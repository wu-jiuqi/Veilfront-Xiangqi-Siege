extends SceneTree

const MATCH_SCREEN_SCENE: PackedScene = preload("res://scenes/game/match/match_screen.tscn")
const PLAYER_VIEW_PATH: String = "res://tests/game/contracts/fixtures/red_player_view_minimal_v1.json"
const FixtureMatchClientPort = preload("res://tests/game/contracts/fixture_match_client_port.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var match_screen: Control = MATCH_SCREEN_SCENE.instantiate() as Control
	root.add_child(match_screen)
	match_screen.apply_layout_for_size(match_screen.size)
	await process_frame

	var view: Dictionary = _build_observer_view()
	match_screen.render_player_view(view)
	await process_frame
	var board_snapshot: Dictionary = match_screen.get_board_render_snapshot()
	_expect(int(board_snapshot.get("piece_count", -1)) == 1, "visible fixture piece was not rendered")
	_expect(int(board_snapshot.get("flag_count", -1)) == 1, "discovered flag memory was not rendered")
	_expect(int(board_snapshot.get("ghost_count", -1)) == 1, "capture ghost was not rendered")
	_expect(bool(board_snapshot.get("flag_cell_fogged", false)), "fixture flag must be back under fog")
	_expect(bool(board_snapshot.get("flag_memory_visible", false)), "discovered flag must remain visible over fog")
	_expect(int(board_snapshot.get("tactical_group_count", -1)) == 2, "only rook path and elephant block field should render")
	var tactical_overlay: Node = match_screen.find_child("TacticalOverlay", true, false)
	_expect(tactical_overlay != null, "tactical overlay is missing")
	if tactical_overlay != null:
		_expect(tactical_overlay.has_method("get_semantic_snapshot"), "tactical overlay has no semantic snapshot")
		if tactical_overlay.has_method("get_semantic_snapshot"):
			var tactical_snapshot: Dictionary = tactical_overlay.get_semantic_snapshot()
			_expect(int(tactical_snapshot.get("rook_path_count", -1)) == 1, "rook path semantic count mismatch")
			_expect(int(tactical_snapshot.get("elephant_field_count", -1)) == 1, "elephant field semantic count mismatch")
			_expect(int(tactical_snapshot.get("ignored_reveal_cell_count", -1)) == 19, "19-cell elephant reveal source was not ignored")
			_expect(int(tactical_snapshot.get("rendered_reveal_count", -1)) == 0, "19-cell elephant reveal must not render a border")
			_expect(tactical_snapshot.get("elephant_block_cell_counts", []) == [9], "elephant border must use exactly nine block cells")

	var layer_order: Dictionary = board_snapshot.get("layer_order", {})
	_expect(int(layer_order.get("fog", -1)) < int(layer_order.get("intel", -1)), "flag memory must render above fog")
	_expect(int(layer_order.get("marker", -1)) < int(layer_order.get("interaction", -1)), "interaction must render above private markers")

	match_screen.set_local_interaction_state("SELECTED", "fixture-piece", "")
	var first_right_click: String = match_screen.handle_cancel_or_marker(Vector2i(3, 10))
	_expect(first_right_click == "cancel_selection", "selected right click must cancel before marking")
	_expect(match_screen.get_local_interaction_state() == "IDLE", "selection cancel must return to IDLE")
	_expect(int(match_screen.get_board_render_snapshot().get("marker_count", -1)) == 0, "selection cancel must not add marker")

	var second_right_click: String = match_screen.handle_cancel_or_marker(Vector2i(3, 10))
	_expect(second_right_click == "open_marker_menu", "idle right click must open marker menu")
	match_screen.apply_marker(Vector2i(3, 10), "circle")
	_expect(int(match_screen.get_board_render_snapshot().get("marker_count", -1)) == 1, "marker was not stored locally")
	match_screen.render_action_previews(Vector2i(3, 10), [{
		"classification": "KNOWN_LEGAL",
		"target_cell": [4, 10],
	}])
	var overlay_snapshot: Dictionary = match_screen.get_board_render_snapshot()
	_expect(int(overlay_snapshot.get("marker_count", -1)) == 1, "interaction refresh must not erase markers")
	_expect(int(overlay_snapshot.get("interaction_preview_count", -1)) == 1, "interaction preview was not rendered above marker")

	match_screen.set_local_interaction_state("CONFIRMING", "fixture-advisor", "fixture-resurrect")
	var sacrifice_cancel: String = match_screen.handle_cancel_or_marker(Vector2i(3, 10))
	_expect(sacrifice_cancel == "cancel_prepared_action", "confirming sacrifice must support cancel")
	_expect(match_screen.get_local_interaction_state() == "IDLE", "sacrifice cancel must return to IDLE")

	await _check_delayed_prepare_cancel(match_screen)

	var hidden_view: Dictionary = view.duplicate(true)
	hidden_view["flags"] = [{
		"capture_progress": 0,
		"capturing_side": "",
		"contested": false,
		"discovered": false,
		"id": "flag-hidden",
		"owner": "",
		"position": [],
	}]
	match_screen.render_player_view(hidden_view)
	await process_frame
	_expect(int(match_screen.get_board_render_snapshot().get("flag_count", -1)) == 0, "undiscovered flag must not create a node")

	if _failures.is_empty():
		print("BOARD_OBSERVER_FIXTURE_PASS")
		match_screen.queue_free()
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("BOARD_OBSERVER_FIXTURE_FAIL failures=%d" % _failures.size())
	match_screen.queue_free()
	quit(1)


func _build_observer_view() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAYER_VIEW_PATH))
	var view: Dictionary = parsed as Dictionary
	view["visible_cells"] = [[5, 20], [5, 19], [4, 20]]
	view["pieces"] = [{
		"alive": true,
		"id": "fixture-piece",
		"in_reserve": false,
		"piece_type": "rook",
		"position": [5, 20],
		"side": "red",
		"status_tags": [],
	}]
	view["flags"] = [{
		"capture_progress": 1,
		"capturing_side": "red",
		"contested": false,
		"discovered": true,
		"id": "flag-memory",
		"owner": "",
		"position": [4, 12],
	}]
	view["capture_ghosts"] = [{
		"piece_id": "fallen-rook",
		"piece_type": "rook",
		"position": [6, 18],
		"side": "red",
	}]
	view["vision_overlays"] = {
		"rook_paths": [{"piece_id": "fixture-piece", "cells": [[5, 20], [5, 19], [5, 18]]}],
		"elephant_reveal_zones": [{"piece_id": "fixture-elephant", "cells": [
			[2, 10], [3, 10], [4, 10],
			[2, 11], [3, 11], [4, 11], [5, 11],
			[2, 12], [3, 12], [4, 12], [5, 12], [6, 12],
			[3, 13], [4, 13], [5, 13], [6, 13],
			[4, 14], [5, 14], [6, 14],
		]}],
		"elephant_block_fields": [{"piece_id": "fixture-elephant", "cells": [
			[3, 11], [4, 11], [5, 11],
			[3, 12], [4, 12], [5, 12],
			[3, 13], [4, 13], [5, 13],
		]}],
	}
	return view


