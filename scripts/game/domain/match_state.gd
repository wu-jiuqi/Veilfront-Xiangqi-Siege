extends RefCounted

const Canonical = preload("res://scripts/game/domain/canonical.gd")
const SeededRandom = preload("res://scripts/game/domain/seeded_random.gd")

const BOARD_WIDTH: int = 9
const BOARD_HEIGHT: int = 24
const RED: String = "red"
const BLACK: String = "black"
const NEUTRAL: String = "neutral"
const DEFAULT_FULL_ROUND_LIMIT_HYPOTHESIS: int = 50


static func create(seed_value: int, configuration: Dictionary = {}) -> Dictionary:
	var round_limit: int = int(configuration.get(
		"full_round_limit_hypothesis", DEFAULT_FULL_ROUND_LIMIT_HYPOTHESIS
	))
	assert(round_limit > 0)
	var state: Dictionary = {
		"schema_version": "veilfront-full-state-v1",
		"match_id": str(configuration.get("match_id", "match-%d" % seed_value)),
		"rules_revision": "owner-confirm-2026-08-17-gate1-rule-v5",
		"implementation_revision": "formal-core-revision-1",
		"configuration": {
			"full_round_limit_hypothesis": round_limit,
			"round_limit_status": "hypothesis_cli_overridable",
		},
		"board_width": BOARD_WIDTH,
		"board_height": BOARD_HEIGHT,
		"active_side": RED,
		"action_index": 0,
		"full_round_index": 0,
		"terminal": false,
		"winner": "",
		"win_reason": "",
		"board": {},
		"pieces": {},
		"walls": {
			RED: _new_wall(RED),
			BLACK: _new_wall(BLACK),
		},
		"flags": [],
		"flag_discoveries": {RED: [], BLACK: []},
		"casualty_pools": {RED: [], BLACK: []},
		"capture_ghosts": {RED: [], BLACK: []},
		"reserve_queues": {RED: [], BLACK: []},
		"contact_intel": {RED: [], BLACK: []},
		"vision_sources": {
			RED: {"rook_paths": {}, "elephant_reveal_zones": {}, "elephant_block_fields": {}},
			BLACK: {"rook_paths": {}, "elephant_reveal_zones": {}, "elephant_block_fields": {}},
		},
		"events": [],
		"player_events": {RED: [], BLACK: []},
		"rng": SeededRandom.create_state(seed_value),
	}
	_add_initial_army(state, RED)
	_add_initial_army(state, BLACK)
	state["flags"] = _create_flags(state)
	return state


static func clone(state: Dictionary) -> Dictionary:
	return state.duplicate(true)


static func opponent(side: String) -> String:
	return BLACK if side == RED else RED


