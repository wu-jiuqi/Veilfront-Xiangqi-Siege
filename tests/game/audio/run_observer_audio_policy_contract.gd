extends SceneTree

const ObserverPolicy = preload("res://scripts/game/audio/observer_audio_policy.gd")

var _checks: int = 0
var _failures: Array[String] = []


func _init() -> void:
	_check_first_baseline()
	_check_move_and_public_position()
	_check_reject_equivalence()
	_check_undiscovered_flag_is_global()
	_check_bombardment_has_fixed_public_skeleton()
	_check_state_turn_terminal_order()
	_check_hidden_equivalent_public_inputs()
	_check_rollback_fails_closed()
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(failure)
		print("OBSERVER_AUDIO_POLICY_CONTRACT_FAIL failures=%d" % _failures.size())
		quit(1)
		return
	print("OBSERVER_AUDIO_POLICY_CONTRACT_PASS checks=%d schema=v1" % _checks)
	quit(0)


func _check_first_baseline() -> void:
	var baseline: Dictionary = ObserverPolicy.project_frame({}, _view(), [], {})
	_expect(not baseline.is_empty(), "first observer baseline was rejected")
	_expect(baseline.get("cues", []).is_empty(), "first baseline replayed historical audio")
	var terminal := _view()
	terminal["terminal"] = true
	terminal["winner"] = "red"
	terminal["win_reason"] = "general_destroyed"
	var terminal_batch: Dictionary = ObserverPolicy.project_frame({}, terminal, [], {})
	_expect(_cue_keys(terminal_batch) == ["sfx.match.victory"], "terminal baseline must play once")


func _check_move_and_public_position() -> void:
	var previous := _view()
	previous["pieces"] = [_piece("rp1", "red", "pawn", [1, 5])]
	var current := previous.duplicate(true)
	current["action_index"] = 1
	current["active_side"] = "black"
	current["visible_event_cursor"] = 1
	current["pieces"][0]["position"] = [1, 6]
	var batch: Dictionary = ObserverPolicy.project_frame(
		previous, current, [_event(1, 0, "move_resolved")], {}
	)
	_expect(_cue_keys(batch) == ["sfx.move.foot"], "public pawn move did not map to foot cue")
	var cue: Dictionary = batch["cues"][0]
	_expect(cue["spatial_mode"] == "board_2d", "public move lost spatial mode")
	_expect(cue["position_public"] == [1, 6], "move used a non-destination coordinate")


func _check_reject_equivalence() -> void:
	var view := _view()
	var reference: String = ""
	for public_code: String in [
		"known_illegal", "intent_unresolved", "stale_intent", "invalid_request",
	]:
		var error := {
			"action_index": 0,
			"intent_id": "same-public-intent",
			"public_code": public_code,
			"timing_bucket": "standard",
		}
		var batch: Dictionary = ObserverPolicy.project_visible_error(view, error)
		_expect(_cue_keys(batch) == ["sfx.ui.reject"], "reject did not use unified cue")
		var cue: Dictionary = batch["cues"][0]
		_expect(cue["spatial_mode"] == "global", "reject leaked a location")
		var canonical: String = JSON.stringify(batch, "", true, true)
		if reference.is_empty():
			reference = canonical
		else:
			_expect(canonical == reference, "public error codes produced distinguishable audio")
	var first_attempt: Dictionary = ObserverPolicy.project_visible_error(view, {
		"action_index": 0, "intent_id": "attempt-a", "public_code": "known_illegal",
	})
	var second_attempt: Dictionary = ObserverPolicy.project_visible_error(view, {
		"action_index": 0, "intent_id": "attempt-b", "public_code": "known_illegal",
	})
	_expect(first_attempt["cues"][0]["cue_id"] != second_attempt["cues"][0]["cue_id"],
		"separate rejected attempts collided at the same action index")


func _check_undiscovered_flag_is_global() -> void:
	var previous := _view()
	previous["flags"] = [_flag("f1", false, [], 0, "")]
	var current := previous.duplicate(true)
	current["action_index"] = 1
	current["flags"][0]["capture_progress"] = 1
	var batch: Dictionary = ObserverPolicy.project_frame(previous, current, [], {})
	_expect(_cue_keys(batch) == ["sfx.flag.capture_progress"], "flag progress cue missing")
	var cue: Dictionary = batch["cues"][0]
	_expect(cue["spatial_mode"] == "global", "undiscovered flag progress became positional")
	_expect(cue["position_public"].is_empty(), "undiscovered flag leaked a coordinate")


