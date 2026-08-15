extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")

const KNOWN_LEGAL: String = "KNOWN_LEGAL"
const TENTATIVE: String = "TENTATIVE"
const KNOWN_ILLEGAL: String = "KNOWN_ILLEGAL"


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
		if visible_cell_set.has(Canonical.cell_key(position)) and not piece["hidden"]:
			pieces.append(_public_piece(piece, false))
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])

	var visible_cells: Array = []
	for key: String in visible_cell_set.keys():
		var parts: PackedStringArray = key.split(",")
		visible_cells.append([int(parts[0]), int(parts[1])])
	visible_cells.sort_custom(_coordinate_less)

	return {
		"schema_version": "player-view-v1",
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
		"pieces": pieces,
		"flags": full_state["flags"].duplicate(true),
		"walls": [full_state["walls"][MatchState.RED].duplicate(true), full_state["walls"][MatchState.BLACK].duplicate(true)],
		"player_events": full_state["player_events"][viewer_side].duplicate(true),
		"contact_intel": full_state["contact_intel"][viewer_side].duplicate(true),
	}


static func list_action_intents(player_view: Dictionary, intents: Array) -> Array:
	var previews: Array = []
	for intent_value: Variant in intents:
		previews.append(preview_intent(player_view, intent_value))
	previews.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	return previews


static func preview_intent(player_view: Dictionary, intent: Dictionary) -> Dictionary:
	var piece_id: String = str(intent.get("piece_id", ""))
	var action_type: String = str(intent.get("action_type", ""))
	var target := Canonical.coordinate(intent.get("target_cell", []))
	var skill_type: String = str(intent.get("skill_type", ""))
	var piece: Dictionary = _find_piece(player_view, piece_id)
	var classification: String = KNOWN_ILLEGAL
	var public_code: String = "known_illegal"
	if not piece.is_empty() and piece["side"] == player_view["viewer_side"] \
	and action_type == "move" and MatchState.is_inside_board(target):
		var origin := Canonical.coordinate(piece["position"])
		var path: Array = _orthogonal_path(origin, target)
		if not path.is_empty():
			classification = KNOWN_LEGAL
			public_code = ""
			var visible_set: Dictionary = _coordinate_set(player_view["visible_cells"])
			for index: int in path.size():
				var cell: Vector2i = path[index]
				var visible_piece: Dictionary = _visible_piece_at(player_view, cell)
				var is_target: bool = index == path.size() - 1
				if not visible_piece.is_empty() and (not is_target or visible_piece["side"] == piece["side"]):
					classification = KNOWN_ILLEGAL
					public_code = "known_illegal"
					break
				if not visible_set.has(Canonical.cell_key(cell)):
					classification = TENTATIVE
					public_code = ""
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
		var piece: Dictionary = _find_piece(player_view, preview["piece_id"])
		var origin := Canonical.coordinate(piece["position"])
		var target := Canonical.coordinate(preview["target_cell"])
		var target_piece: Dictionary = _visible_piece_at(player_view, target)
		var visible_captures: Array = []
		if not target_piece.is_empty() and target_piece["side"] != piece["side"]:
			visible_captures.append({"piece_id": target_piece["id"], "piece_type": target_piece["piece_type"]})
		actions.append({
			"id": preview["id"],
			"kind": preview["action_type"],
			"actor_id": preview["piece_id"],
			"origin": [origin.x - 1, origin.y - 1],
			"target": [target.x - 1, target.y - 1],
			"visible_captures": visible_captures,
			"reveal_cell_count": _newly_revealed_cell_count(player_view, target),
			"occupies_flag": _flag_at(player_view, target) != {},
			"attacks_wall": false,
			"path_length": absi(target.x - origin.x) + absi(target.y - origin.y),
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
	return result


static func _public_piece(piece: Dictionary, owned: bool) -> Dictionary:
	var tags: Array = ["owned"] if owned else ["visible"]
	if owned and piece["hidden"]:
		tags.append("hidden")
	if piece["in_reserve"]:
		tags.append("reserve")
	return {
		"id": piece["id"],
		"side": piece["side"],
		"piece_type": piece["piece_type"],
		"position": piece["position"].duplicate(),
		"alive": piece["alive"],
		"in_reserve": piece["in_reserve"],
		"bombard_ammo": piece["bombard_ammo"],
		"status_tags": tags,
	}


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


static func _orthogonal_path(origin: Vector2i, target: Vector2i) -> Array:
	if origin == target or (origin.x != target.x and origin.y != target.y):
		return []
	var direction := Vector2i(signi(target.x - origin.x), signi(target.y - origin.y))
	var result: Array = []
	var cursor: Vector2i = origin + direction
	while cursor != target + direction:
		result.append(cursor)
		cursor += direction
	return result


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
