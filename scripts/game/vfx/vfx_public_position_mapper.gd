class_name VfxPublicPositionMapper
extends RefCounted

const BOARD_WIDTH: int = 9
const BOARD_HEIGHT: int = 24


static func is_public_cell(value: Variant) -> bool:
	return value is Array and value.size() == 2 \
		and value[0] is int and value[1] is int \
		and int(value[0]) >= 1 and int(value[0]) <= BOARD_WIDTH \
		and int(value[1]) >= 1 and int(value[1]) <= BOARD_HEIGHT


static func to_local(
	position_public: Array,
	display_side: String,
	cell_size: Vector2
) -> Vector2:
	if not is_public_cell(position_public) or display_side not in ["red", "black"]:
		return Vector2(INF, INF)
	var authority_cell := Vector2i(int(position_public[0]), int(position_public[1]))
	var display_cell := Vector2i.ZERO
	if display_side == "black":
		display_cell = Vector2i(BOARD_WIDTH - authority_cell.x, authority_cell.y - 1)
	else:
		display_cell = Vector2i(authority_cell.x - 1, BOARD_HEIGHT - authority_cell.y)
	return Vector2(
		(float(display_cell.x) + 0.5) * cell_size.x,
		(float(display_cell.y) + 0.5) * cell_size.y
	)


static func wall_anchor(side: String) -> Array:
	if side == "red":
		return [5, 4]
	if side == "black":
		return [5, 21]
	return []