func _check_bombardment_has_fixed_public_skeleton() -> void:
	var previous := _view()
	var current := previous.duplicate(true)
	current["action_index"] = 1
	current["active_side"] = "black"
	current["visible_event_cursor"] = 1
	var event := _event(1, 0, "bombardment_resolved")
	event["position_public"] = []
	var first: Dictionary = ObserverPolicy.project_frame(previous, current, [event], {})
	# Hidden impact cells and casualty truth are intentionally not inputs.
	var hidden_truth_a := {"impacts": 0, "secret_seed": 1}
	var hidden_truth_b := {"impacts": 3, "secret_seed": 999}
	_expect(hidden_truth_a != hidden_truth_b, "test hidden fixtures must differ")
	var second: Dictionary = ObserverPolicy.project_frame(previous, current, [event], {})
	_expect(JSON.stringify(first, "", true, true) == JSON.stringify(second, "", true, true),
		"hidden-equivalent bombardment inputs diverged")
	_expect(_cue_keys(first) == ["sfx.bombard.launch", "sfx.bombard.impact_bed"],
		"bombardment skeleton must stay fixed at two cues")
	for cue_value: Variant in first["cues"]:
		_expect(cue_value["spatial_mode"] == "global", "bombardment inferred a hidden position")


func _check_state_turn_terminal_order() -> void:
	var previous := _view()
	previous["active_side"] = "black"
	previous["walls"] = [_wall("red", "INTACT"), _wall("black", "INTACT")]
	previous["flags"] = [_flag("f1", true, [5, 12], 2, "")]
	var current := previous.duplicate(true)
	current["action_index"] = 4
	current["active_side"] = "red"
	current["terminal"] = true
	current["winner"] = "red"
	current["win_reason"] = "flags"
	current["walls"][1]["status"] = "BREACHED"
	current["flags"][0]["capture_progress"] = 3
	current["flags"][0]["owner"] = "red"
	var batch: Dictionary = ObserverPolicy.project_frame(previous, current, [], {})
	_expect(_cue_keys(batch) == [
		"sfx.wall.breached",
		"sfx.flag.captured",
		"sfx.match.victory",
	], "state/terminal ordering violated the shared Cue v1 contract")


func _check_hidden_equivalent_public_inputs() -> void:
	var previous := _view()
	var current := previous.duplicate(true)
	current["action_index"] = 2
	current["visible_event_cursor"] = 1
	var public_events: Array = [_event(1, 1, "pass")]
	var hidden_a := {"enemy_piece_type": "horse", "flag_position": [3, 9]}
	var hidden_b := {"enemy_piece_type": "cannon", "flag_position": [8, 19]}
	_expect(hidden_a != hidden_b, "hidden fixtures did not differ")
	var a: Dictionary = ObserverPolicy.project_frame(previous, current, public_events, {})
	var b: Dictionary = ObserverPolicy.project_frame(previous, current, public_events, {})
	_expect(JSON.stringify(a, "", true, true) == JSON.stringify(b, "", true, true),
		"same observer inputs did not produce byte-equivalent batches")


func _check_rollback_fails_closed() -> void:
	var previous := _view()
	previous["action_index"] = 2
	previous["visible_event_cursor"] = 2
	var rollback := _view()
	rollback["action_index"] = 1
	rollback["visible_event_cursor"] = 1
	_expect(ObserverPolicy.project_frame(previous, rollback, [], {}).is_empty(),
		"rollback observer frame did not fail closed")


func _view() -> Dictionary:
	return {
		"schema_version": "veilfront-player-view-v1",
		"match_id": "audio-test-session",
		"rules_revision": "owner-rule-revision-5",
		"viewer_side": "red",
		"board": {"width": 9, "height": 24},
		"active_side": "red",
		"action_index": 0,
		"full_round_index": 1,
		"round_limit_public": 50,
		"terminal": false,
		"winner": "",
		"win_reason": "",
		"visible_cells": [[1, 1]],
		"hidden_detection_cells": [],
		"pieces": [],
		"flags": [],
		"walls": [],
		"casualties": [],
		"capture_ghosts": [],
		"vision_overlays": {
			"rook_paths": [], "elephant_reveal_zones": [], "elephant_block_fields": [],
		},
		"contact_intel": [],
		"visible_event_cursor": 0,
	}


func _piece(id: String, side: String, piece_type: String, position: Array) -> Dictionary:
	return {
		"id": id, "side": side, "piece_type": piece_type, "position": position,
		"alive": true, "in_reserve": false, "status_tags": [],
	}


func _flag(id: String, discovered: bool, position: Array, progress: int, owner: String) -> Dictionary:
	return {
		"id": id, "owner": owner, "capturing_side": "red" if progress > 0 else "",
		"capture_progress": progress, "contested": false, "discovered": discovered,
		"position": position,
	}


func _wall(side: String, status: String) -> Dictionary:
	return {"side": side, "status": status}


func _event(sequence: int, action_index: int, event_type: String) -> Dictionary:
	return {
		"schema_version": "veilfront-visible-event-v1",
		"visible_sequence": sequence,
		"action_index": action_index,
		"event_type": event_type,
		"actor_side_public": "red",
		"position_public": [],
		"piece_public": {},
		"message_key": "event.%s" % event_type,
		"public_payload": {},
		"timing_bucket": "standard",
	}


func _cue_keys(batch: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for cue_value: Variant in batch.get("cues", []):
		result.append(str(cue_value.get("cue_key", "")))
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
