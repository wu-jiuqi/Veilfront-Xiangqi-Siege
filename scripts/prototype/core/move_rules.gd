extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const SeededRandom = preload("res://scripts/prototype/core/seeded_random.gd")

const MOVE: String = "move"
const BOMBARD: String = "bombard"
const PASS: String = "pass"


static func evaluate_move(
	state: Dictionary,
	intent: Dictionary,
	actor_side: String,
	visibility_context: Dictionary = {}
) -> Dictionary:
	var piece_id: String = str(intent.get("piece_id", ""))
	if not state["pieces"].has(piece_id):
		return _invalid("unknown_piece")
	var piece: Dictionary = state["pieces"][piece_id]
	if piece["side"] != actor_side or not piece["alive"] or piece["in_reserve"]:
		return _invalid("piece_unavailable")
	var origin := Canonical.coordinate(piece["position"])
	var target := Canonical.coordinate(intent.get("target_cell", []))
	if not MatchState.is_inside_board(target) or target == origin:
		return _invalid("target_out_of_bounds_or_origin")
	var visible_set: Dictionary = visibility_context.get("visible_cell_set", {})
	if visible_set.is_empty():
		visible_set = _cell_set(visibility_context.get("visible_cells", []))
	var visible_piece_ids: Dictionary = visibility_context.get("visible_piece_id_set", {})
	if visible_piece_ids.is_empty():
		for visible_piece_id: Variant in visibility_context.get("visible_piece_ids", []):
			visible_piece_ids[str(visible_piece_id)] = true
	var piece_type: String = str(piece["piece_type"])
	var result: Dictionary
	match piece_type:
		"rook":
			result = _evaluate_rook(state, piece, origin, target)
		"horse":
			result = _evaluate_horse(state, piece, origin, target)
		"elephant":
			result = _evaluate_elephant(state, piece, origin, target)
		"advisor":
			result = _evaluate_advisor(state, piece, origin, target)
		"general":
			result = _evaluate_general(state, piece, origin, target)
		"pawn":
			result = _evaluate_pawn(state, piece, origin, target)
		"cannon":
			result = _evaluate_cannon(state, piece, origin, target, visible_set, visible_piece_ids)
		_:
			result = _invalid("unknown_piece_type")
	if result.get("legal", false) and _blocked_by_intact_wall(state, piece["side"], origin, target):
		return _invalid("intact_wall_blocks_entry", [target])
	result["origin"] = [origin.x, origin.y]
	result["target"] = [target.x, target.y]
	result["piece_id"] = piece_id
	result["piece_type"] = piece_type
	return result


static func generate_legal_actions(state: Dictionary, actor_side: String, visibility_context: Dictionary) -> Array:
	var actions: Array = []
	var piece_ids: Array = state["pieces"].keys()
	piece_ids.sort()
	for piece_id_value: Variant in piece_ids:
		var piece_id: String = str(piece_id_value)
		var piece: Dictionary = state["pieces"][piece_id]
		if piece["side"] != actor_side or not piece["alive"] or piece["in_reserve"]:
			continue
		for target: Vector2i in _geometry_targets(piece):
			if not MatchState.is_inside_board(target):
				continue
			var intent: Dictionary = {
				"piece_id": piece_id,
				"action_type": MOVE,
				"target_cell": [target.x, target.y],
				"skill_type": "",
			}
			var evaluation: Dictionary = evaluate_move(state, intent, actor_side, visibility_context)
			if evaluation.get("legal", false):
				intent["skill_type"] = str(evaluation.get("move_kind", ""))
				actions.append(intent)
		if piece["piece_type"] == "cannon":
			for y: int in range(1, MatchState.BOARD_HEIGHT + 1):
				for x: int in range(1, MatchState.BOARD_WIDTH + 1):
					var bombard_intent: Dictionary = {
						"piece_id": piece_id,
						"action_type": BOMBARD,
						"target_cell": [x, y],
						"skill_type": "area_bombardment",
					}
					if evaluate_bombard(state, bombard_intent, actor_side).get("legal", false):
						actions.append(bombard_intent)
	actions.sort_custom(_intent_less)
	actions.append({"piece_id": "", "action_type": PASS, "target_cell": [], "skill_type": ""})
	return actions


