extends RefCounted

const Canonical = preload("res://scripts/game/domain/canonical.gd")
const MatchState = preload("res://scripts/game/domain/match_state.gd")


static func context(state: Dictionary, side: String) -> Dictionary:
	var visible_cell_set: Dictionary = visible_cell_set(state, side)
	var visible_cells: Array = []
	for key: String in visible_cell_set.keys():
		var parts: PackedStringArray = key.split(",")
		visible_cells.append([int(parts[0]), int(parts[1])])
	visible_cells.sort_custom(_coordinate_less)
	var visible_piece_ids: Array = []
	for piece_value: Variant in state["pieces"].values():
		var piece: Dictionary = piece_value
		if piece["side"] == side:
			visible_piece_ids.append(piece["id"])
			continue
		if not piece["alive"] or piece["in_reserve"]:
			continue
		var position: Vector2i = Canonical.coordinate(piece["position"])
		var normally_visible: bool = visible_cell_set.has(Canonical.cell_key(position))
		var elephant_revealed: bool = piece["hidden"] \
			and in_elephant_reveal_zone(state, position, side)
		if (normally_visible and enemy_piece_revealed(state, piece, side)) or elephant_revealed:
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


static func is_cell_visible(state: Dictionary, side: String, cell: Vector2i) -> bool:
	return visible_cell_set(state, side).has(Canonical.cell_key(cell))


static func visible_cell_set(state: Dictionary, side: String) -> Dictionary:
	var result: Dictionary = {}
	for cell_value: Variant in state.get("tutorial_visible_cells", {}).get(side, []):
		var tutorial_cell: Vector2i = Canonical.coordinate(cell_value)
		if MatchState.is_inside_board(tutorial_cell):
			result[Canonical.cell_key(tutorial_cell)] = true
	var first_y: int = 1 if side == MatchState.RED else 22
	var last_y: int = 3 if side == MatchState.RED else 24
	for y: int in range(first_y, last_y + 1):
		for x: int in range(1, MatchState.BOARD_WIDTH + 1):
			result[Canonical.cell_key(Vector2i(x, y))] = true
	var enemy_side: String = MatchState.opponent(side)
	if str(state["walls"][enemy_side]["status"]) != "INTACT":
		for y: int in range(1, MatchState.BOARD_HEIGHT + 1):
			for x: int in range(1, MatchState.BOARD_WIDTH + 1):
				var breached_region_cell: Vector2i = Vector2i(x, y)
				if MatchState.is_in_buffer_or_base(breached_region_cell, enemy_side):
					result[Canonical.cell_key(breached_region_cell)] = true
	for piece_value: Variant in state["pieces"].values():
		var piece: Dictionary = piece_value
		if piece["side"] != side or not piece["alive"] or piece["in_reserve"]:
			continue
		var center: Vector2i = Canonical.coordinate(piece["position"])
		for y: int in range(center.y - 1, center.y + 2):
			for x: int in range(center.x - 1, center.x + 2):
				var cell: Vector2i = Vector2i(x, y)
				if MatchState.is_inside_board(cell):
					result[Canonical.cell_key(cell)] = true
	var rook_paths: Dictionary = state.get("vision_sources", {}).get(side, {}).get(
		"rook_paths", {}
	)
	for path_value: Variant in rook_paths.values():
		for cell_value: Variant in path_value:
			var cell: Vector2i = Canonical.coordinate(cell_value)
			if MatchState.is_inside_board(cell):
				result[Canonical.cell_key(cell)] = true
	var elephant_zones: Dictionary = state.get("vision_sources", {}).get(side, {}).get(
		"elephant_reveal_zones", {}
	)
	for zone_value: Variant in elephant_zones.values():
		for cell_value: Variant in zone_value:
			var cell: Vector2i = Canonical.coordinate(cell_value)
			if MatchState.is_inside_board(cell):
				result[Canonical.cell_key(cell)] = true
	return result


static func enemy_piece_revealed(state: Dictionary, piece: Dictionary, side: String) -> bool:
	if not piece["hidden"]:
		return true
	if piece["piece_type"] != "horse":
		return false
	if piece.get("revealed_to", []).has(side):
		return true
	return in_elephant_reveal_zone(state, Canonical.coordinate(piece["position"]), side)


static func in_elephant_reveal_zone(
	state: Dictionary,
	position: Vector2i,
	side: String
) -> bool:
	var position_key: String = Canonical.cell_key(position)
	var zones: Dictionary = state.get("vision_sources", {}).get(side, {}).get(
		"elephant_reveal_zones", {}
	)
	for cells_value: Variant in zones.values():
		for cell_value: Variant in cells_value:
			if Canonical.cell_key(Canonical.coordinate(cell_value)) == position_key:
				return true
	return false


static func hidden_detection_cells(state: Dictionary, side: String) -> Array:
	var cell_set: Dictionary = {}
	var zones: Dictionary = state.get("vision_sources", {}).get(side, {}).get(
		"elephant_reveal_zones", {}
	)
	for cells_value: Variant in zones.values():
		for cell_value: Variant in cells_value:
			var cell: Vector2i = Canonical.coordinate(cell_value)
			if MatchState.is_inside_board(cell):
				cell_set[Canonical.cell_key(cell)] = [cell.x, cell.y]
	var result: Array = cell_set.values()
	result.sort_custom(_coordinate_less)
	return result


static func _coordinate_less(a: Array, b: Array) -> bool:
	return int(a[1]) < int(b[1]) or (int(a[1]) == int(b[1]) and int(a[0]) < int(b[0]))
