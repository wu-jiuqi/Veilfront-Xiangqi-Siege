class_name TutorialEffectApplier
extends RefCounted

const Canonical = preload("res://scripts/game/domain/canonical.gd")
const MatchState = preload("res://scripts/game/domain/match_state.gd")


static func apply(
	state: Dictionary,
	scenario: TutorialScenarioDefinition,
	step_id: String
) -> Dictionary:
	if scenario == null or not scenario.is_valid_definition():
		return {"ok": false, "error_code": "tutorial_scenario_invalid"}
	var effect: Dictionary = scenario.effect_for_step(step_id)
	if effect.is_empty():
		return {"ok": true, "applied": false}
	var ghost_ids: Array = effect.get("ghost_piece_ids", [])
	for piece_id_value: Variant in effect.get("remove", []):
		var piece_id := str(piece_id_value)
		if not state["pieces"].has(piece_id):
			continue
		var piece: Dictionary = state["pieces"][piece_id]
		if not bool(piece.get("alive", false)):
			continue
		var position := Canonical.coordinate(piece.get("position", []))
		MatchState.register_casualty(
			state,
			piece_id,
			"tutorial_scripted_outcome",
			position,
			ghost_ids.has(piece_id)
		)
	for piece_id_value: Variant in effect.get("restore_initial", []):
		_restore_initial_piece(state, scenario, str(piece_id_value))
	for piece_id_value: Variant in effect.get("moves", {}).keys():
		var piece_id := str(piece_id_value)
		var cell := Canonical.coordinate(effect["moves"][piece_id_value])
		if state["pieces"].has(piece_id) and MatchState.is_inside_board(cell):
			var occupying: Dictionary = MatchState.piece_at(state, cell)
			if occupying.is_empty() or str(occupying.get("id", "")) == piece_id:
				MatchState.relocate_piece(state, piece_id, cell)
	for piece_id_value: Variant in effect.get("hidden", {}).keys():
		var piece_id := str(piece_id_value)
		if state["pieces"].has(piece_id):
			state["pieces"][piece_id]["hidden"] = bool(effect["hidden"][piece_id_value])
			if not bool(effect["hidden"][piece_id_value]):
				state["pieces"][piece_id]["revealed_to"] = []
	_apply_visibility(state, scenario.bound_seat, effect)
	_apply_vision_sources(state, scenario.bound_seat, effect)
	_apply_flags(state, scenario.bound_seat, effect)
	var wall_status := str(effect.get("black_wall_status", ""))
	if wall_status in ["INTACT", "BREACHED", "REPAIRING"]:
		state["walls"]["black"]["status"] = wall_status
	return {"ok": true, "applied": true}


static func _restore_initial_piece(
	state: Dictionary,
	scenario: TutorialScenarioDefinition,
	piece_id: String
) -> void:
	for definition: Dictionary in scenario.initial_pieces:
		if str(definition.get("id", "")) != piece_id:
			continue
		var cell := Canonical.coordinate(definition.get("position", []))
		if not MatchState.is_inside_board(cell) or not state["pieces"].has(piece_id):
			return
		var occupying: Dictionary = MatchState.piece_at(state, cell)
		if occupying.is_empty() or str(occupying.get("id", "")) == piece_id:
			MatchState.relocate_piece(state, piece_id, cell)
		return


static func _apply_visibility(state: Dictionary, side: String, effect: Dictionary) -> void:
	var cells: Array = state.get("tutorial_visible_cells", {}).get(side, []).duplicate(true)
	var cell_set: Dictionary = {}
	for value: Variant in cells:
		var cell := Canonical.coordinate(value)
		if MatchState.is_inside_board(cell):
			cell_set[Canonical.cell_key(cell)] = [cell.x, cell.y]
	for value: Variant in effect.get("visible_add", []):
		var cell := Canonical.coordinate(value)
		if MatchState.is_inside_board(cell):
			cell_set[Canonical.cell_key(cell)] = [cell.x, cell.y]
	for value: Variant in effect.get("visible_remove", []):
		var cell := Canonical.coordinate(value)
		cell_set.erase(Canonical.cell_key(cell))
	if effect.has("visible_region"):
		var region: Array = effect.get("visible_region", [])
		if region.size() == 2:
			for y: int in range(int(region[0]), int(region[1]) + 1):
				for x: int in range(1, 10):
					cell_set[Canonical.cell_key(Vector2i(x, y))] = [x, y]
	state["tutorial_visible_cells"][side] = cell_set.values()


static func _apply_vision_sources(state: Dictionary, side: String, effect: Dictionary) -> void:
	var sources: Dictionary = state["vision_sources"][side]
	if bool(effect.get("clear_elephant_sources", false)):
		sources["elephant_reveal_zones"].clear()
		sources["elephant_block_fields"].clear()
	for source_id_value: Variant in effect.get("rook_paths", {}).keys():
		sources["rook_paths"][str(source_id_value)] = effect["rook_paths"][source_id_value].duplicate(true)
	for source_id_value: Variant in effect.get("elephant_fields", {}).keys():
		var source_id := str(source_id_value)
		var cells: Array = effect["elephant_fields"][source_id_value].duplicate(true)
		sources["elephant_reveal_zones"][source_id] = cells
		sources["elephant_block_fields"][source_id] = cells


static func _apply_flags(state: Dictionary, side: String, effect: Dictionary) -> void:
	for flag_id_value: Variant in effect.get("discover_flags", []):
		var flag_id := str(flag_id_value)
		if not state["flag_discoveries"][side].has(flag_id):
			state["flag_discoveries"][side].append(flag_id)
	for flag_id_value: Variant in effect.get("flag_progress", {}).keys():
		var flag_id := str(flag_id_value)
		for flag: Dictionary in state["flags"]:
			if str(flag.get("id", "")) != flag_id:
				continue
			var progress := int(effect["flag_progress"][flag_id_value])
			if progress >= 3:
				flag["owner"] = side
				flag["occupier_piece_id"] = ""
				flag["capturing_side"] = ""
				flag["capture_progress"] = 0
				flag["contested"] = false
			else:
				flag["capture_progress"] = progress
				flag["capturing_side"] = side
				if effect.has("flag_occupier"):
					flag["occupier_piece_id"] = str(effect.get("flag_occupier", ""))
			break