static func evaluate_bombard(state: Dictionary, intent: Dictionary, actor_side: String) -> Dictionary:
	var piece_id: String = str(intent.get("piece_id", ""))
	if not state["pieces"].has(piece_id):
		return _invalid("unknown_piece")
	var cannon: Dictionary = state["pieces"][piece_id]
	if cannon["side"] != actor_side or not cannon["alive"] or cannon["in_reserve"] \
	or cannon["piece_type"] != "cannon":
		return _invalid("bombard_piece_unavailable")
	if not _can_bombard(state, cannon):
		return _invalid("bombard_qualification")
	var center := Canonical.coordinate(intent.get("target_cell", []))
	if center.x < 2 or center.x > 8 or center.y < 7 or center.y > 18:
		return _invalid("bombard_area_out_of_bounds")
	return {
		"legal": true,
		"reason": "",
		"target": [center.x, center.y],
		"skill_type": "area_bombardment",
	}


static func choose_legal_action_fast(
	state: Dictionary,
	actor_side: String,
	visibility_context: Dictionary,
	policy_rng: Dictionary
) -> Dictionary:
	var evaluation_count: int = 0
	var piece_ids: Array = []
	var bombard_piece_ids: Array = []
	for piece_id_value: Variant in state["pieces"].keys():
		var piece_id: String = str(piece_id_value)
		var piece: Dictionary = state["pieces"][piece_id]
		if piece["side"] != actor_side or not piece["alive"] or piece["in_reserve"]:
			continue
		piece_ids.append(piece_id)
		if piece["piece_type"] == "cannon" and _can_bombard(state, piece):
			bombard_piece_ids.append(piece_id)
	piece_ids.sort()
	bombard_piece_ids.sort()
	var prefer_bombard: bool = not bombard_piece_ids.is_empty() \
		and SeededRandom.draw_range(policy_rng, 0, 3, "fast_policy_bombard") == 0
	if prefer_bombard:
		return {"intent": _fast_bombard_intent(bombard_piece_ids, policy_rng), "candidate_evaluations": 0}
	if not piece_ids.is_empty():
		var piece_start: int = SeededRandom.draw_range(
			policy_rng, 0, piece_ids.size() - 1, "fast_policy_piece"
		)
		for piece_offset: int in piece_ids.size():
			var piece_id: String = piece_ids[(piece_start + piece_offset) % piece_ids.size()]
			var piece: Dictionary = state["pieces"][piece_id]
			var targets: Array[Vector2i] = _geometry_targets(piece)
			if targets.is_empty():
				continue
			var target_start: int = SeededRandom.draw_range(
				policy_rng, 0, targets.size() - 1, "fast_policy_target:%s" % piece_id
			)
			for target_offset: int in targets.size():
				var target: Vector2i = targets[(target_start + target_offset) % targets.size()]
				if not MatchState.is_inside_board(target):
					continue
				var intent: Dictionary = {
					"piece_id": piece_id,
					"action_type": MOVE,
					"target_cell": [target.x, target.y],
					"skill_type": "",
				}
				var evaluation: Dictionary = evaluate_move(
					state, intent, actor_side, visibility_context
				)
				evaluation_count += 1
				if evaluation.get("legal", false):
					intent["skill_type"] = evaluation["move_kind"]
					return {"intent": intent, "candidate_evaluations": evaluation_count}
	if not bombard_piece_ids.is_empty():
		return {"intent": _fast_bombard_intent(bombard_piece_ids, policy_rng), "candidate_evaluations": evaluation_count}
	return {
		"intent": {"piece_id": "", "action_type": PASS, "target_cell": [], "skill_type": ""},
		"candidate_evaluations": evaluation_count,
	}


