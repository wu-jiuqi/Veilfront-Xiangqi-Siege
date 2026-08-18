class_name BoardCoordinateMapper
extends RefCounted

const BOARD_WIDTH: int = 9
const BOARD_HEIGHT: int = 24


static func authority_to_display(cell: Vector2i, side: String) -> Vector2i:
	if side == "black":
		return Vector2i(BOARD_WIDTH - cell.x, cell.y - 1)
	return Vector2i(cell.x - 1, BOARD_HEIGHT - cell.y)


static func display_to_authority(cell: Vector2i, side: String) -> Vector2i:
	if side == "black":
		return Vector2i(BOARD_WIDTH - cell.x, cell.y + 1)
	return Vector2i(cell.x + 1, BOARD_HEIGHT - cell.y)


static func authority_to_world(cell: Vector2i, side: String, cell_size: Vector2) -> Vector2:
	var display_cell: Vector2i = authority_to_display(cell, side)
	return Vector2(
		(float(display_cell.x) + 0.5) * cell_size.x,
		(float(display_cell.y) + 0.5) * cell_size.y
	)


static func world_to_authority(world_position: Vector2, side: String, cell_size: Vector2) -> Vector2i:
	if cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return Vector2i.ZERO
	var display_cell := Vector2i(
		floori(world_position.x / cell_size.x),
		floori(world_position.y / cell_size.y)
	)
	if display_cell.x < 0 or display_cell.x >= BOARD_WIDTH \
	or display_cell.y < 0 or display_cell.y >= BOARD_HEIGHT:
		return Vector2i.ZERO
	return display_to_authority(display_cell, side)


static func is_authority_cell_valid(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= BOARD_WIDTH and cell.y >= 1 and cell.y <= BOARD_HEIGHT


static func coordinate_from_variant(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
