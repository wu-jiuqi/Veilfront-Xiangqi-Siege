extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const MoveRules = preload("res://scripts/prototype/core/move_rules.gd")

const KNOWN_LEGAL: String = "KNOWN_LEGAL"
const TENTATIVE: String = "TENTATIVE"
const KNOWN_ILLEGAL: String = "KNOWN_ILLEGAL"


static func visibility_context(full_state: Dictionary, viewer_side: String) -> Dictionary:
	var visible_cell_set: Dictionary = _visible_cell_set(full_state, viewer_side)
	var visible_cells: Array = []
	for key: String in visible_cell_set.keys():
		var parts: PackedStringArray = key.split(",")
		visible_cells.append([int(parts[0]), int(parts[1])])
	visible_cells.sort_custom(_coordinate_less)
	var visible_piece_ids: Array = []
	for piece_value: Variant in full_state["pieces"].values():
		var piece: Dictionary = piece_value
		if piece["side"] == viewer_side:
			visible_piece_ids.append(piece["id"])
			continue
		if not piece["alive"] or piece["in_reserve"]:
			continue
		var position := Canonical.coordinate(piece["position"])
		var normally_visible: bool = visible_cell_set.has(Canonical.cell_key(position))
		var elephant_revealed: bool = piece["hidden"] and _in_elephant_reveal_zone(full_state, position, viewer_side)
		if (normally_visible and _enemy_piece_revealed(full_state, piece, viewer_side)) or elephant_revealed:
			visible_piece_ids.append(piece["id"])
	visible_piece_ids.sort()
	var visible_piece_id_set: Dictionary = {}
	for piece_id: String in visible_piece_ids:
		visible_piece_id_set[piece_id] = true
	return {
		"visible_cells": visible_cells,
		"visible_piece_ids": visible_piece_ids,
		"visible_cell_set": visible_cell_set,
		"visible_piece_id_set": visible_piece_id_set,
	}


static func is_cell_visible(full_state: Dictionary, viewer_side: String, cell: Vector2i) -> bool:
	return _visible_cell_set(full_state, viewer_side).has(Canonical.cell_key(cell))


static func project(full_state: Dictionary, viewer_side: String) -> Dictionary:
	assert(viewer_side == MatchState.RED or viewer_side == MatchState.BLACK)
	var visible_cell_set: Dictionary = _visible_cell_set(full_state, viewer_side)
	var pieces: Array = []
	for piece_value: Variant in full_state["pieces"].values():
		var piece: Dictionary = piece_value
		if piece["side"] == viewer_side:
			pieces.append(_public_piece(piece, true))
			continue
		if not piece["alive"] or piece["in_reserve"]:
			continue
		var position := Canonical.coordinate(piece["position"])
		var normally_visible: bool = visible_cell_set.has(Canonical.cell_key(position))
		var elephant_revealed: bool = piece["hidden"] and _in_elephant_reveal_zone(full_state, position, viewer_side)
		if (normally_visible and _enemy_piece_revealed(full_state, piece, viewer_side)) or elephant_revealed:
			pieces.append(_public_piece(piece, false))
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])

	var visible_cells: Array = []
	for key: String in visible_cell_set.keys():
		var parts: PackedStringArray = key.split(",")
		visible_cells.append([int(parts[0]), int(parts[1])])
	visible_cells.sort_custom(_coordinate_less)
	var hidden_detection_cells: Array = _hidden_detection_cells(full_state, viewer_side)
	var visible_piece_ids: Dictionary = {}
	for piece: Dictionary in pieces:
		visible_piece_ids[piece["id"]] = true

	return {
		"schema_version": "player-view-v1",
		"match_seed": int(full_state["rng"]["seed"]),
		"rules_revision": str(full_state["rules_revision"]),
		"implementation_revision": str(full_state["implementation_revision"]),
		"full_round_limit_hypothesis": int(full_state["configuration"]["full_round_limit_hypothesis"]),
		"round_limit_status": str(full_state["configuration"]["round_limit_status"]),
		"viewer_side": viewer_side,
		"board_width": full_state["board_width"],
		"board_height": full_state["board_height"],
		"active_side": full_state["active_side"],
		"action_index": full_state["action_index"],
		"full_round_index": full_state["full_round_index"],
		"terminal": full_state["terminal"],
		"winner": full_state["winner"],
		"win_reason": full_state["win_reason"],
		"visible_cells": visible_cells,
		"hidden_detection_cells": hidden_detection_cells,
		"pieces": pieces,
		"flags": _public_flags(full_state, viewer_side, visible_piece_ids),
		"walls": _public_walls(full_state),
		"player_events": full_state["player_events"][viewer_side].duplicate(true),
		"contact_intel": full_state["contact_intel"][viewer_side].duplicate(true),
	}