static func movement_path(origin: Vector2i, target: Vector2i) -> Array:
	if origin == target or (origin.x != target.x and origin.y != target.y):
		return []
	var direction := Vector2i(signi(target.x - origin.x), signi(target.y - origin.y))
	var result: Array = []
	var cursor: Vector2i = origin + direction
	while cursor != target + direction:
		result.append(cursor)
		cursor += direction
	return result


static func reveal_cells_for_elephant_move(origin: Vector2i, target: Vector2i) -> Array:
	# Owner-frozen rule: the move's opposite corners define one complete 3x3
	# reveal source, including origin, elephant eye, and target. Legal move
	# validation owns board bounds; this geometry helper does not clip the nine.
	var result: Array = []
	var min_x: int = mini(origin.x, target.x)
	var min_y: int = mini(origin.y, target.y)
	for y: int in range(min_y, min_y + 3):
		for x: int in range(min_x, min_x + 3):
			result.append([x, y])
	return result


static func _evaluate_rook(state: Dictionary, piece: Dictionary, origin: Vector2i, target: Vector2i) -> Dictionary:
	var path: Array = movement_path(origin, target)
	if path.is_empty():
		return _invalid("rook_geometry")
	var special: bool = _special_eligible(state, piece["side"], origin, path)
	var targets: Array = []
	for index: int in path.size():
		var occupant: Dictionary = MatchState.piece_at(state, path[index])
		if occupant.is_empty():
			continue
		if occupant["side"] == piece["side"]:
			return _invalid("own_piece_blocks", [path[index]])
		if special:
			targets.append(occupant["id"])
		elif index < path.size() - 1:
			return _invalid("route_blocked", [path[index]])
		else:
			targets.append(occupant["id"])
	return _valid("rook_special" if special else "rook_standard", path, targets)


static func _evaluate_horse(state: Dictionary, piece: Dictionary, origin: Vector2i, target: Vector2i) -> Dictionary:
	var delta := target - origin
	if not ((absi(delta.x) == 2 and absi(delta.y) == 1) or (absi(delta.x) == 1 and absi(delta.y) == 2)):
		return _invalid("horse_geometry")
	var leg := origin + (Vector2i(signi(delta.x), 0) if absi(delta.x) == 2 else Vector2i(0, signi(delta.y)))
	var special: bool = _special_eligible(state, piece["side"], origin, [leg, target])
	if not special and not MatchState.piece_at(state, leg).is_empty():
		return _invalid("horse_leg_blocked", [leg])
	return _target_capture_result(state, piece, target, "horse_special" if special else "horse_standard", [leg, target])


static func _evaluate_elephant(state: Dictionary, piece: Dictionary, origin: Vector2i, target: Vector2i) -> Dictionary:
	var delta := target - origin
	if absi(delta.x) != 2 or absi(delta.y) != 2:
		return _invalid("elephant_geometry")
	var eye := origin + Vector2i(signi(delta.x), signi(delta.y))
	var special: bool = _special_eligible(state, piece["side"], origin, [eye, target])
	if not special and not MatchState.piece_at(state, eye).is_empty():
		return _invalid("elephant_eye_blocked", [eye])
	return _target_capture_result(state, piece, target, "elephant_special" if special else "elephant_standard", [eye, target])


static func _evaluate_advisor(state: Dictionary, piece: Dictionary, origin: Vector2i, target: Vector2i) -> Dictionary:
	var delta := target - origin
	if absi(delta.x) != 1 or absi(delta.y) != 1 or not _inside_palace(target, piece["side"]):
		return _invalid("advisor_geometry_or_palace")
	return _target_capture_result(state, piece, target, "advisor_standard", [target])


static func _evaluate_general(state: Dictionary, piece: Dictionary, origin: Vector2i, target: Vector2i) -> Dictionary:
	var delta := target - origin
	if absi(delta.x) + absi(delta.y) != 1 or not _inside_palace(target, piece["side"]):
		return _invalid("general_geometry_or_palace")
	return _target_capture_result(state, piece, target, "general_standard", [target])