static func is_inside_board(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= BOARD_WIDTH and cell.y >= 1 and cell.y <= BOARD_HEIGHT


static func is_in_base(cell: Vector2i, side: String) -> bool:
	if side == RED:
		return cell.y >= 1 and cell.y <= 3
	return cell.y >= 22 and cell.y <= 24


static func is_in_buffer_or_base(cell: Vector2i, side: String) -> bool:
	if side == RED:
		return cell.y >= 1 and cell.y <= 8
	return cell.y >= 17 and cell.y <= 24


static func is_in_buffer(cell: Vector2i, side: String) -> bool:
	if side == RED:
		return cell.y >= 4 and cell.y <= 8
	return cell.y >= 17 and cell.y <= 21


static func piece_at(state: Dictionary, cell: Vector2i) -> Dictionary:
	var piece_id: String = str(state["board"].get(Canonical.cell_key(cell), ""))
	if piece_id.is_empty():
		return {}
	return state["pieces"].get(piece_id, {})


static func relocate_piece(state: Dictionary, piece_id: String, cell: Vector2i) -> void:
	assert(is_inside_board(cell))
	var piece: Dictionary = state["pieces"][piece_id]
	var previous: Vector2i = Canonical.coordinate(piece.get("position", []))
	if is_inside_board(previous):
		state["board"].erase(Canonical.cell_key(previous))
	var occupying: Dictionary = piece_at(state, cell)
	assert(occupying.is_empty() or occupying["id"] == piece_id)
	piece["position"] = [cell.x, cell.y]
	piece["alive"] = true
	piece["in_reserve"] = false
	if state.has("casualty_pools") and state["casualty_pools"].has(piece["side"]):
		state["casualty_pools"][piece["side"]].erase(piece_id)
	state["board"][Canonical.cell_key(cell)] = piece_id


static func register_casualty(
	state: Dictionary,
	piece_id: String,
	reason: String,
	position: Vector2i,
	leave_capture_ghost: bool = false
) -> void:
	assert(state["pieces"].has(piece_id))
	var piece: Dictionary = state["pieces"][piece_id]
	var side: String = str(piece["side"])
	remove_piece_from_board(state, piece_id)
	piece["alive"] = false
	piece["in_reserve"] = false
	piece["reserve_queue_index"] = -1
	if state.has("reserve_queues") and state["reserve_queues"].has(side):
		state["reserve_queues"][side].erase(piece_id)
	var pool: Array = state["casualty_pools"][side]
	if not pool.has(piece_id):
		pool.append(piece_id)
		pool.sort()
	if not leave_capture_ghost or not is_inside_board(position):
		return
	var ghosts: Array = state["capture_ghosts"][side]
	for index: int in range(ghosts.size() - 1, -1, -1):
		if str(ghosts[index].get("piece_id", "")) == piece_id:
			ghosts.remove_at(index)
	ghosts.append({
		"piece_id": piece_id,
		"piece_type": str(piece["piece_type"]),
		"side": side,
		"position": [position.x, position.y],
		"reason": reason,
		"created_at_action_index": int(state["action_index"]),
		"expires_at_action_index": int(state["action_index"]) + 2,
	})


static func remove_piece_from_board(state: Dictionary, piece_id: String) -> void:
	var piece: Dictionary = state["pieces"][piece_id]
	var position: Vector2i = Canonical.coordinate(piece.get("position", []))
	if is_inside_board(position):
		state["board"].erase(Canonical.cell_key(position))
	piece["position"] = []


static func base_empty_cells(state: Dictionary, side: String) -> Array:
	var result: Array = []
	var first_y: int = 1 if side == RED else 22
	var last_y: int = 3 if side == RED else 24
	for y: int in range(first_y, last_y + 1):
		for x: int in range(1, BOARD_WIDTH + 1):
			var cell := Vector2i(x, y)
			if piece_at(state, cell).is_empty():
				result.append(cell)
	return result


static func summary(state: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {
		"schema_version": state["schema_version"],
		"match_id": state["match_id"],
		"rules_revision": state["rules_revision"],
		"implementation_revision": state["implementation_revision"],
		"configuration": state["configuration"],
		"active_side": state["active_side"],
		"action_index": state["action_index"],
		"full_round_index": state["full_round_index"],
		"terminal": state["terminal"],
		"winner": state["winner"],
		"win_reason": state["win_reason"],
		"board": state["board"],
		"pieces": state["pieces"],
		"walls": state["walls"],
		"flags": state["flags"],
		"flag_discoveries": state["flag_discoveries"],
		"casualty_pools": state["casualty_pools"],
		"capture_ghosts": state["capture_ghosts"],
		"reserve_queues": state["reserve_queues"],
		"contact_intel": state["contact_intel"],
		"vision_sources": state["vision_sources"],
		"rng": {
			"seed": state["rng"]["seed"],
			"state": state["rng"]["state"],
			"draw_index": state["rng"]["draw_index"],
		},
	}
	return {
		"schema_version": "state-summary-v1",
		"action_index": state["action_index"],
		"full_round_index": state["full_round_index"],
		"state_digest": Canonical.digest(snapshot),
		"event_log_digest": Canonical.digest(state["events"]),
	}


static func _new_wall(side: String) -> Dictionary:
	return {
		"side": side,
		"status": "INTACT",
		"repair_start_action_index": -1,
		"sides_acted_since_repair_start": [],
		"invading_piece_count": 0,
	}


static func _add_initial_army(state: Dictionary, side: String) -> void:
	var home_y: int = 1 if side == RED else 24
	var cannon_y: int = 3 if side == RED else 22
	var pawn_y: int = 4 if side == RED else 21
	var home_types: Array[String] = [
		"rook", "horse", "elephant", "advisor", "general",
		"advisor", "elephant", "horse", "rook",
	]
	var type_counts: Dictionary = {}
	for x: int in range(1, 10):
		var piece_type: String = home_types[x - 1]
		type_counts[piece_type] = int(type_counts.get(piece_type, 0)) + 1
		_add_piece(state, "%s-%s-%d" % [side, piece_type, type_counts[piece_type]], side, piece_type, Vector2i(x, home_y))
	for cannon_x: int in [2, 8]:
		type_counts["cannon"] = int(type_counts.get("cannon", 0)) + 1
		_add_piece(state, "%s-cannon-%d" % [side, type_counts["cannon"]], side, "cannon", Vector2i(cannon_x, cannon_y))
	for pawn_x: int in [1, 3, 5, 7, 9]:
		type_counts["pawn"] = int(type_counts.get("pawn", 0)) + 1
		_add_piece(state, "%s-pawn-%d" % [side, type_counts["pawn"]], side, "pawn", Vector2i(pawn_x, pawn_y))


static func _add_piece(
	state: Dictionary,
	piece_id: String,
	side: String,
	piece_type: String,
	position: Vector2i
) -> void:
	var piece: Dictionary = {
		"id": piece_id,
		"side": side,
		"piece_type": piece_type,
		"position": [position.x, position.y],
		"alive": true,
		"in_reserve": false,
		"reserve_queue_index": -1,
		"hidden": false,
		"revealed_to": [],
		"bombard_ammo": 2 if piece_type == "cannon" else 0,
		"temporary_effects": [],
	}
	state["pieces"][piece_id] = piece
	state["board"][Canonical.cell_key(position)] = piece_id


static func _create_flags(state: Dictionary) -> Array:
	var candidates: Array = []
	for y: int in range(9, 17):
		for x: int in range(1, BOARD_WIDTH + 1):
			candidates.append(Vector2i(x, y))
	var cells: Array = SeededRandom.draw_unique(state["rng"], candidates, 3, "flag_cell")
	var flags: Array = []
	for index: int in cells.size():
		var cell: Vector2i = cells[index]
		flags.append({
			"id": "flag-%d" % (index + 1),
			"position": [cell.x, cell.y],
			"owner": NEUTRAL,
			"occupier_piece_id": "",
			"capturing_side": "",
			"capture_progress": 0,
			"contested": false,
		})
	return flags
