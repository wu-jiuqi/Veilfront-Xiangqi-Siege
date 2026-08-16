extends RefCounted

const MODE: String = "visible-state-evaluation-v1"
const DIMENSION_IDS: Array[String] = [
	"material", "general_safety", "flag_control", "wall_state",
	"territory", "mobility", "vision", "threat",
]


static func evaluate(
	action: Dictionary,
	player_data: Dictionary,
	public_rules: RefCounted,
	config: Resource,
	baseline: Dictionary = {}
) -> Dictionary:
	if baseline.is_empty():
		baseline = build_baseline(player_data, public_rules, config)
	var viewer_side: String = str(player_data.get("viewer_side", ""))
	var original_pieces: Array = player_data.get("visible_pieces", []).duplicate(true)
	var projected_pieces: Array = _project_pieces(original_pieces, action)
	var actor_id: String = str(action.get("actor_id", ""))
	var original_actor: Dictionary = _find_piece(original_pieces, actor_id)
	var projected_actor: Dictionary = _find_piece(projected_pieces, actor_id)
	var walls: Array = player_data.get("public_walls", [])
	var material_before: int = int(baseline.material)
	var material_after: int = material_before
	for capture: Dictionary in action.get("visible_captures", []):
		material_after += public_rules.piece_value(str(capture.get("piece_type", ""))) \
			* int(config.material_weight)
	var general_before: int = int(baseline.general_safety)
	var general_attackers_after: int = int(_general_attack_context(
		projected_pieces, viewer_side, walls
	).get("attackers", 0))
	var general_after: int = -general_attackers_after * int(config.general_safety_penalty)
	var flag_before: int = int(baseline.flag_control)
	var flag_after: int = _projected_flag_score(action, player_data, viewer_side, config)
	var wall_before: int = int(baseline.wall_state)
	var wall_after: int = wall_before + (int(config.wall_pressure_weight) \
		if bool(action.get("attacks_wall", false)) and str(action.get("kind", "")) != "pass" else 0)
	var territory_before: int = int(baseline.territory)
	var territory_after: int = territory_before
	if str(action.get("kind", "")) == "move" and not original_actor.is_empty():
		var progress_delta: int = _piece_progress(projected_actor, public_rules.board_height()) \
			- _piece_progress(original_actor, public_rules.board_height())
		progress_delta = clampi(
			progress_delta, -int(config.territory_step_cap), int(config.territory_step_cap)
		)
		territory_after += progress_delta * int(config.territory_weight)
	var actor_mobility: Dictionary = baseline.actor_mobility
	var mobility_before: int = int(actor_mobility.get(actor_id, -1))
	if mobility_before < 0:
		mobility_before = _local_mobility(
			original_actor, original_pieces, public_rules.board_width(), public_rules.board_height()
		) * int(config.mobility_weight)
		actor_mobility[actor_id] = mobility_before
	var mobility_after: int = _local_mobility(
		projected_actor, projected_pieces, public_rules.board_width(), public_rules.board_height()
	) * int(config.mobility_weight)
	var actor_contexts: Dictionary = baseline.actor_contexts
	var original_actor_context: Dictionary = actor_contexts.get(actor_id, {})
	if original_actor_context.is_empty():
		original_actor_context = _actor_tactical_context(
			original_pieces, original_actor, viewer_side, walls, public_rules, config
		)
		actor_contexts[actor_id] = original_actor_context
	var projected_actor_context: Dictionary = _actor_tactical_context(
		projected_pieces, projected_actor, viewer_side, walls, public_rules, config
	)
	var vision_after: int = mini(
		int(action.get("reveal_cell_count", 0)), int(config.vision_cell_cap)
	) * int(config.reveal_weight)
	var score_pairs: Dictionary = {
		"material": [material_before, material_after],
		"general_safety": [general_before, general_after],
		"flag_control": [flag_before, flag_after],
		"wall_state": [wall_before, wall_after],
		"territory": [territory_before, territory_after],
		"mobility": [mobility_before, mobility_after],
		"vision": [0, vision_after],
		"threat": [int(original_actor_context.get("score", 0)), int(projected_actor_context.get("score", 0))],
	}
	var dimensions: Dictionary = {}
	var adjustment: int = 0
	var projected_state_score: int = 0
	for dimension_id: String in DIMENSION_IDS:
		var pair: Array = score_pairs[dimension_id]
		var before_score: int = int(pair[0])
		var after_score: int = int(pair[1])
		var delta: int = after_score - before_score
		dimensions[dimension_id] = {
			"before": before_score,
			"after": after_score,
			"delta": delta,
		}
		adjustment += delta
		projected_state_score += after_score
	return {
		"adjustment": adjustment,
		"projected_state_score": projected_state_score,
		"breakdown": {
			"mode": MODE,
			"dimensions": dimensions,
			"visible_attackers": int(projected_actor_context.get("attackers", 0)),
			"visible_supporters": int(projected_actor_context.get("supporters", 0)),
			"unsupported_advance_penalty_before": int(
				original_actor_context.get("unsupported_advance_penalty", 0)
			),
			"unsupported_advance_penalty_after": int(
				projected_actor_context.get("unsupported_advance_penalty", 0)
			),
			"general_attackers_before": int(baseline.general_attackers),
			"general_attackers_after": general_attackers_after,
		},
	}