static func _evaluate_pawn(state: Dictionary, piece: Dictionary, origin: Vector2i, target: Vector2i) -> Dictionary:
	var path: Array = movement_path(origin, target)
	var special: bool = not path.is_empty() and path.size() <= 5 \
		and _special_eligible(state, piece["side"], origin, path)
	if special:
		for cell: Vector2i in path:
			var occupant: Dictionary = MatchState.piece_at(state, cell)
			if occupant.is_empty():
				continue
			if cell == target:
				return _invalid("pawn_special_target_occupied", [cell], true)
			if occupant["side"] == piece["side"]:
				return _invalid("pawn_special_blocked", [cell])
		return _valid("pawn_special", path)
	var delta := target - origin
	var forward: int = 1 if piece["side"] == MatchState.RED else -1
	if not ((delta.y == forward and delta.x == 0) or (delta.y == 0 and absi(delta.x) == 1)):
		return _invalid("pawn_geometry")
	return _target_capture_result(state, piece, target, "pawn_standard", [target])


static func _evaluate_cannon(
	state: Dictionary,
	piece: Dictionary,
	origin: Vector2i,
	target: Vector2i,
	visible_set: Dictionary,
	visible_piece_ids: Dictionary
) -> Dictionary:
	var path: Array = movement_path(origin, target)
	if path.is_empty():
		return _invalid("cannon_geometry")
	var target_piece: Dictionary = MatchState.piece_at(state, target)
	if not target_piece.is_empty() and target_piece["side"] == piece["side"]:
		return _invalid("own_piece_target", [target])
	var screens: Array = []
	for index: int in path.size() - 1:
		if not MatchState.piece_at(state, path[index]).is_empty():
			screens.append(path[index])
	if not target_piece.is_empty() \
	and (not visible_set.has(Canonical.cell_key(target)) or not visible_piece_ids.has(target_piece["id"])):
		if not screens.is_empty():
			return _invalid("cannon_route_blocked", screens)
		return _invalid("cannon_target_occupied_hidden", [target], true)
	if target_piece.is_empty():
		if not screens.is_empty():
			return _invalid("cannon_route_blocked", screens)
		return _valid("cannon_standard", path)
	if screens.size() != 1:
		return _invalid("cannon_screen_count", screens if not screens.is_empty() else path.slice(0, path.size() - 1))
	return _valid("cannon_capture", path, [target_piece["id"]])


static func _target_capture_result(
	state: Dictionary,
	piece: Dictionary,
	target: Vector2i,
	move_kind: String,
	path: Array
) -> Dictionary:
	var target_piece: Dictionary = MatchState.piece_at(state, target)
	if not target_piece.is_empty() and target_piece["side"] == piece["side"]:
		return _invalid("own_piece_target", [target])
	var targets: Array = [] if target_piece.is_empty() else [target_piece["id"]]
	return _valid(move_kind, path, targets)


static func _special_eligible(state: Dictionary, side: String, origin: Vector2i, path: Array) -> bool:
	var enemy_side: String = MatchState.opponent(side)
	if state["walls"][enemy_side]["status"] != "INTACT" or not _inside_special_region(origin):
		return false
	for cell: Vector2i in path:
		if not _inside_special_region(cell):
			return false
	return true


static func _inside_special_region(cell: Vector2i) -> bool:
	return cell.y >= 6 and cell.y <= 19


static func _inside_palace(cell: Vector2i, side: String) -> bool:
	if cell.x < 4 or cell.x > 6:
		return false
	return cell.y >= 1 and cell.y <= 3 if side == MatchState.RED else cell.y >= 22 and cell.y <= 24


static func _blocked_by_intact_wall(
	state: Dictionary,
	side: String,
	origin: Vector2i,
	target: Vector2i
) -> bool:
	var enemy_side: String = MatchState.opponent(side)
	if state["walls"][enemy_side]["status"] != "INTACT":
		return false
	if enemy_side == MatchState.RED:
		return origin.y >= 6 and target.y <= 5
	return origin.y <= 19 and target.y >= 20