static func list_action_intents(player_view: Dictionary, intents: Array) -> Array:
	var previews: Array = []
	for intent_value: Variant in intents:
		previews.append(preview_intent(player_view, intent_value))
	previews.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	return previews


static func generate_action_intents(player_view: Dictionary) -> Array:
	var intents: Array = []
	for piece: Dictionary in player_view["pieces"]:
		if piece["side"] != player_view["viewer_side"] or not piece["alive"] \
		or piece["in_reserve"] or piece["position"].is_empty():
			continue
		for intent: Dictionary in _geometry_intents_for_piece(piece):
			intents.append(intent)
		if piece["piece_type"] == "cannon":
			for y: int in range(7, 19):
				for x: int in range(2, 9):
					intents.append({
						"piece_id": piece["id"],
						"action_type": "bombard",
						"target_cell": [x, y],
						"skill_type": "area_bombardment",
					})
	intents.append({"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""})
	return list_action_intents(player_view, intents)


static func preview_intent(player_view: Dictionary, intent: Dictionary) -> Dictionary:
	var piece_id: String = str(intent.get("piece_id", ""))
	var action_type: String = str(intent.get("action_type", ""))
	var target := Canonical.coordinate(intent.get("target_cell", []))
	var skill_type: String = str(intent.get("skill_type", ""))
	var piece: Dictionary = _find_piece(player_view, piece_id)
	var classification: String = KNOWN_ILLEGAL
	var public_code: String = "known_illegal"
	if action_type in ["pass", "skip", "timeout"]:
		classification = KNOWN_LEGAL
		public_code = ""
	elif not piece.is_empty() and piece["side"] == player_view["viewer_side"]:
		if action_type == "bombard":
			if _public_bombard_available(player_view, piece, target):
				classification = KNOWN_LEGAL
				public_code = ""
		elif action_type == "move" and MatchState.is_inside_board(target):
			classification = _preview_move(player_view, piece, target)
			public_code = "known_illegal" if classification == KNOWN_ILLEGAL else ""
	return {
		"schema_version": "action-preview-v1",
		"id": _action_id(piece_id, action_type, target, skill_type),
		"classification": classification,
		"piece_id": piece_id,
		"action_type": action_type,
		"target_cell": [target.x, target.y],
		"skill_type": skill_type,
		"error": {"code": public_code, "fields": []},
	}


static func export_ai_projection(player_view: Dictionary, intents: Array) -> Dictionary:
	var previews: Array = list_action_intents(player_view, intents)
	var actions: Array = []
	for preview: Dictionary in previews:
		if preview["classification"] == KNOWN_ILLEGAL:
			continue
		if preview["action_type"] in ["pass", "skip", "timeout"]:
			actions.append({
				"id": preview["id"],
				"kind": preview["action_type"],
				"actor_id": "",
				# AI DTO v1 keeps fixed two-int coordinates. kind=pass makes the
				# zero sentinel non-spatial; consumers must not interpret it as a cell.
				"origin": [0, 0],
				"target": [0, 0],
				"visible_captures": [],
				"reveal_cell_count": 0,
				"occupies_flag": false,
				"attacks_wall": false,
				"path_length": 0,
			})
			continue
		var piece: Dictionary = _find_piece(player_view, preview["piece_id"])
		var origin := Canonical.coordinate(piece["position"])
		var target := Canonical.coordinate(preview["target_cell"])
		var target_piece: Dictionary = _visible_piece_at(player_view, target)
		var visible_captures: Array = []
		var is_move: bool = preview["action_type"] == "move"
		if is_move and piece["piece_type"] == "rook":
			var rook_path: Array = MoveRules.movement_path(origin, target)
			if _public_special_eligible(player_view, piece["side"], origin, rook_path):
				for path_cell: Vector2i in rook_path:
					var path_piece: Dictionary = _visible_piece_at(player_view, path_cell)
					if not path_piece.is_empty() and path_piece["side"] != piece["side"]:
						visible_captures.append({
							"piece_id": path_piece["id"],
							"piece_type": path_piece["piece_type"],
						})
			elif not target_piece.is_empty() and target_piece["side"] != piece["side"]:
				visible_captures.append({"piece_id": target_piece["id"], "piece_type": target_piece["piece_type"]})
		elif is_move and not target_piece.is_empty() and target_piece["side"] != piece["side"]:
			visible_captures.append({"piece_id": target_piece["id"], "piece_type": target_piece["piece_type"]})
		actions.append({
			"id": preview["id"],
			"kind": preview["action_type"],
			"actor_id": preview["piece_id"],
			"origin": [origin.x - 1, origin.y - 1],
			"target": [target.x - 1, target.y - 1],
			"visible_captures": visible_captures,
			"reveal_cell_count": _newly_revealed_cell_count(player_view, target) if is_move else 0,
			"occupies_flag": (_flag_at(player_view, target) != {}) if is_move else false,
			"attacks_wall": false,
			"path_length": absi(target.x - origin.x) + absi(target.y - origin.y) if is_move else 0,
		})
	var visible_pieces: Array = []
	for piece: Dictionary in player_view["pieces"]:
		if piece["position"].is_empty():
			continue
		var position := Canonical.coordinate(piece["position"])
		visible_pieces.append({
			"id": piece["id"],
			"side": piece["side"],
			"piece_type": piece["piece_type"],
			"position": [position.x - 1, position.y - 1],
			"status_tags": piece["status_tags"].duplicate(),
		})
	var public_flags: Array = []
	for flag: Dictionary in player_view["flags"]:
		var position := Canonical.coordinate(flag["position"])
		public_flags.append({
			"id": flag["id"],
			"position": [position.x - 1, position.y - 1],
			"owner": flag["owner"],
			"capture_progress": flag["capture_progress"],
		})
	var public_walls: Array = []
	for wall: Dictionary in player_view["walls"]:
		public_walls.append({"side": wall["side"], "status": wall["status"]})
	return {
		"schema_version": "player-view-ai-v1",
		"decision_id": "turn-%d-%s" % [player_view["action_index"], player_view["viewer_side"]],
		"viewer_side": player_view["viewer_side"],
		"turn_index": player_view["action_index"],
		"visible_pieces": visible_pieces,
		"public_flags": public_flags,
		"public_walls": public_walls,
		"legal_actions": actions,
		"public_events": _ai_public_events(player_view),
	}


static func export_ai_projection_from_view(player_view: Dictionary) -> Dictionary:
	var generated: Array = generate_action_intents(player_view)
	var intents: Array = []
	for preview: Dictionary in generated:
		if preview["classification"] == KNOWN_ILLEGAL:
			continue
		intents.append({
			"piece_id": preview["piece_id"],
			"action_type": preview["action_type"],
			"target_cell": preview["target_cell"].duplicate(),
			"skill_type": preview["skill_type"],
		})
	return export_ai_projection(player_view, intents)


static func canonical_surface(player_view: Dictionary, intents: Array) -> Dictionary:
	return {
		"projection_digest": Canonical.digest(player_view),
		"query_digest": Canonical.digest(list_action_intents(player_view, intents)),
		"ai_projection_digest": Canonical.digest(export_ai_projection(player_view, intents)),
	}


static func _visible_cell_set(full_state: Dictionary, viewer_side: String) -> Dictionary:
	var result: Dictionary = {}
	var first_y: int = 1 if viewer_side == MatchState.RED else 20
	var last_y: int = 5 if viewer_side == MatchState.RED else 24
	for y: int in range(first_y, last_y + 1):
		for x: int in range(1, MatchState.BOARD_WIDTH + 1):
			result[Canonical.cell_key(Vector2i(x, y))] = true
	for piece_value: Variant in full_state["pieces"].values():
		var piece: Dictionary = piece_value
		if piece["side"] != viewer_side or not piece["alive"] or piece["in_reserve"]:
			continue
		var center := Canonical.coordinate(piece["position"])
		for y: int in range(center.y - 1, center.y + 2):
			for x: int in range(center.x - 1, center.x + 2):
				var cell := Vector2i(x, y)
				if MatchState.is_inside_board(cell):
					result[Canonical.cell_key(cell)] = true
	var rook_paths: Dictionary = full_state.get("vision_sources", {}).get(viewer_side, {}).get("rook_paths", {})
	for path_value: Variant in rook_paths.values():
		for cell_value: Variant in path_value:
			var cell := Canonical.coordinate(cell_value)
			if MatchState.is_inside_board(cell):
				result[Canonical.cell_key(cell)] = true
	return result


static func _public_piece(piece: Dictionary, owned: bool) -> Dictionary:
	var tags: Array = ["owned"] if owned else ["visible"]
	if owned and piece["hidden"]:
		tags.append("hidden")
	if piece["in_reserve"]:
		tags.append("reserve")
	var public_piece: Dictionary = {
		"id": piece["id"],
		"side": piece["side"],
		"piece_type": piece["piece_type"],
		"position": piece["position"].duplicate(),
		"alive": piece["alive"],
		"in_reserve": piece["in_reserve"],
		"status_tags": tags,
	}
	if owned:
		public_piece["bombard_ammo"] = int(piece["bombard_ammo"])
	return public_piece


static func _find_piece(player_view: Dictionary, piece_id: String) -> Dictionary:
	for piece: Dictionary in player_view["pieces"]:
		if piece["id"] == piece_id:
			return piece
	return {}


static func _visible_piece_at(player_view: Dictionary, cell: Vector2i) -> Dictionary:
	for piece: Dictionary in player_view["pieces"]:
		if Canonical.coordinate(piece["position"]) == cell:
			return piece
	return {}


static func _action_id(piece_id: String, action_type: String, target: Vector2i, skill_type: String) -> String:
	return "%s:%s:%d,%d:%s" % [action_type, piece_id, target.x, target.y, skill_type]


static func _coordinate_set(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for value_to_convert: Variant in cells:
		result[Canonical.cell_key(Canonical.coordinate(value_to_convert))] = true
	return result


static func _coordinate_less(a: Array, b: Array) -> bool:
	return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0])


static func _flag_at(player_view: Dictionary, cell: Vector2i) -> Dictionary:
	for flag: Dictionary in player_view["flags"]:
		if Canonical.coordinate(flag["position"]) == cell:
			return flag
	return {}


static func _newly_revealed_cell_count(player_view: Dictionary, target: Vector2i) -> int:
	var visible_set: Dictionary = _coordinate_set(player_view["visible_cells"])
	var count: int = 0
	for y: int in range(target.y - 1, target.y + 2):
		for x: int in range(target.x - 1, target.x + 2):
			var cell := Vector2i(x, y)
			if MatchState.is_inside_board(cell) and not visible_set.has(Canonical.cell_key(cell)):
				count += 1
	return count


static func _ai_public_events(player_view: Dictionary) -> Array:
	var events: Array = []
	for event: Dictionary in player_view["player_events"]:
		var position: Array = event.get("position", [])
		if position.size() != 2:
			continue
		var cell := Canonical.coordinate(position)
		events.append({
			"id": str(event.get("id", "")),
			"event_type": str(event.get("event_type", "")),
			"actor_side": str(event.get("actor_side", "")),
			"position": [cell.x - 1, cell.y - 1],
		})
	return events


static func _preview_move(player_view: Dictionary, piece: Dictionary, target: Vector2i) -> String:
	var origin := Canonical.coordinate(piece["position"])
	if target == origin or _public_wall_blocks(player_view, piece["side"], origin, target):
		return KNOWN_ILLEGAL
	var target_piece: Dictionary = _visible_piece_at(player_view, target)
	if not target_piece.is_empty() and target_piece["side"] == piece["side"]:
		return KNOWN_ILLEGAL
	var visible_set: Dictionary = _coordinate_set(player_view["visible_cells"])
	var piece_type: String = str(piece["piece_type"])
	match piece_type:
		"rook":
			return _preview_rook(player_view, piece, origin, target, visible_set)
		"horse":
			return _preview_horse(player_view, piece, origin, target, visible_set)
		"elephant":
			return _preview_elephant(player_view, piece, origin, target, visible_set)
		"advisor":
			var advisor_delta := target - origin
			return KNOWN_LEGAL if absi(advisor_delta.x) == 1 and absi(advisor_delta.y) == 1 \
				and _inside_palace(target, piece["side"]) else KNOWN_ILLEGAL
		"general":
			var general_delta := target - origin
			return KNOWN_LEGAL if absi(general_delta.x) + absi(general_delta.y) == 1 \
				and _inside_palace(target, piece["side"]) else KNOWN_ILLEGAL
		"pawn":
			return _preview_pawn(player_view, piece, origin, target, visible_set)
		"cannon":
			return _preview_cannon(player_view, piece, origin, target, visible_set)
	return KNOWN_ILLEGAL


static func _preview_rook(
	player_view: Dictionary,
	piece: Dictionary,
	origin: Vector2i,
	target: Vector2i,
	visible_set: Dictionary
) -> String:
	var path: Array = MoveRules.movement_path(origin, target)
	if path.is_empty():
		return KNOWN_ILLEGAL
	var special: bool = _public_special_eligible(player_view, piece["side"], origin, path)
	var tentative: bool = false
	for index: int in path.size():
		var cell: Vector2i = path[index]
		var occupant: Dictionary = _visible_piece_at(player_view, cell)
		if not occupant.is_empty():
			if occupant["side"] == piece["side"] or (not special and index < path.size() - 1):
				return KNOWN_ILLEGAL
		elif not special and index < path.size() - 1 \
		and (not visible_set.has(Canonical.cell_key(cell)) or _hidden_uncertain(player_view, cell)):
			tentative = true
	return TENTATIVE if tentative else KNOWN_LEGAL


static func _preview_horse(
	player_view: Dictionary,
	piece: Dictionary,
	origin: Vector2i,
	target: Vector2i,
	visible_set: Dictionary
) -> String:
	var delta := target - origin
	if not ((absi(delta.x) == 2 and absi(delta.y) == 1) or (absi(delta.x) == 1 and absi(delta.y) == 2)):
		return KNOWN_ILLEGAL
	var leg := origin + (Vector2i(signi(delta.x), 0) if absi(delta.x) == 2 else Vector2i(0, signi(delta.y)))
	if _public_special_eligible(player_view, piece["side"], origin, [leg, target]):
		return KNOWN_LEGAL
	if not _visible_piece_at(player_view, leg).is_empty():
		return KNOWN_ILLEGAL
	if not visible_set.has(Canonical.cell_key(leg)) or _hidden_uncertain(player_view, leg):
		return TENTATIVE
	return KNOWN_LEGAL


static func _preview_elephant(
	player_view: Dictionary,
	piece: Dictionary,
	origin: Vector2i,
	target: Vector2i,
	visible_set: Dictionary
) -> String:
	var delta := target - origin
	if absi(delta.x) != 2 or absi(delta.y) != 2:
		return KNOWN_ILLEGAL
	var eye := origin + Vector2i(signi(delta.x), signi(delta.y))
	if _public_special_eligible(player_view, piece["side"], origin, [eye, target]):
		return KNOWN_LEGAL
	if not _visible_piece_at(player_view, eye).is_empty():
		return KNOWN_ILLEGAL
	if not visible_set.has(Canonical.cell_key(eye)) or _hidden_uncertain(player_view, eye):
		return TENTATIVE
	return KNOWN_LEGAL


static func _preview_pawn(
	player_view: Dictionary,
	piece: Dictionary,
	origin: Vector2i,
	target: Vector2i,
	visible_set: Dictionary
) -> String:
	var path: Array = MoveRules.movement_path(origin, target)
	if not path.is_empty() and path.size() <= 5 \
	and _public_special_eligible(player_view, piece["side"], origin, path):
		for cell: Vector2i in path:
			var occupant: Dictionary = _visible_piece_at(player_view, cell)
			if not occupant.is_empty() and (occupant["side"] == piece["side"] or cell == target):
				return KNOWN_ILLEGAL
		return KNOWN_LEGAL if visible_set.has(Canonical.cell_key(target)) \
			and not _hidden_uncertain(player_view, target) else TENTATIVE
	var delta := target - origin
	var forward: int = 1 if piece["side"] == MatchState.RED else -1
	if not ((delta.y == forward and delta.x == 0) or (delta.y == 0 and absi(delta.x) == 1)):
		return KNOWN_ILLEGAL
	return KNOWN_LEGAL


static func _preview_cannon(
	player_view: Dictionary,
	piece: Dictionary,
	origin: Vector2i,
	target: Vector2i,
	visible_set: Dictionary
) -> String:
	var path: Array = MoveRules.movement_path(origin, target)
	if path.is_empty():
		return KNOWN_ILLEGAL
	var visible_screens: int = 0
	var has_fog: bool = false
	for index: int in path.size() - 1:
		var cell: Vector2i = path[index]
		if not _visible_piece_at(player_view, cell).is_empty():
			visible_screens += 1
		elif not visible_set.has(Canonical.cell_key(cell)) or _hidden_uncertain(player_view, cell):
			has_fog = true
	var target_piece: Dictionary = _visible_piece_at(player_view, target)
	if not target_piece.is_empty():
		if target_piece["side"] == piece["side"] or visible_screens > 1:
			return KNOWN_ILLEGAL
		if has_fog:
			return TENTATIVE
		return KNOWN_LEGAL if visible_screens == 1 else KNOWN_ILLEGAL
	if visible_screens > 0:
		return KNOWN_ILLEGAL
	if has_fog or not visible_set.has(Canonical.cell_key(target)) or _hidden_uncertain(player_view, target):
		return TENTATIVE
	return KNOWN_LEGAL


static func _public_special_eligible(
	player_view: Dictionary,
	side: String,
	origin: Vector2i,
	path: Array
) -> bool:
	var enemy_side: String = MatchState.opponent(side)
	var enemy_wall: Dictionary = {}
	for wall: Dictionary in player_view["walls"]:
		if wall["side"] == enemy_side:
			enemy_wall = wall
			break
	if enemy_wall.get("status", "") != "INTACT" or origin.y < 6 or origin.y > 19:
		return false
	for cell: Vector2i in path:
		if cell.y < 6 or cell.y > 19:
			return false
	return true


static func _public_wall_blocks(
	player_view: Dictionary,
	side: String,
	origin: Vector2i,
	target: Vector2i
) -> bool:
	var enemy_side: String = MatchState.opponent(side)
	for wall: Dictionary in player_view["walls"]:
		if wall["side"] != enemy_side or wall["status"] != "INTACT":
			continue
		if enemy_side == MatchState.RED:
			return origin.y >= 6 and target.y <= 5
		return origin.y <= 19 and target.y >= 20
	return false


static func _public_bombard_available(player_view: Dictionary, piece: Dictionary, target: Vector2i) -> bool:
	if piece["piece_type"] != "cannon" or int(piece["bombard_ammo"]) <= 0 \
	or not MatchState.is_in_base(Canonical.coordinate(piece["position"]), piece["side"]):
		return false
	if target.x < 2 or target.x > 8 or target.y < 7 or target.y > 18:
		return false
	var enemy_side: String = MatchState.opponent(piece["side"])
	for wall: Dictionary in player_view["walls"]:
		if wall["side"] == enemy_side:
			return wall["status"] == "INTACT"
	return false


static func _inside_palace(cell: Vector2i, side: String) -> bool:
	if cell.x < 4 or cell.x > 6:
		return false
	return cell.y >= 1 and cell.y <= 3 if side == MatchState.RED else cell.y >= 22 and cell.y <= 24


static func _geometry_intents_for_piece(piece: Dictionary) -> Array:
	var origin := Canonical.coordinate(piece["position"])
	var targets: Array[Vector2i] = []
	match str(piece["piece_type"]):
		"rook", "cannon":
			for x: int in range(1, MatchState.BOARD_WIDTH + 1):
				if x != origin.x:
					targets.append(Vector2i(x, origin.y))
			for y: int in range(1, MatchState.BOARD_HEIGHT + 1):
				if y != origin.y:
					targets.append(Vector2i(origin.x, y))
		"horse":
			for delta: Vector2i in [Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1), Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)]:
				targets.append(origin + delta)
		"elephant":
			for delta: Vector2i in [Vector2i(2, 2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(-2, -2)]:
				targets.append(origin + delta)
		"advisor":
			for delta: Vector2i in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				targets.append(origin + delta)
		"general":
			for delta: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				targets.append(origin + delta)
		"pawn":
			for distance: int in range(1, 6):
				for direction: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					targets.append(origin + direction * distance)
	var intents: Array = []
	for target: Vector2i in targets:
		if MatchState.is_inside_board(target):
			intents.append({
				"piece_id": piece["id"],
				"action_type": "move",
				"target_cell": [target.x, target.y],
				"skill_type": "",
			})
	return intents


static func _enemy_piece_revealed(full_state: Dictionary, piece: Dictionary, viewer_side: String) -> bool:
	if not piece["hidden"]:
		return true
	if piece["piece_type"] != "horse":
		return false
	if piece.get("revealed_to", []).has(viewer_side):
		return true
	return _in_elephant_reveal_zone(full_state, Canonical.coordinate(piece["position"]), viewer_side)


static func _in_elephant_reveal_zone(full_state: Dictionary, position: Vector2i, viewer_side: String) -> bool:
	var position_key: String = Canonical.cell_key(position)
	var zones: Dictionary = full_state.get("vision_sources", {}).get(viewer_side, {}).get("elephant_reveal_zones", {})
	for cells_value: Variant in zones.values():
		for cell_value: Variant in cells_value:
			if Canonical.cell_key(Canonical.coordinate(cell_value)) == position_key:
				return true
	return false


static func _hidden_detection_cells(full_state: Dictionary, viewer_side: String) -> Array:
	var cell_set: Dictionary = {}
	var zones: Dictionary = full_state.get("vision_sources", {}).get(viewer_side, {}).get("elephant_reveal_zones", {})
	for cells_value: Variant in zones.values():
		for cell_value: Variant in cells_value:
			var cell := Canonical.coordinate(cell_value)
			if MatchState.is_inside_board(cell):
				cell_set[Canonical.cell_key(cell)] = [cell.x, cell.y]
	var result: Array = cell_set.values()
	result.sort_custom(_coordinate_less)
	return result


static func _hidden_uncertain(player_view: Dictionary, cell: Vector2i) -> bool:
	if _coordinate_set(player_view.get("hidden_detection_cells", [])).has(Canonical.cell_key(cell)):
		return false
	var viewer_side: String = str(player_view["viewer_side"])
	if MatchState.is_in_base(cell, viewer_side):
		for wall: Dictionary in player_view["walls"]:
			if wall["side"] == viewer_side and wall["status"] == "INTACT":
				return false
	return true


static func _public_walls(full_state: Dictionary) -> Array:
	var result: Array = []
	for side: String in [MatchState.RED, MatchState.BLACK]:
		result.append({
			"side": side,
			"status": str(full_state["walls"][side]["status"]),
		})
	return result


static func _public_flags(
	full_state: Dictionary,
	viewer_side: String,
	visible_piece_ids: Dictionary
) -> Array:
	var result: Array = []
	for flag: Dictionary in full_state["flags"]:
		var occupier_id: String = str(flag["occupier_piece_id"])
		var public_occupier_id: String = ""
		if not occupier_id.is_empty() and full_state["pieces"].has(occupier_id):
			var occupier: Dictionary = full_state["pieces"][occupier_id]
			if occupier["side"] == viewer_side or visible_piece_ids.has(occupier_id):
				public_occupier_id = occupier_id
		result.append({
			"id": str(flag["id"]),
			"position": flag["position"].duplicate(),
			"owner": str(flag["owner"]),
			"occupier_piece_id": public_occupier_id,
			"capturing_side": str(flag["capturing_side"]),
			"capture_progress": int(flag["capture_progress"]),
			"contested": bool(flag["contested"]),
		})
	return result
