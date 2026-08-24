extends SceneTree

const MATCH_SCREEN_SCENE: PackedScene = preload("res://scenes/game/match/match_screen.tscn")
const SETTINGS_MANAGER_SCRIPT = preload("res://scripts/game/settings/settings_manager.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _options()
	var width := int(options.get("width", "1280"))
	var height := int(options.get("height", "720"))
	var reduce_motion := str(options.get("reduce-motion", "false")) == "true"
	var sample_seconds := float(options.get("sample-seconds", "30"))
	var warmup_seconds := float(options.get("warmup-seconds", "5"))
	var output_path := str(options.get("output", "res://evidence/gate2/v3-candidate-05ada98/performance-%dx%d.json" % [width, height]))
	var settings_manager: Node = SETTINGS_MANAGER_SCRIPT.new("user://gate2-rc5-settings.cfg", false, "user://gate2-rc5-progress.cfg")
	settings_manager.name = "SettingsManager"
	root.add_child(settings_manager)
	await process_frame
	var candidate: Dictionary = settings_manager.call("get_settings")
	candidate["window_mode"] = "windowed"
	candidate["resolution"] = Vector2i(1280, 720)
	candidate["vsync"] = false
	candidate["reduce_motion"] = reduce_motion
	settings_manager.call("begin_preview", candidate)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_position(Vector2i(-10000, -10000))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(width, height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen: Control = MATCH_SCREEN_SCENE.instantiate() as Control
	viewport.add_child(screen)
	await process_frame
	screen.apply_layout_for_size(Vector2(width, height))
	screen.render_player_view(_player_view())
	screen.set_local_interaction_state("CONFIRMING", "perf-soldier", "perf-move")
	RenderingServer.force_draw()
	var warmup_start := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - warmup_start) / 1000000.0 < warmup_seconds:
		await process_frame
	var frame_ms: Array[float] = []
	var sample_start := Time.get_ticks_usec()
	var previous := sample_start
	while (Time.get_ticks_usec() - sample_start) / 1000000.0 < sample_seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append((now - previous) / 1000.0)
		previous = now
	var elapsed := (Time.get_ticks_usec() - sample_start) / 1000000.0
	frame_ms.sort()
	var count := frame_ms.size()
	var p99_index := clampi(int(floor(float(maxi(count - 1, 0)) * 0.99)), 0, maxi(count - 1, 0))
	var p99_ms := frame_ms[p99_index] if count > 0 else 0.0
	var total_ms := 0.0
	for value: float in frame_ms:
		total_ms += value
	var snapshot: Dictionary = screen.get_layout_snapshot()
	var board_rect: Rect2 = snapshot.get("board_rect", Rect2())
	var readable := bool(snapshot.get("main_buttons_inside", false)) and bool(snapshot.get("confirming_action_button_inside", false)) and board_rect.position.x >= -0.5 and board_rect.position.y >= -0.5 and board_rect.end.x <= width + 0.5 and board_rect.end.y <= height + 0.5
	var result := {
		"schema_version": "veilfront-gate2-performance-sample-v1", "candidate": "05ada9848c20c41b6d6cc92ce552df643c31438c",
		"godot": Engine.get_version_info().get("string", ""), "display_driver": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(), "video_adapter": RenderingServer.get_video_adapter_name(),
		"resolution": [width, height], "reduce_motion_requested": reduce_motion,
		"reduce_motion_active": settings_manager.call("is_reduced_motion_enabled"), "independent_quality_tier_switch_exists": false,
		"vsync_disabled_for_sampling": true, "warmup_seconds": warmup_seconds, "sample_seconds": elapsed, "frame_count": count,
		"average_fps": count / elapsed if elapsed > 0.0 else 0.0, "average_frame_ms": total_ms / count if count > 0 else 0.0,
		"p99_frame_ms": p99_ms, "one_percent_low_fps_equivalent": 1000.0 / p99_ms if p99_ms > 0.0 else 0.0,
		"max_frame_ms": frame_ms[count - 1] if count > 0 else 0.0, "core_layout_readable": readable,
		"active_layout_profile": snapshot.get("active_profile", ""),
		"board_rect": [board_rect.position.x, board_rect.position.y, board_rect.size.x, board_rect.size.y],
	}
	var absolute_output := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var file := FileAccess.open(absolute_output, FileAccess.WRITE)
	if file == null:
		push_error("PERFORMANCE_SAMPLE_FAIL cannot open output")
		quit(2)
		return
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("GATE2_RC5_PERFORMANCE_SAMPLE_PASS resolution=%dx%d reduce_motion=%s average_fps=%.3f p99_ms=%.3f one_percent_low=%.3f core_readable=%s path=%s" % [width, height, reduce_motion, result.average_fps, p99_ms, result.one_percent_low_fps_equivalent, readable, output_path])
	quit(0)


func _options() -> Dictionary:
	var result := {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and "=" in argument:
			var index := argument.find("=")
			result[argument.substr(2, index - 2)] = argument.substr(index + 1)
	return result


func _player_view() -> Dictionary:
	var cells: Array = []
	for y: int in range(1, 15):
		for x: int in range(1, 10):
			cells.append([x, y])
	return {
		"match_id": "gate2-rc5-performance", "viewer_side": "red", "active_side": "red", "action_index": 15,
		"full_round_index": 8, "round_limit_public": 50, "terminal": false, "board": {"width": 9, "height": 24},
		"visible_cells": cells, "hidden_detection_cells": [[2, 15], [4, 15], [6, 15], [8, 15]],
		"pieces": [
			{"alive": true, "id": "perf-rook", "in_reserve": false, "piece_type": "rook", "position": [2, 4], "side": "red", "status_tags": ["READY"]},
			{"alive": true, "id": "perf-soldier", "in_reserve": false, "piece_type": "soldier", "position": [5, 5], "side": "red", "status_tags": []},
			{"alive": true, "id": "perf-elephant", "in_reserve": false, "piece_type": "elephant", "position": [8, 4], "side": "red", "status_tags": []},
			{"alive": true, "id": "perf-enemy", "in_reserve": false, "piece_type": "horse", "position": [5, 12], "side": "black", "status_tags": ["CONTACT"]},
		],
		"flags": [{"capture_progress": 1, "capturing_side": "red", "contested": false, "discovered": true, "id": "perf-flag", "owner": "red", "position": [7, 3]}],
		"walls": [{"side": "red", "status": "INTACT"}, {"side": "black", "status": "BREACHED"}],
		"casualties": [{"side": "red", "piece_type": "soldier"}, {"side": "black", "piece_type": "cannon"}], "capture_ghosts": [],
		"vision_overlays": {"rook_paths": [], "elephant_reveal_zones": [], "elephant_block_fields": []}, "contact_intel": [],
	}