static func build_baseline(
	player_data: Dictionary,
	public_rules: RefCounted,
	config: Resource
) -> Dictionary:
	var viewer_side: String = str(player_data.get("viewer_side", ""))
	var pieces: Array = player_data.get("visible_pieces", [])
	var walls: Array = player_data.get("public_walls", [])
	var general_attackers: int = int(_general_attack_context(
		pieces, viewer_side, walls
	).get("attackers", 0))
	return {
		"material": _material_score(pieces, viewer_side, public_rules) * int(config.material_weight),
		"general_safety": -general_attackers * int(config.general_safety_penalty),
		"flag_control": _flag_score(player_data.get("public_flags", []), viewer_side, config),
		"wall_state": _wall_score(walls, viewer_side, config),
		"territory": _territory_score(pieces, viewer_side, public_rules.board_height()) \
			* int(config.territory_weight),
		"general_attackers": general_attackers,
		"actor_mobility": {},
		"actor_contexts": {},
	}


static func critical_reasons(
	action: Dictionary,
	player_data: Dictionary,
	public_rules: RefCounted,
	config: Resource,
	current_general_attackers: int = -1
) -> Array[String]:
	var reasons: Array[String] = []
	if str(action.get("kind", "")) == "pass":
		return reasons
	var flags: Array = player_data.get("public_flags", [])
	var pieces: Array = player_data.get("visible_pieces", [])
	for capture: Dictionary in action.get("visible_captures", []):
		var piece_type: String = str(capture.get("piece_type", ""))
		if piece_type == "general":
			reasons.append("capture_general")
		if public_rules.piece_value(piece_type) >= int(config.critical_capture_value):
			reasons.append("high_value_capture")
		var captured_piece: Dictionary = _find_piece(pieces, str(capture.get("piece_id", "")))
		if not captured_piece.is_empty() and _cell_has_flag(_coordinate(captured_piece["position"]), flags):
			reasons.append("defend_flag")
	if bool(action.get("occupies_flag", false)):
		reasons.append("capture_flag")
	var before_attackers: int = current_general_attackers
	if before_attackers < 0:
		before_attackers = general_visible_attacker_count(player_data)
	if before_attackers > 0:
		var viewer_side: String = str(player_data.get("viewer_side", ""))
		var after: Dictionary = _general_attack_context(
			_project_pieces(pieces, action), viewer_side, player_data.get("public_walls", [])
		)
		if int(after.get("attackers", 0)) < before_attackers:
			reasons.append("relieve_general_threat")
	reasons.sort()
	return reasons


