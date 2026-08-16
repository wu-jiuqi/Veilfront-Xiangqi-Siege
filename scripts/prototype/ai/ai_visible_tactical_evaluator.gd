extends RefCounted

const MODE: String = "visible-tactical-one-ply"


static func evaluate(
	action: Dictionary,
	player_data: Dictionary,
	public_rules: RefCounted,
	config: Resource
) -> Dictionary:
	var empty_result: Dictionary = {"adjustment": 0, "breakdown": {"mode": str(config.strategy_mode)}}
	if str(config.strategy_mode) != MODE or str(action.get("kind", "")) != "move":
		return empty_result
	var viewer_side: String = str(player_data.get("viewer_side", ""))
	var actor: Dictionary = _find_piece(player_data.get("visible_pieces", []), str(action.get("actor_id", "")))
	if actor.is_empty() or str(actor.get("side", "")) != viewer_side:
		return empty_result

	var original_pieces: Array = player_data.get("visible_pieces", []).duplicate(true)
	var projected_pieces: Array = original_pieces.duplicate(true)
	var captured_ids: Dictionary = {}
	var capture_value: int = 0
	var captured_general: bool = false
	for capture: Dictionary in action.get("visible_captures", []):
		captured_ids[str(capture.get("piece_id", ""))] = true
		var captured_type: String = str(capture.get("piece_type", ""))
		capture_value += public_rules.piece_value(captured_type)
		captured_general = captured_general or captured_type == "general"
	for index: int in range(projected_pieces.size() - 1, -1, -1):
		if captured_ids.has(str(projected_pieces[index].get("id", ""))):
			projected_pieces.remove_at(index)
	var projected_actor: Dictionary = _find_piece(projected_pieces, str(actor["id"]))
	if projected_actor.is_empty():
		return empty_result
	projected_actor["position"] = action["target"].duplicate()

	var target := _coordinate(action["target"])
	var origin := _coordinate(action["origin"])
	var enemy_side: String = _opponent(viewer_side)
	var walls: Array = player_data.get("public_walls", [])
	var visible_attackers: int = _attackers_of_cell(projected_pieces, target, enemy_side, walls, "")
	var visible_supporters: int = _attackers_of_cell(
		projected_pieces, target, viewer_side, walls, str(actor["id"])
	)
	var actor_value: int = public_rules.piece_value(str(actor["piece_type"]))
	var capture_bonus: int = capture_value * maxi(int(config.capture_priority_multiplier) - 1, 0)
	var threat_penalty: int = 0
	if not captured_general:
		threat_penalty = actor_value * visible_attackers * int(config.threat_penalty_percent) / 100
	var support_bonus: int = actor_value * mini(visible_supporters, visible_attackers) \
		* int(config.support_bonus_percent) / 100

	var forward_delta: int = target.y - origin.y if viewer_side == "red" else origin.y - target.y
	var advance_bonus: int = forward_delta * int(config.advance_weight)
	var origin_center_distance: int = absi(origin.x - 4) * 2 + absi(origin.y * 2 - 23)
	var target_center_distance: int = absi(target.x - 4) * 2 + absi(target.y * 2 - 23)
	var center_bonus: int = (origin_center_distance - target_center_distance) * int(config.center_control_weight)

	var flag_bonus: int = 0
	for flag: Dictionary in player_data.get("public_flags", []):
		if _coordinate(flag.get("position", [0, 0])) != target:
			continue
		if str(flag.get("owner", "")) != viewer_side:
			flag_bonus += int(config.flag_weight)
		flag_bonus += int(flag.get("capture_progress", 0)) * int(config.flag_weight) / 3
		break

	var breach_pressure_bonus: int = 0
	if _wall_status(walls, enemy_side) != "INTACT" and _in_buffer_or_base(target, enemy_side):
		breach_pressure_bonus = int(config.wall_pressure_weight) * 2

	var original_general: Dictionary = _find_general(original_pieces, viewer_side)
	var projected_general: Dictionary = _find_general(projected_pieces, viewer_side)
	var general_attackers_before: int = 0
	var general_attackers_after: int = 0
	if not original_general.is_empty():
		general_attackers_before = _attackers_of_cell(
			original_pieces, _coordinate(original_general["position"]), enemy_side, walls, ""
		)
	if not projected_general.is_empty():
		general_attackers_after = _attackers_of_cell(
			projected_pieces, _coordinate(projected_general["position"]), enemy_side, walls, ""
		)
	var general_safety_adjustment: int = (general_attackers_before - general_attackers_after) \
		* int(config.general_safety_penalty)

	var adjustment: int = capture_bonus - threat_penalty + support_bonus + advance_bonus \
		+ center_bonus + flag_bonus + breach_pressure_bonus + general_safety_adjustment
	return {
		"adjustment": adjustment,
		"breakdown": {
			"mode": MODE,
			"capture_bonus": capture_bonus,
			"visible_attackers": visible_attackers,
			"visible_supporters": visible_supporters,
			"threat_penalty": threat_penalty,
			"support_bonus": support_bonus,
			"advance_bonus": advance_bonus,
			"center_bonus": center_bonus,
			"flag_bonus": flag_bonus,
			"breach_pressure_bonus": breach_pressure_bonus,
			"general_attackers_before": general_attackers_before,
			"general_attackers_after": general_attackers_after,
			"general_safety_adjustment": general_safety_adjustment,
		},
	}