static func _can_bombard(state: Dictionary, cannon: Dictionary) -> bool:
	var enemy_side: String = MatchState.opponent(cannon["side"])
	return MatchState.is_in_base(Canonical.coordinate(cannon["position"]), cannon["side"]) \
		and state["walls"][enemy_side]["status"] == "INTACT" \
		and int(cannon["bombard_ammo"]) > 0


static func _fast_bombard_intent(cannon_ids: Array, policy_rng: Dictionary) -> Dictionary:
	var cannon_index: int = SeededRandom.draw_range(
		policy_rng, 0, cannon_ids.size() - 1, "fast_policy_cannon"
	)
	return {
		"piece_id": str(cannon_ids[cannon_index]),
		"action_type": BOMBARD,
		"target_cell": [
			SeededRandom.draw_range(policy_rng, 2, 8, "fast_policy_bombard_x"),
			SeededRandom.draw_range(policy_rng, 7, 18, "fast_policy_bombard_y"),
		],
		"skill_type": "area_bombardment",
	}


static func _geometry_targets(piece: Dictionary) -> Array[Vector2i]:
	var origin := Canonical.coordinate(piece["position"])
	var result: Array[Vector2i] = []
	match str(piece["piece_type"]):
		"rook", "cannon":
			for x: int in range(1, MatchState.BOARD_WIDTH + 1):
				if x != origin.x:
					result.append(Vector2i(x, origin.y))
			for y: int in range(1, MatchState.BOARD_HEIGHT + 1):
				if y != origin.y:
					result.append(Vector2i(origin.x, y))
		"horse":
			for delta: Vector2i in [Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1), Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)]:
				result.append(origin + delta)
		"elephant":
			for delta: Vector2i in [Vector2i(2, 2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(-2, -2)]:
				result.append(origin + delta)
		"advisor":
			for delta: Vector2i in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				result.append(origin + delta)
		"general":
			for delta: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				result.append(origin + delta)
		"pawn":
			for distance: int in range(1, 6):
				for direction: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					result.append(origin + direction * distance)
	return result


static func _cell_set(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for cell_value: Variant in cells:
		var cell := Canonical.coordinate(cell_value)
		if MatchState.is_inside_board(cell):
			result[Canonical.cell_key(cell)] = true
	return result


static func _valid(move_kind: String, path: Array, target_piece_ids: Array = []) -> Dictionary:
	var normalized_path: Array = []
	for cell: Vector2i in path:
		normalized_path.append([cell.x, cell.y])
	return {
		"legal": true,
		"move_kind": move_kind,
		"path": normalized_path,
		"target_piece_ids": target_piece_ids.duplicate(),
		"cause_cells": [],
		"reason": "",
	}


static func _invalid(
	reason: String,
	cause_cells: Array = [],
	contact_reached_target: bool = false
) -> Dictionary:
	var normalized_cells: Array = []
	for cell_value: Variant in cause_cells:
		var cell := Canonical.coordinate(cell_value)
		if MatchState.is_inside_board(cell):
			normalized_cells.append([cell.x, cell.y])
	return {
		"legal": false,
		"move_kind": "",
		"path": [],
		"target_piece_ids": [],
		"cause_cells": normalized_cells,
		"reason": reason,
		"contact_reached_target": contact_reached_target,
	}


static func _intent_less(a: Dictionary, b: Dictionary) -> bool:
	var a_key: String = "%s|%s|%03d|%03d|%s" % [a["action_type"], a["piece_id"], int(a["target_cell"][1]) if a["target_cell"].size() == 2 else -1, int(a["target_cell"][0]) if a["target_cell"].size() == 2 else -1, a["skill_type"]]
	var b_key: String = "%s|%s|%03d|%03d|%s" % [b["action_type"], b["piece_id"], int(b["target_cell"][1]) if b["target_cell"].size() == 2 else -1, int(b["target_cell"][0]) if b["target_cell"].size() == 2 else -1, b["skill_type"]]
	return a_key < b_key
