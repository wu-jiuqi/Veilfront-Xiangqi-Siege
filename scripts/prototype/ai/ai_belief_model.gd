extends RefCounted

const HOME_TYPES: Array[String] = [
	"rook", "horse", "elephant", "advisor", "general",
	"advisor", "elephant", "horse", "rook",
]


static func build_samples(
	player_data: Dictionary,
	memory: RefCounted,
	public_rules: RefCounted,
	ai_seed: int,
	sample_count: int
) -> Array:
	var samples: Array = []
	var effective_count: int = maxi(1, sample_count)
	for sample_index: int in effective_count:
		samples.append(_build_sample(
			player_data, memory, public_rules, ai_seed, sample_index, sample_count > 0
		))
	return samples


static func _build_sample(
	player_data: Dictionary,
	memory: RefCounted,
	public_rules: RefCounted,
	ai_seed: int,
	sample_index: int,
	include_hypotheses: bool
) -> Array:
	var pieces: Array = player_data.get("visible_pieces", []).duplicate(true)
	if not include_hypotheses:
		return pieces
	var viewer_side: String = str(player_data.get("viewer_side", ""))
	var enemy_side: String = _opponent(viewer_side)
	var visible_ids: Dictionary = {}
	var occupied: Dictionary = {}
	for piece: Dictionary in pieces:
		visible_ids[str(piece.get("id", ""))] = true
		occupied[_cell_key(_coordinate(piece.get("position", [0, 0])))] = true
	var visible_cells: Dictionary = {}
	for cell_value: Variant in player_data.get("visible_cells", []):
		visible_cells[_cell_key(_coordinate(cell_value))] = true
	var captured_ids: Dictionary = {}
	for piece_id: String in memory.known_captured_enemy_ids():
		captured_ids[piece_id] = true
	var observations: Dictionary = memory.enemy_piece_observations()
	var rng := RandomNumberGenerator.new()
	rng.seed = ai_seed + (sample_index + 1) * 104729
	for roster_piece: Dictionary in _initial_army(
		enemy_side, public_rules.board_width(), public_rules.board_height()
	):
		var piece_id: String = str(roster_piece.id)
		if visible_ids.has(piece_id) or captured_ids.has(piece_id):
			continue
		var observation: Dictionary = observations.get(piece_id, {})
		var anchor: Vector2i = _coordinate(
			observation.get("position", roster_piece.position)
		)
		var last_turn: int = int(observation.get("turn_index", 0))
		var elapsed: int = maxi(0, int(player_data.get("turn_index", 0)) - last_turn)
		var candidates: Array[Vector2i] = _candidate_cells(
			anchor,
			str(roster_piece.piece_type),
			elapsed,
			public_rules.board_width(),
			public_rules.board_height(),
			visible_cells,
			occupied
		)
		if candidates.is_empty():
			continue
		var chosen: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		occupied[_cell_key(chosen)] = true
		pieces.append({
			"id": piece_id,
			"side": enemy_side,
			"piece_type": str(roster_piece.piece_type),
			"position": [chosen.x, chosen.y],
			"status_tags": ["belief"],
		})
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	return pieces


static func _candidate_cells(
	anchor: Vector2i,
	piece_type: String,
	elapsed: int,
	board_width: int,
	board_height: int,
	visible_cells: Dictionary,
	occupied: Dictionary
) -> Array[Vector2i]:
	var radius: int = clampi(1 + elapsed / 2, 1, 6)
	if piece_type in ["general", "advisor", "elephant"]:
		radius = mini(radius, 3)
	var candidates: Array[Vector2i] = []
	for y: int in range(maxi(0, anchor.y - radius), mini(board_height - 1, anchor.y + radius) + 1):
		for x: int in range(maxi(0, anchor.x - radius), mini(board_width - 1, anchor.x + radius) + 1):
			var cell := Vector2i(x, y)
			if visible_cells.has(_cell_key(cell)) or occupied.has(_cell_key(cell)):
				continue
			if _plausible_for_piece(piece_type, anchor, cell, radius):
				candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return candidates


static func _plausible_for_piece(
	piece_type: String,
	anchor: Vector2i,
	cell: Vector2i,
	radius: int
) -> bool:
	var delta := cell - anchor
	match piece_type:
		"rook", "cannon":
			return delta.x == 0 or delta.y == 0
		"horse":
			return absi(delta.x) + absi(delta.y) <= radius + 2
		"elephant":
			return (cell.x - anchor.x) % 2 == 0 and (cell.y - anchor.y) % 2 == 0
		"advisor":
			return absi(delta.x) == absi(delta.y) or delta == Vector2i.ZERO
		"general", "pawn":
			return absi(delta.x) + absi(delta.y) <= radius
	return true


static func _initial_army(side: String, board_width: int, board_height: int) -> Array:
	var result: Array = []
	var home_y: int = 0 if side == "red" else board_height - 1
	var cannon_y: int = 2 if side == "red" else board_height - 3
	var pawn_y: int = 3 if side == "red" else board_height - 4
	var type_counts: Dictionary = {}
	for x: int in mini(board_width, HOME_TYPES.size()):
		var piece_type: String = HOME_TYPES[x]
		type_counts[piece_type] = int(type_counts.get(piece_type, 0)) + 1
		result.append(_roster_piece(side, piece_type, int(type_counts[piece_type]), Vector2i(x, home_y)))
	for cannon_x: int in [1, 7]:
		if cannon_x >= board_width:
			continue
		type_counts["cannon"] = int(type_counts.get("cannon", 0)) + 1
		result.append(_roster_piece(side, "cannon", int(type_counts.cannon), Vector2i(cannon_x, cannon_y)))
	for pawn_x: int in [0, 2, 4, 6, 8]:
		if pawn_x >= board_width:
			continue
		type_counts["pawn"] = int(type_counts.get("pawn", 0)) + 1
		result.append(_roster_piece(side, "pawn", int(type_counts.pawn), Vector2i(pawn_x, pawn_y)))
	return result


static func _roster_piece(side: String, piece_type: String, index: int, position: Vector2i) -> Dictionary:
	return {
		"id": "%s-%s-%d" % [side, piece_type, index],
		"side": side,
		"piece_type": piece_type,
		"position": [position.x, position.y],
		"status_tags": ["belief"],
	}


static func _coordinate(value: Variant) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))


static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func _opponent(side: String) -> String:
	return "black" if side == "red" else "red"
