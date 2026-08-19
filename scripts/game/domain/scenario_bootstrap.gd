class_name ScenarioBootstrap
extends RefCounted

const Canonical = preload("res://scripts/game/domain/canonical.gd")
const MatchState = preload("res://scripts/game/domain/match_state.gd")


static func create_validated(
	base_state: Dictionary,
	scenario: TutorialScenarioDefinition
) -> Dictionary:
	if scenario == null or not scenario.is_valid_definition() or not base_state is Dictionary:
		return {"ok": false, "error_code": "invalid_scenario", "state": {}}
	var state: Dictionary = base_state.duplicate(true)
	state["match_id"] = scenario.scenario_id
	state["active_side"] = scenario.bound_seat
	state["action_index"] = 0
	state["full_round_index"] = 0
	state["terminal"] = false
	state["winner"] = ""
	state["win_reason"] = ""
	state["board"] = {}
	state["pieces"] = {}
	state["flags"] = []
	state["flag_discoveries"] = {"red": [], "black": []}
	state["casualty_pools"] = {"red": [], "black": []}
	state["capture_ghosts"] = {"red": [], "black": []}
	state["reserve_queues"] = {"red": [], "black": []}
	state["contact_intel"] = {"red": [], "black": []}
	state["vision_sources"] = {
		"red": {"rook_paths": {}, "elephant_reveal_zones": {}, "elephant_block_fields": {}},
		"black": {"rook_paths": {}, "elephant_reveal_zones": {}, "elephant_block_fields": {}},
	}
	state["events"] = []
	state["player_events"] = {"red": [], "black": []}
	state["walls"]["red"] = _wall("red", "INTACT")
	state["walls"]["black"] = _wall("black", scenario.black_wall_status)
	state["tutorial_visible_cells"] = {
		scenario.bound_seat: _coordinate_arrays(scenario.initial_visible_cells),
	}

	for piece_definition: Dictionary in scenario.initial_pieces:
		_add_piece(state, piece_definition, true)
	for casualty_definition: Dictionary in scenario.initial_casualties:
		_add_piece(state, casualty_definition, false)
		state["casualty_pools"][str(casualty_definition.get("side", "red"))].append(
			str(casualty_definition.get("id", ""))
		)
	for flag_definition: Dictionary in scenario.initial_flags:
		var flag_id := str(flag_definition.get("id", ""))
		var position: Array = flag_definition.get("position", []).duplicate()
		state["flags"].append({
			"id": flag_id,
			"position": position,
			"owner": str(flag_definition.get("owner", "neutral")),
			"occupier_piece_id": "",
			"capturing_side": "",
			"capture_progress": 0,
			"contested": false,
		})
		for side_value: Variant in flag_definition.get("discovered_by", []):
			var side := str(side_value)
			if side in ["red", "black"]:
				state["flag_discoveries"][side].append(flag_id)
	return {"ok": true, "error_code": "", "state": state}


static func _add_piece(state: Dictionary, definition: Dictionary, alive: bool) -> void:
	var piece_id := str(definition.get("id", ""))
	var side := str(definition.get("side", ""))
	var piece_type := str(definition.get("piece_type", ""))
	var position: Array = definition.get("position", []).duplicate() if alive else []
	var piece := {
		"id": piece_id,
		"side": side,
		"piece_type": piece_type,
		"position": position,
		"alive": alive,
		"in_reserve": false,
		"reserve_queue_index": -1,
		"hidden": bool(definition.get("hidden", false)),
		"revealed_to": [],
		"bombard_ammo": int(definition.get("bombard_ammo", 2 if piece_type == "cannon" else 0)),
		"temporary_effects": [],
	}
	state["pieces"][piece_id] = piece
	if alive:
		state["board"][Canonical.cell_key(Canonical.coordinate(position))] = piece_id


static func _wall(side: String, status: String) -> Dictionary:
	return {
		"side": side,
		"status": status,
		"repair_start_action_index": -1,
		"sides_acted_since_repair_start": [],
		"invading_piece_count": 0,
	}


static func _coordinate_arrays(values: Array[Vector2i]) -> Array:
	var result: Array = []
	for cell: Vector2i in values:
		if MatchState.is_inside_board(cell):
			result.append([cell.x, cell.y])
	return result
