extends SceneTree

const BOARD_VIEWPORT_SCENE: PackedScene = preload(
	"res://scenes/game/match/board/board_viewport.tscn"
)
const FEEDBACK_SCENE: PackedScene = preload(
	"res://scenes/game/presentation/match_feedback_coordinator.tscn"
)
const FORMAL_SCREEN_PATHS: Array[String] = [
	"res://scenes/game/match/match_screen.tscn",
	"res://scenes/game/match/online_match_screen.tscn",
]

var _failures: Array[String] = []
var _played_audio_keys: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_runtime_coordination()
	for screen_path: String in FORMAL_SCREEN_PATHS:
		await _check_formal_screen(screen_path)
	_check_observer_boundary()
	_finish()


func _check_runtime_coordination() -> void:
	var host := Node.new()
	root.add_child(host)
	var board_viewport := BOARD_VIEWPORT_SCENE.instantiate() as SubViewportContainer
	(board_viewport.get_node("BoardSubViewport") as SubViewport).render_target_update_mode = \
		SubViewport.UPDATE_DISABLED
	host.add_child(board_viewport)
	var feedback := FEEDBACK_SCENE.instantiate() as MatchFeedbackCoordinator
	host.add_child(feedback)
	await process_frame

	var emitter := board_viewport.get_board_audio_emitter_pool() as BoardAudioEmitterPool
	var director := board_viewport.get_vfx_director() as VfxDirector
	feedback.get_audio_root().dry_run = true
	emitter.dry_run = true
	feedback.bind_board_feedback(emitter, director)
	feedback.get_audio_root().cue_played.connect(
		func(cue: Dictionary) -> void: _played_audio_keys.append(str(cue.get("cue_key", "")))
	)

	feedback.consume_player_view(_bombard_view(false))
	var initial_result := feedback.consume_visible_events([])
	_expect(initial_result.has("audio_batch"), "initial observer frame was not consumed")
	feedback.play_local_selection(Vector2i(2, 4))
	await process_frame
	_expect("sfx.board.select" in _played_audio_keys, "local selection SFX was not routed")
	var local_vfx: Dictionary = director.get_pool_snapshot()
	_expect(int(local_vfx.get("active_count", 0)) >= 1, "local selection VFX was not routed")
	director.clear_all()

	var audio_count_before_observer := _played_audio_keys.size()
	feedback.consume_player_view(_bombard_view(true))
	var result := feedback.consume_visible_events([_bombard_event()])
	var audio_batch: Dictionary = result.get("audio_batch", {})
	var vfx_batch: Dictionary = result.get("vfx_batch", {})
	var audio_keys: Array[String] = []
	for cue: Dictionary in audio_batch.get("cues", []):
		audio_keys.append(str(cue.get("cue_key", "")))
	var vfx_cues: Array = vfx_batch.get("cues", [])
	_expect(
		audio_keys == ["sfx.bombard.launch", "sfx.bombard.impact_bed"],
		"bombardment frame did not produce the exact two-cue SFX skeleton"
	)
	_expect(vfx_cues.size() == 1, "bombardment frame must produce exactly one VFX cue")
	if vfx_cues.size() == 1:
		_expect(str(vfx_cues[0].get("cue_key", "")) == "vfx.bombardment.resolve", "bombardment VFX key mismatch")
		_expect(vfx_cues[0].get("position_public", []) == [4, 8], "bombardment VFX public position mismatch")
	_expect(int(result.get("vfx_played", 0)) == 1, "bombardment VFX batch did not reach the director exactly once")
	_expect(_played_audio_keys.size() == audio_count_before_observer + 2, "bombardment SFX did not play exactly twice")
	_expect(
		str(audio_batch.get("session_public_id", "")) == "match-feedback-contract",
		"audio batch lost the public session identity"
	)
	_expect(
		str(vfx_batch.get("session_public_id", "")) == "match-feedback-contract",
		"VFX batch lost the public session identity"
	)
	var audio_count_before_replay := _played_audio_keys.size()
	feedback.consume_player_view(_bombard_view(true))
	var replay := feedback.consume_visible_events([_bombard_event()])
	_expect((replay.get("audio_batch", {}) as Dictionary).get("cues", []).is_empty(), "replayed frame emitted SFX cues")
	_expect((replay.get("vfx_batch", {}) as Dictionary).get("cues", []).is_empty(), "replayed frame emitted VFX cues")
	_expect(int(replay.get("vfx_played", -1)) == 0, "replayed frame activated VFX")
	_expect(_played_audio_keys.size() == audio_count_before_replay, "replayed frame activated SFX")

	var switched_view := _bombard_view(false)
	switched_view["match_id"] = "match-feedback-contract-next"
	feedback.consume_player_view(switched_view)
	var switched_result := feedback.consume_visible_events([])
	_expect(
		str((switched_result.get("audio_batch", {}) as Dictionary).get("session_public_id", "")) \
			== "match-feedback-contract-next",
		"public session switch did not reset the audio/VFX baseline"
	)

	feedback.reset_session()
	var reset_snapshot: Dictionary = feedback.get_feedback_snapshot()
	_expect(not bool(reset_snapshot.get("has_previous_view", true)), "session reset kept prior view")
	_expect(not bool(reset_snapshot.get("has_pending_view", true)), "session reset kept pending view")
	_expect(
		int((reset_snapshot.get("vfx", {}) as Dictionary).get("active_count", -1)) == 0,
		"session reset kept active VFX"
	)
	host.queue_free()
	await process_frame