func _check_delayed_prepare_cancel(match_screen: Control) -> void:
	var port: RefCounted = FixtureMatchClientPort.new(PLAYER_VIEW_PATH)
	port.set_prepare_response_delayed(true)
	match_screen.action_prepare_requested.connect(port.prepare_action)
	match_screen.action_confirm_requested.connect(port.confirm_prepared_action)
	match_screen.prepared_action_cancel_requested.connect(port.cancel_prepared_action)
	port.prepared_action_changed.connect(match_screen.render_prepared_action)
	match_screen.render_action_previews_from_port([{
		"preview_id": "fixture-preview",
		"message_key": "action.move",
	}])
	match_screen.prepare_action("fixture-preview")
	_expect(match_screen.get_local_interaction_state() == "PREVIEW_SELECTED", "delayed prepare must remain in PREVIEW_SELECTED")
	_expect(port.get_pending_prepare_response_count() == 1, "delayed fixture did not retain the prepare response")
	var result: String = match_screen.handle_cancel_or_marker(Vector2i(2, 10))
	_expect(result == "cancel_prepared_action", "in-flight prepare right click must cancel the prepared action")
	_expect(port.count_request("cancel_prepared_action") == 1, "in-flight cancel must reach the port exactly once")
	_expect(port.count_request("confirm_prepared_action") == 0, "in-flight cancel must not confirm")
	_expect(port.flush_next_prepare_response(), "delayed prepare response was unavailable")
	await process_frame
	_expect(match_screen.get_local_interaction_state() == "IDLE", "late prepared response reopened the confirmation UI")
	_expect(port.count_request("cancel_prepared_action") == 1, "late response changed the cancel count")
	_expect(port.count_request("confirm_prepared_action") == 0, "late response caused a confirmation")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
