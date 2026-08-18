extends RefCounted

const Canonical = preload("res://scripts/game/domain/canonical.gd")
const MatchState = preload("res://scripts/game/domain/match_state.gd")
const MoveRules = preload("res://scripts/game/domain/move_rules.gd")

const KNOWN_LEGAL: String = "KNOWN_LEGAL"
const TENTATIVE: String = "TENTATIVE"
const KNOWN_ILLEGAL: String = "KNOWN_ILLEGAL"

static func list_action_intents(player_view: Dictionary, intents: Array) -> Array:
	var previews: Array = []
	for intent_value: Variant in intents:
		previews.append(preview_intent(player_view, intent_value))
	previews.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["preview_id"] < b["preview_id"]
	)
	return previews


static func generate_action_intents(player_view: Dictionary) -> Array:
	var intents: Array = []
	for piece: Dictionary in player_view["pieces"]:
		if piece["side"] != player_view["viewer_side"] or not piece["alive"] \
		or piece["in_reserve"] or piece["position"].is_empty():
			continue
		for intent: Dictionary in _geometry_intents_for_piece(piece):
			if MatchState.is_inside_board(Canonical.coordinate(intent.get("target_cell", []))):
				intents.append(intent)
		if piece["piece_type"] == "cannon":
			for y: int in range(5, 21):
				for x: int in range(2, 9):
					intents.append({
						"piece_id": piece["id"],
						"action_type": "bombard",
						"target_cell": [x, y],
						"skill_type": "area_bombardment",
					})
		if piece["piece_type"] == "advisor" and _public_resurrection_available(player_view, piece):
			intents.append({
				"piece_id": piece["id"],
				"action_type": "resurrect",
				"target_cell": [],
				"skill_type": "advisor_resurrection",
			})
	intents.append({"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""})
	return list_action_intents(player_view, intents)


static func preview_intent(player_view: Dictionary, intent: Dictionary) -> Dictionary:
	var piece_id: String = str(intent.get("piece_id", ""))
	var action_type: String = str(intent.get("action_type", ""))
	var target := Canonical.coordinate(intent.get("target_cell", []))
	var public_target: Array = [] if action_type in ["pass", "skip", "timeout", "resurrect"] \
		else [target.x, target.y]
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
		elif action_type == "resurrect" and _public_resurrection_available(player_view, piece):
			classification = KNOWN_LEGAL
			public_code = ""
	return {
		"schema_version": "veilfront-action-preview-v1",
		"preview_id": _action_id(piece_id, action_type, target, skill_type),
		"piece_id": piece_id,
		"action_type": action_type,
		"target_cell": public_target,
		"skill_type": skill_type,
		"classification": classification,
		"confirmation_required": action_type in ["move", "bombard", "resurrect"],
		"public_cost": {},
		"message_key": "action.%s" % (public_code if not public_code.is_empty() else action_type),
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


static func _action_id(piece_id: String, action_type: String, target: Vector2i, skill_type: String) -> String:
	return "%s:%s:%d,%d:%s" % [action_type, piece_id, target.x, target.y, skill_type]


static func _coordinate_set(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for value_to_convert: Variant in cells:
		result[Canonical.cell_key(Canonical.coordinate(value_to_convert))] = true
	return result


static func _coordinate_less(a: Array, b: Array) -> bool:
	return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0])


static func _newly_revealed_cell_count(player_view: Dictionary, target: Vector2i) -> int:
	var visible_set: Dictionary = _coordinate_set(player_view["visible_cells"])
	var count: int = 0
	for y: int in range(target.y - 1, target.y + 2):
		for x: int in range(target.x - 1, target.x + 2):
			var cell := Vector2i(x, y)
			if MatchState.is_inside_board(cell) and not visible_set.has(Canonical.cell_key(cell)):
				count += 1
	return count



static func _preview_move(player_view: Dictionary, piece: Dictionary, target: Vector2i) -> String:
	var origin := Canonical.coordinate(piece["position"])
	if target == origin:
		return KNOWN_ILLEGAL
	var visible_set: Dictionary = _coordinate_set(player_view["visible_cells"])
	if _public_enemy_headquarters_staging_required(piece["side"], origin, target):
		return KNOWN_ILLEGAL
	if _public_wall_blocks(player_view, piece["side"], origin, target):
		var wall_path: Array = MoveRules.movement_path(origin, target)
		if piece["piece_type"] in ["rook", "pawn"] \
		and _path_has_hidden_elephant_field_uncertainty(player_view, wall_path, visible_set):
			# The public wall is intact, but an undisclosed enemy elephant field
			# may authoritatively stop this intent before it reaches the wall.
			return TENTATIVE
		return KNOWN_ILLEGAL
	var target_piece: Dictionary = _visible_piece_at(player_view, target)
	if not target_piece.is_empty() and target_piece["side"] == piece["side"]:
		return KNOWN_ILLEGAL
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


static func _path_has_hidden_elephant_field_uncertainty(
	player_view: Dictionary,
	path: Array,
	visible_set: Dictionary
) -> bool:
	for cell: Vector2i in path:
		if cell.y < 4 or cell.y > 21:
			continue
		if not visible_set.has(Canonical.cell_key(cell)) or _hidden_uncertain(player_view, cell):
			return true
	return false


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
		if cell.y >= 4 and cell.y <= 21 and not visible_set.has(Canonical.cell_key(cell)):
			# Hidden enemy elephant fields are host-authoritative. Crossing fog is
			# tentative without exposing whether a field actually exists.
			tentative = true
		var occupant: Dictionary = _visible_piece_at(player_view, cell)
		if not occupant.is_empty():
			if occupant["side"] == piece["side"]:
				return KNOWN_ILLEGAL
			if not special and index < path.size() - 1:
				# An undisclosed enemy elephant field can turn an otherwise blocked
				# route into a legal interception at or before this visible piece.
				# Preserve the already-established fog uncertainty instead of
				# rejecting an intent that the authoritative rules may consume.
				return TENTATIVE if tentative else KNOWN_ILLEGAL
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
	if path.size() >= 2 and path.size() <= 5 \
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
	if enemy_wall.get("status", "") != "INTACT" or origin.y < 4 or origin.y > 21:
		return false
	for cell: Vector2i in path:
		if cell.y < 4 or cell.y > 21:
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
			return origin.y >= 5 and target.y <= 4
		return origin.y <= 20 and target.y >= 21
	return false


static func _public_enemy_headquarters_staging_required(
	side: String,
	origin: Vector2i,
	target: Vector2i
) -> bool:
	var enemy_side: String = MatchState.opponent(side)
	if not MatchState.is_in_base(target, enemy_side):
		return false
	return not MatchState.is_in_buffer(origin, enemy_side) \
		and not MatchState.is_in_base(origin, enemy_side)


static func _public_bombard_available(player_view: Dictionary, piece: Dictionary, target: Vector2i) -> bool:
	if piece["piece_type"] != "cannon" or int(piece["bombard_ammo"]) <= 0 \
	or not MatchState.is_in_base(Canonical.coordinate(piece["position"]), piece["side"]):
		return false
	if target.x < 2 or target.x > 8 or target.y < 5 or target.y > 20:
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



static func _hidden_uncertain(player_view: Dictionary, cell: Vector2i) -> bool:
	if _coordinate_set(player_view.get("hidden_detection_cells", [])).has(Canonical.cell_key(cell)):
		return false
	var viewer_side: String = str(player_view["viewer_side"])
	if MatchState.is_in_base(cell, viewer_side):
		for wall: Dictionary in player_view["walls"]:
			if wall["side"] == viewer_side and wall["status"] == "INTACT":
				return false
	return true

static func _public_resurrection_available(player_view: Dictionary, advisor: Dictionary) -> bool:
	if advisor.get("piece_type", "") != "advisor" or not bool(advisor.get("alive", false)) \
	or bool(advisor.get("in_reserve", false)):
		return false
	var summary: Dictionary = _public_resurrection_summary(player_view)
	if int(summary["candidate_count"]) <= 0:
		return false
	if not _public_base_empty_cells(player_view).is_empty():
		return true
	return MatchState.is_in_base(Canonical.coordinate(advisor.get("position", [])), str(advisor["side"]))


static func _public_resurrection_summary(player_view: Dictionary) -> Dictionary:
	var count: int = 0
	var total_value: int = 0
	var values: Dictionary = {
		"rook": 90, "cannon": 50, "horse": 45, "elephant": 40, "pawn": 20,
	}
	for casualty: Dictionary in player_view.get("casualties", []):
		if casualty.get("side", "") != player_view.get("viewer_side", ""):
			continue
		var piece_type: String = str(casualty.get("piece_type", ""))
		# Dead advisors and generals are explicitly excluded from the random pool.
		if piece_type in ["advisor", "general"]:
			continue
		count += 1
		total_value += int(values.get(piece_type, 0))
	return {
		"candidate_count": count,
		"average_piece_value": roundi(float(total_value) / float(count)) if count > 0 else 0,
	}


static func _public_base_empty_cells(player_view: Dictionary) -> Array:
	var occupied: Dictionary = {}
	for piece: Dictionary in player_view.get("pieces", []):
		if not bool(piece.get("alive", false)) or bool(piece.get("in_reserve", false)):
			continue
		var cell := Canonical.coordinate(piece.get("position", []))
		if MatchState.is_inside_board(cell):
			occupied[Canonical.cell_key(cell)] = true
	var result: Array = []
	var side: String = str(player_view["viewer_side"])
	var first_y: int = 1 if side == MatchState.RED else 22
	var last_y: int = 3 if side == MatchState.RED else 24
	for y: int in range(first_y, last_y + 1):
		for x: int in range(1, MatchState.BOARD_WIDTH + 1):
			var cell := Vector2i(x, y)
			if not occupied.has(Canonical.cell_key(cell)):
				result.append([x, y])
	return result
