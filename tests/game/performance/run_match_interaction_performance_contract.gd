extends SceneTree

const FormalLocalSession = preload(
	"res://scripts/game/application/formal_local_session.gd"
)
const FOG_SCENE: PackedScene = preload(
	"res://scenes/game/match/board/fog_overlay.tscn"
)

const SAMPLE_COUNT: int = 200
const INTERACTION_P99_BUDGET_MS: float = 16.7

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var selection_metrics := _measure_incremental_selection()
	var confirmation_metrics := _measure_action_confirmation()
	var fog_metrics := _measure_fog_cache()
	if _failures.is_empty():
		print(
			"MATCH_INTERACTION_PERFORMANCE_CONTRACT_PASS "
			+ "selection_p95_ms=%.3f selection_p99_ms=%.3f " % [
				selection_metrics.get("p95_ms", 0.0),
				selection_metrics.get("p99_ms", 0.0),
			]
			+ "confirmation_p95_ms=%.3f confirmation_p99_ms=%.3f " % [
				confirmation_metrics.get("p95_ms", 0.0),
				confirmation_metrics.get("p99_ms", 0.0),
			]
			+ "fog_cache_p95_ms=%.3f fog_cache_p99_ms=%.3f" % [
				fog_metrics.get("p95_ms", 0.0),
				fog_metrics.get("p99_ms", 0.0),
			]
		)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("MATCH_INTERACTION_PERFORMANCE_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _measure_incremental_selection() -> Dictionary:
	var session: RefCounted = FormalLocalSession.create(471001)
	var port: RefCounted = session.create_client_port("red")
	var signal_counts := {"view": 0, "events": 0, "session": 0, "previews": 0}
	var last_previews: Array = []
	port.player_view_updated.connect(func(_view: Dictionary) -> void:
		signal_counts["view"] = int(signal_counts["view"]) + 1
	)
	port.visible_events_received.connect(func(_events: Array) -> void:
		signal_counts["events"] = int(signal_counts["events"]) + 1
	)
	port.session_state_changed.connect(func(_state: Dictionary) -> void:
		signal_counts["session"] = int(signal_counts["session"]) + 1
	)
	port.action_previews_updated.connect(func(previews: Array) -> void:
		signal_counts["previews"] = int(signal_counts["previews"]) + 1
		last_previews.assign(previews)
	)
	var publish_result: Dictionary = port.publish_current()
	_expect(bool(publish_result.get("ok", false)), "formal local port initial publish failed")
	var selected_preview := _first_legal_move(last_previews)
	_expect(not selected_preview.is_empty(), "formal local port exposed no legal move preview")
	if selected_preview.is_empty():
		return {"p95_ms": INF, "p99_ms": INF}
	var piece_id := str(selected_preview.get("piece_id", ""))
	var action_type := str(selected_preview.get("action_type", ""))
	var baseline_view_count := int(signal_counts["view"])
	var baseline_event_count := int(signal_counts["events"])
	var baseline_session_count := int(signal_counts["session"])
	var samples: Array[float] = []
	for _sample_index: int in SAMPLE_COUNT:
		var started_at := Time.get_ticks_usec()
		port.request_action_previews(piece_id, action_type)
		samples.append(float(Time.get_ticks_usec() - started_at) / 1000.0)
		_expect(
			_previews_match_request(last_previews, piece_id, action_type),
			"selection request published previews outside the requested piece/action"
		)
	_expect(
		int(signal_counts["view"]) == baseline_view_count,
		"selection request republished PlayerView"
	)
	_expect(
		int(signal_counts["events"]) == baseline_event_count,
		"selection request republished visible events"
	)
	_expect(
		int(signal_counts["session"]) == baseline_session_count,
		"selection request republished session state"
	)
	_expect(
		int(signal_counts["previews"]) == SAMPLE_COUNT + 1,
		"selection request did not publish exactly one preview batch per request"
	)
	var metrics := _percentiles(samples)
	_expect(
		float(metrics.get("p99_ms", INF)) <= INTERACTION_P99_BUDGET_MS,
		"selection request p99 exceeded %.1f ms: %.3f ms" % [
			INTERACTION_P99_BUDGET_MS,
			metrics.get("p99_ms", INF),
		]
	)
	return metrics


func _measure_action_confirmation() -> Dictionary:
	var samples: Array[float] = []
	for sample_index: int in SAMPLE_COUNT:
		var session: RefCounted = FormalLocalSession.create(472000 + sample_index)
		var port: RefCounted = session.create_client_port("red")
		var available_previews: Array = []
		port.action_previews_updated.connect(func(previews: Array) -> void:
			available_previews.assign(previews)
		)
		var publish_result: Dictionary = port.publish_current()
		_expect(
			bool(publish_result.get("ok", false)),
			"confirmation sample initial publish failed"
		)
		var selected_preview := _first_legal_move(available_previews)
		_expect(
			not selected_preview.is_empty(),
			"confirmation sample exposed no legal move preview"
		)
		if selected_preview.is_empty():
			continue
		var preview_id := str(selected_preview.get("preview_id", ""))
		port.prepare_action(preview_id)
		var started_at := Time.get_ticks_usec()
		port.confirm_prepared_action(preview_id)
		samples.append(float(Time.get_ticks_usec() - started_at) / 1000.0)
	if samples.size() != SAMPLE_COUNT:
		return {"p95_ms": INF, "p99_ms": INF}
	var metrics := _percentiles(samples)
	_expect(
		float(metrics.get("p99_ms", INF)) <= INTERACTION_P99_BUDGET_MS,
		"action confirmation p99 exceeded %.1f ms: %.3f ms" % [
			INTERACTION_P99_BUDGET_MS,
			metrics.get("p99_ms", INF),
		]
	)
	return metrics


func _measure_fog_cache() -> Dictionary:
	var main_fog := FOG_SCENE.instantiate() as TextureRect
	var minimap_fog := FOG_SCENE.instantiate() as TextureRect
	root.add_child(main_fog)
	root.add_child(minimap_fog)
	var visible_cells: Array = [[1, 1], [2, 1], [5, 12], [9, 24]]
	var detection_cells: Array = [[8, 20]]
	main_fog.render(visible_cells, detection_cells, "red", Vector2(128.0, 128.0))
	var initial_texture: ImageTexture = main_fog.get_mask_texture()
	minimap_fog.render(
		visible_cells,
		detection_cells,
		"red",
		Vector2(128.0, 128.0),
		initial_texture
	)
	var main_before: Dictionary = main_fog.get_visual_snapshot()
	var minimap_before: Dictionary = minimap_fog.get_visual_snapshot()
	_expect(
		int(main_before.get("mask_rebuild_count", -1)) == 1,
		"main fog did not build exactly one initial mask"
	)
	_expect(
		int(minimap_before.get("mask_rebuild_count", -1)) == 0 \
		and int(minimap_before.get("borrowed_mask_count", 0)) == 1,
		"minimap fog did not reuse the main-board mask"
	)
	var samples: Array[float] = []
	for _sample_index: int in SAMPLE_COUNT:
		var started_at := Time.get_ticks_usec()
		main_fog.render(visible_cells, detection_cells, "red", Vector2(128.0, 128.0))
		minimap_fog.render(
			visible_cells,
			detection_cells,
			"red",
			Vector2(128.0, 128.0),
			main_fog.get_mask_texture()
		)
		samples.append(float(Time.get_ticks_usec() - started_at) / 1000.0)
	var main_after: Dictionary = main_fog.get_visual_snapshot()
	var minimap_after: Dictionary = minimap_fog.get_visual_snapshot()
	_expect(
		int(main_after.get("mask_rebuild_count", -1)) == 1,
		"unchanged main-board fog rebuilt its mask"
	)
	_expect(
		int(minimap_after.get("mask_rebuild_count", -1)) == 0,
		"unchanged minimap fog rebuilt its mask"
	)
	var texture_rid_before: RID = main_fog.get_mask_texture().get_rid()
	visible_cells.append([4, 12])
	main_fog.render(visible_cells, detection_cells, "red", Vector2(128.0, 128.0))
	minimap_fog.render(
		visible_cells,
		detection_cells,
		"red",
		Vector2(128.0, 128.0),
		main_fog.get_mask_texture()
	)
	_expect(
		int(main_fog.get_visual_snapshot().get("mask_rebuild_count", -1)) == 2,
		"changed visibility did not rebuild the main-board mask once"
	)
	_expect(
		main_fog.get_mask_texture().get_rid() == texture_rid_before,
		"owned fog mask texture was recreated instead of updated"
	)
	_expect(
		int(minimap_fog.get_visual_snapshot().get("mask_rebuild_count", -1)) == 0,
		"changed minimap visibility did not reuse the main-board mask"
	)
	main_fog.queue_free()
	minimap_fog.queue_free()
	var metrics := _percentiles(samples)
	_expect(
		float(metrics.get("p99_ms", INF)) <= INTERACTION_P99_BUDGET_MS,
		"cached dual fog render p99 exceeded %.1f ms: %.3f ms" % [
			INTERACTION_P99_BUDGET_MS,
			metrics.get("p99_ms", INF),
		]
	)
	return metrics


func _first_legal_move(previews: Array) -> Dictionary:
	for preview_value: Variant in previews:
		if preview_value is Dictionary \
		and str(preview_value.get("action_type", "")) == "move" \
		and str(preview_value.get("classification", "")) == "KNOWN_LEGAL":
			return preview_value.duplicate(true)
	return {}


func _previews_match_request(previews: Array, piece_id: String, action_type: String) -> bool:
	if previews.is_empty():
		return false
	for preview_value: Variant in previews:
		if not preview_value is Dictionary \
		or str(preview_value.get("piece_id", "")) != piece_id \
		or str(preview_value.get("action_type", "")) != action_type:
			return false
	return true


func _percentiles(samples: Array[float]) -> Dictionary:
	var sorted_samples := samples.duplicate()
	sorted_samples.sort()
	return {
		"p95_ms": sorted_samples[_percentile_index(sorted_samples.size(), 0.95)],
		"p99_ms": sorted_samples[_percentile_index(sorted_samples.size(), 0.99)],
	}


func _percentile_index(sample_count: int, percentile: float) -> int:
	return clampi(ceili(float(sample_count) * percentile) - 1, 0, sample_count - 1)


func _expect(condition: bool, message: String) -> void:
	if not condition and message not in _failures:
		_failures.append(message)