static func general_visible_attacker_count(player_data: Dictionary) -> int:
	return int(_general_attack_context(
		player_data.get("visible_pieces", []),
		str(player_data.get("viewer_side", "")),
		player_data.get("public_walls", [])
	).get("attackers", 0))


static func _project_pieces(pieces: Array, action: Dictionary) -> Array:
	var projected: Array = pieces.duplicate(true)
	var captured_ids: Dictionary = {}
	for capture: Dictionary in action.get("visible_captures", []):
		captured_ids[str(capture.get("piece_id", ""))] = true
	for index: int in range(projected.size() - 1, -1, -1):
		if captured_ids.has(str(projected[index].get("id", ""))):
			projected.remove_at(index)
	if str(action.get("kind", "")) == "move":
		var actor: Dictionary = _find_piece(projected, str(action.get("actor_id", "")))
		if not actor.is_empty():
			actor["position"] = action.get("target", actor.get("position", [0, 0])).duplicate()
	return projected


static func _material_score(pieces: Array, viewer_side: String, public_rules: RefCounted) -> int:
	var score: int = 0
	for piece: Dictionary in pieces:
		var value: int = public_rules.piece_value(str(piece.get("piece_type", "")))
		score += value if str(piece.get("side", "")) == viewer_side else -value
	return score


static func _territory_score(pieces: Array, viewer_side: String, board_height: int) -> int:
	var score: int = 0
	for piece: Dictionary in pieces:
		var position := _coordinate(piece.get("position", [0, 0]))
		var side: String = str(piece.get("side", ""))
		var progress: int = position.y if side == "red" else board_height - 1 - position.y
		score += progress if side == viewer_side else -progress
	return score


static func _piece_progress(piece: Dictionary, board_height: int) -> int:
	if piece.is_empty():
		return 0
	var position := _coordinate(piece.get("position", [0, 0]))
	return position.y if str(piece.get("side", "")) == "red" else board_height - 1 - position.y


static func _flag_score(flags: Array, viewer_side: String, config: Resource) -> int:
	var score: int = 0
	for flag: Dictionary in flags:
		var owner: String = str(flag.get("owner", ""))
		if owner == viewer_side:
			score += int(config.flag_weight)
		elif owner == _opponent(viewer_side):
			score -= int(config.flag_weight)
	return score


static func _projected_flag_score(
	action: Dictionary,
	player_data: Dictionary,
	viewer_side: String,
	config: Resource
) -> int:
	var flags: Array = player_data.get("public_flags", [])
	var score: int = _flag_score(flags, viewer_side, config)
	if bool(action.get("occupies_flag", false)) and str(action.get("kind", "")) != "pass":
		var target := _coordinate(action.get("target", [0, 0]))
		for flag: Dictionary in flags:
			if _coordinate(flag.get("position", [0, 0])) == target:
				var owner: String = str(flag.get("owner", ""))
				if owner != viewer_side:
					score += int(config.flag_weight) / 3
					if owner == _opponent(viewer_side):
						score += int(config.flag_weight) / 6
				break
	return score


static func _wall_score(walls: Array, viewer_side: String, config: Resource) -> int:
	var score: int = 0
	for wall: Dictionary in walls:
		var intact_value: int = int(config.wall_pressure_weight) * 2
		var status: String = str(wall.get("status", ""))
		var value: int = intact_value if status == "INTACT" else (-intact_value if status == "BREACHED" else 0)
		score += value if str(wall.get("side", "")) == viewer_side else -value
	return score


static func _general_attack_context(pieces: Array, viewer_side: String, walls: Array) -> Dictionary:
	var general: Dictionary = _find_general(pieces, viewer_side)
	if general.is_empty():
		return {"attackers": 1}
	return {
		"attackers": _attackers_of_cell(
			pieces, _coordinate(general.get("position", [0, 0])), _opponent(viewer_side), walls, ""
		),
	}