func _check_formal_screen(screen_path: String) -> void:
	var packed := load(screen_path) as PackedScene
	_expect(packed != null, "formal screen cannot load: %s" % screen_path)
	if packed == null:
		return
	var screen := packed.instantiate() as Control
	for node: Node in screen.find_children("*", "SubViewport", true, false):
		(node as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(screen)
	await process_frame
	var feedback_nodes := screen.find_children("MatchFeedbackCoordinator", "", true, false)
	_expect(feedback_nodes.size() == 1, "formal screen must preset exactly one feedback coordinator: %s" % screen_path)
	var feedback := screen.get_node_or_null("MatchFeedbackCoordinator") as MatchFeedbackCoordinator
	_expect(feedback != null, "formal screen feedback coordinator is missing: %s" % screen_path)
	if feedback != null:
		var snapshot: Dictionary = feedback.get_feedback_snapshot()
		_expect(bool(snapshot.get("board_emitter_bound", false)), "formal screen did not bind board audio: %s" % screen_path)
		_expect(bool(snapshot.get("vfx_bound", false)), "formal screen did not bind VFX: %s" % screen_path)
		feedback.get_audio_root().dry_run = true
		feedback.get_audio_root().cue_played.connect(
			func(cue: Dictionary) -> void: _played_audio_keys.append(str(cue.get("cue_key", "")))
		)
		var board_viewports := screen.find_children("BoardViewport", "SubViewportContainer", true, false)
		if not board_viewports.is_empty():
			(board_viewports[0].get_board_audio_emitter_pool() as BoardAudioEmitterPool).dry_run = true
		screen.call("render_player_view", _bombard_view(false))
		screen.call("render_visible_events", [])
		snapshot = feedback.get_feedback_snapshot()
		_expect(bool(snapshot.get("has_previous_view", false)), "formal screen did not forward the observer frame: %s" % screen_path)
		screen.call("reset_for_session_end")
		snapshot = feedback.get_feedback_snapshot()
		_expect(not bool(snapshot.get("has_previous_view", true)), "formal screen did not reset feedback state: %s" % screen_path)
		if screen_path.ends_with("online_match_screen.tscn"):
			var timeout_audio_before := _played_audio_keys.count("sfx.turn.timeout")
			screen.call("render_player_view", _timeout_view(false))
			screen.call("render_visible_events", [])
			screen.call("_on_turn_timeout_requested", 0)
			_expect(
				_played_audio_keys.count("sfx.turn.timeout") == timeout_audio_before,
				"local timeout request played before the visible timeout event"
			)
			screen.call("render_player_view", _timeout_view(true))
			screen.call("render_visible_events", [_timeout_event()])
			_expect(
				_played_audio_keys.count("sfx.turn.timeout") == timeout_audio_before + 1,
				"visible timeout event did not produce exactly one timeout cue"
			)
			screen.call("reset_for_session_end")
	var minimap_worlds := screen.find_children("BoardWorld", "", true, false)
	_expect(minimap_worlds.size() >= 2, "formal screen should contain main and minimap BoardWorld: %s" % screen_path)
	for board_world: Node in minimap_worlds:
		_expect(
			board_world.get_node_or_null("BoardFeedbackLayer") == null,
			"minimap-reusable BoardWorld contains feedback pools: %s" % screen_path
		)
	screen.queue_free()
	await process_frame


func _check_observer_boundary() -> void:
	for path: String in [
		"res://scripts/game/presentation/match_feedback_coordinator.gd",
		"res://scripts/game/vfx/observer_vfx_policy.gd",
		"res://scripts/game/audio/observer_audio_policy.gd",
	]:
		var file := FileAccess.open(path, FileAccess.READ)
		var text := file.get_as_text().to_lower() if file != null else ""
		for forbidden: String in ["/domain/", "full" + "state", "rng_state", "authoritative" + "replay"]:
			_expect(not text.contains(forbidden), "observer feedback depends on forbidden source: %s -> %s" % [path, forbidden])


func _bombard_view(after: bool) -> Dictionary:
	return {
		"schema_version": "veilfront-player-view-v1",
		"match_id": "match-feedback-contract",
		"rules_revision": "owner-rule-revision-5",
		"viewer_side": "red",
		"board": {"width": 9, "height": 24},
		"active_side": "black",
		"action_index": 1 if after else 0,
		"full_round_index": 1,
		"round_limit_public": 50,
		"terminal": false,
		"winner": "",
		"win_reason": "",
		"visible_cells": [[4, 8]],
		"hidden_detection_cells": [],
		"pieces": [],
		"flags": [{
			"id": "flag-hidden", "owner": "", "capturing_side": "",
			"capture_progress": 0, "contested": false,
			"discovered": false, "position": [],
		}],
		"walls": [
			{"side": "red", "status": "INTACT"},
			{"side": "black", "status": "INTACT"},
		],
		"casualties": [],
		"capture_ghosts": [],
		"vision_overlays": {
			"rook_paths": [], "elephant_reveal_zones": [], "elephant_block_fields": [],
		},
		"contact_intel": [],
		"visible_event_cursor": 1 if after else 0,
	}


func _timeout_view(after: bool) -> Dictionary:
	var view := _bombard_view(after)
	view["match_id"] = "match-feedback-timeout"
	view["active_side"] = "black" if after else "red"
	return view


func _bombard_event() -> Dictionary:
	return {
		"schema_version": "veilfront-visible-event-v1",
		"visible_sequence": 1,
		"action_index": 1,
		"event_type": "bombardment_resolved",
		"actor_side_public": "black",
		"position_public": [4, 8],
		"piece_public": {},
		"message_key": "event.bombardment_resolved",
		"public_payload": {},
		"timing_bucket": "standard",
	}


func _timeout_event() -> Dictionary:
	var event := _bombard_event()
	event["event_type"] = "timeout"
	event["position_public"] = []
	event["message_key"] = "event.timeout"
	return event


func _finish() -> void:
	if _failures.is_empty():
		print(
			"MATCH_FEEDBACK_INTEGRATION_CONTRACT_PASS screens=2 "
			+ "audio_observer=true vfx_observer=true local_selection=true "
			+ "minimap_isolation=true reset=true"
		)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("MATCH_FEEDBACK_INTEGRATION_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