static func _attackers_of_cell(
	pieces: Array,
	target: Vector2i,
	attacker_side: String,
	walls: Array,
	excluded_piece_id: String
) -> int:
	var occupied: Dictionary = _occupied_cells(pieces)
	var count: int = 0
	for piece: Dictionary in pieces:
		if str(piece.get("side", "")) != attacker_side \
		or str(piece.get("id", "")) == excluded_piece_id:
			continue
		if _piece_attacks_cell(piece, target, occupied, walls):
			count += 1
	return count


static func _piece_attacks_cell(
	piece: Dictionary,
	target: Vector2i,
	occupied: Dictionary,
	walls: Array
) -> bool:
	var origin := _coordinate(piece.get("position", [0, 0]))
	var delta := target - origin
	if delta == Vector2i.ZERO:
		return false
	var side: String = str(piece.get("side", ""))
	match str(piece.get("piece_type", "")):
		"rook":
			if delta.x != 0 and delta.y != 0:
				return false
			if _special_eligible(side, origin, target, walls):
				return not _line_has_friendly_blocker(origin, target, occupied, side)
			return _line_screen_count(origin, target, occupied) == 0
		"cannon":
			return (delta.x == 0 or delta.y == 0) \
				and _line_screen_count(origin, target, occupied) == 1
		"horse":
			if not ((absi(delta.x) == 2 and absi(delta.y) == 1) \
			or (absi(delta.x) == 1 and absi(delta.y) == 2)):
				return false
			if _special_eligible(side, origin, target, walls):
				return true
			var leg := origin + (Vector2i(signi(delta.x), 0) \
				if absi(delta.x) == 2 else Vector2i(0, signi(delta.y)))
			return not occupied.has(_cell_key(leg))
		"elephant":
			if absi(delta.x) != 2 or absi(delta.y) != 2:
				return false
			if _special_eligible(side, origin, target, walls):
				return true
			return not occupied.has(_cell_key(origin + Vector2i(signi(delta.x), signi(delta.y))))
		"advisor":
			return absi(delta.x) == 1 and absi(delta.y) == 1
		"general":
			return absi(delta.x) + absi(delta.y) == 1
		"pawn":
			var forward: int = 1 if side == "red" else -1
			return (delta.y == forward and delta.x == 0) or (delta.y == 0 and absi(delta.x) == 1)
	return false


static func _line_screen_count(origin: Vector2i, target: Vector2i, occupied: Dictionary) -> int:
	if origin.x != target.x and origin.y != target.y:
		return 999
	var step := Vector2i(signi(target.x - origin.x), signi(target.y - origin.y))
	var cursor: Vector2i = origin + step
	var count: int = 0
	while cursor != target:
		if occupied.has(_cell_key(cursor)):
			count += 1
		cursor += step
	return count


static func _line_has_friendly_blocker(
	origin: Vector2i,
	target: Vector2i,
	occupied: Dictionary,
	attacker_side: String
) -> bool:
	var step := Vector2i(signi(target.x - origin.x), signi(target.y - origin.y))
	var cursor: Vector2i = origin + step
	while cursor != target:
		var blocker: Dictionary = occupied.get(_cell_key(cursor), {})
		if not blocker.is_empty() and str(blocker.get("side", "")) == attacker_side:
			return true
		cursor += step
	return false


static func _special_eligible(side: String, origin: Vector2i, target: Vector2i, walls: Array) -> bool:
	return _wall_status(walls, _opponent(side)) == "INTACT" \
		and origin.y >= 5 and origin.y <= 18 and target.y >= 5 and target.y <= 18


static func _in_buffer_or_base(cell: Vector2i, side: String) -> bool:
	return cell.y <= 7 if side == "red" else cell.y >= 16


static func _wall_status(walls: Array, side: String) -> String:
	for wall: Dictionary in walls:
		if str(wall.get("side", "")) == side:
			return str(wall.get("status", ""))
	return ""


static func _occupied_cells(pieces: Array) -> Dictionary:
	var result: Dictionary = {}
	for piece: Dictionary in pieces:
		result[_cell_key(_coordinate(piece.get("position", [0, 0])))] = piece
	return result


static func _find_piece(pieces: Array, piece_id: String) -> Dictionary:
	for piece: Dictionary in pieces:
		if str(piece.get("id", "")) == piece_id:
			return piece
	return {}


static func _find_general(pieces: Array, side: String) -> Dictionary:
	for piece: Dictionary in pieces:
		if str(piece.get("side", "")) == side and str(piece.get("piece_type", "")) == "general":
			return piece
	return {}


static func _coordinate(value: Variant) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))


static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func _opponent(side: String) -> String:
	return "black" if side == "red" else "red"