static func _actor_tactical_context(
	pieces: Array,
	actor: Dictionary,
	viewer_side: String,
	walls: Array,
	public_rules: RefCounted,
	config: Resource
) -> Dictionary:
	if actor.is_empty() or str(actor.get("side", "")) != viewer_side:
		return {"score": 0, "attackers": 0, "supporters": 0}
	var target := _coordinate(actor.get("position", [0, 0]))
	var attackers: int = _attackers_of_cell(pieces, target, _opponent(viewer_side), walls, "")
	var supporters: int = _attackers_of_cell(pieces, target, viewer_side, walls, str(actor.get("id", "")))
	var actor_value: int = public_rules.piece_value(str(actor.get("piece_type", "")))
	var exposure: int = actor_value * attackers * int(config.threat_penalty_percent) / 100
	var support: int = actor_value * mini(attackers, supporters) \
		* int(config.support_bonus_percent) / 100
	var best_threat: int = _best_actor_threat_value(actor, pieces, viewer_side, walls, public_rules)
	var opportunity: int = best_threat * int(config.threat_opportunity_percent) / 100
	var unsupported_advance: int = 0
	if supporters == 0 and _outside_home_region(actor, public_rules.board_height()):
		unsupported_advance = actor_value \
			* int(config.unsupported_advance_penalty_percent) / 100
	return {
		"score": -exposure + support + opportunity - unsupported_advance,
		"attackers": attackers,
		"supporters": supporters,
		"unsupported_advance_penalty": unsupported_advance,
	}


static func _outside_home_region(piece: Dictionary, board_height: int) -> bool:
	if piece.is_empty():
		return false
	var position := _coordinate(piece.get("position", [0, 0]))
	var region_height: int = board_height / 3
	return position.y >= region_height if str(piece.get("side", "")) == "red" \
		else position.y < board_height - region_height


static func _best_actor_threat_value(
	actor: Dictionary,
	pieces: Array,
	viewer_side: String,
	walls: Array,
	public_rules: RefCounted
) -> int:
	if actor.is_empty():
		return 0
	var occupied: Dictionary = _occupied_cells(pieces)
	var best: int = 0
	for target: Dictionary in pieces:
		if str(target.get("side", "")) == viewer_side:
			continue
		if _piece_attacks_cell(actor, _coordinate(target.get("position", [0, 0])), occupied, walls):
			best = maxi(best, public_rules.piece_value(str(target.get("piece_type", ""))))
	return best


static func _local_mobility(
	actor: Dictionary,
	pieces: Array,
	board_width: int,
	board_height: int
) -> int:
	if actor.is_empty():
		return 0
	var occupied: Dictionary = _occupied_cells(pieces)
	var origin := _coordinate(actor.get("position", [0, 0]))
	var actor_side: String = str(actor.get("side", ""))
	var count: int = 0
	for offset: Vector2i in [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
		Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	]:
		var target: Vector2i = origin + offset
		if target.x < 0 or target.x >= board_width or target.y < 0 or target.y >= board_height:
			continue
		var occupant: Dictionary = occupied.get(_cell_key(target), {})
		if occupant.is_empty() or str(occupant.get("side", "")) != actor_side:
			count += 1
	return count


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


static func _cell_has_flag(cell: Vector2i, flags: Array) -> bool:
	for flag: Dictionary in flags:
		if _coordinate(flag.get("position", [0, 0])) == cell:
			return true
	return false


static func _sum_dimension_scores(scores: Dictionary) -> int:
	var total: int = 0
	for dimension_id: String in DIMENSION_IDS:
		total += int(scores.get(dimension_id, 0))
	return total


static func _coordinate(value: Variant) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))


static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func _opponent(side: String) -> String:
	return "black" if side == "red" else "red"
