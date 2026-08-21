extends TextureRect

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

const BOARD_WIDTH: int = 9
const BOARD_HEIGHT: int = 24
const MASK_PIXELS_PER_CELL: int = 8

var _visible_cells: Dictionary = {}
var _side: String = "red"
var _cell_size := Vector2(128.0, 128.0)
var _mask_texture: ImageTexture


func render(visible_cells: Array, side: String, cell_size: Vector2) -> void:
	_side = side if side in ["red", "black"] else "red"
	_cell_size = cell_size
	_visible_cells = _coordinate_set(visible_cells)
	custom_minimum_size = Vector2(
		float(BOARD_WIDTH) * _cell_size.x,
		float(BOARD_HEIGHT) * _cell_size.y
	)
	size = custom_minimum_size
	_rebuild_mask()


func get_visual_snapshot() -> Dictionary:
	return {
		"board_cell_count": BOARD_WIDTH * BOARD_HEIGHT,
		"visible_cell_count": _visible_cells.size(),
		"fogged_cell_count": BOARD_WIDTH * BOARD_HEIGHT - _visible_cells.size(),
		"display_side": _side,
		"mask_size": Vector2i(
			BOARD_WIDTH * MASK_PIXELS_PER_CELL,
			BOARD_HEIGHT * MASK_PIXELS_PER_CELL
		),
		"uses_generated_mask": texture != null,
		"uses_player_view_only": true,
	}


func _rebuild_mask() -> void:
	var mask_size := Vector2i(
		BOARD_WIDTH * MASK_PIXELS_PER_CELL,
		BOARD_HEIGHT * MASK_PIXELS_PER_CELL
	)
	var image := Image.create(mask_size.x, mask_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for key_value: Variant in _visible_cells.keys():
		var authority_cell: Vector2i = _visible_cells[key_value]
		var display_cell: Vector2i = Mapper.authority_to_display(authority_cell, _side)
		image.fill_rect(
			Rect2i(
				display_cell * MASK_PIXELS_PER_CELL,
				Vector2i.ONE * MASK_PIXELS_PER_CELL
			),
			Color.BLACK
		)
	_mask_texture = ImageTexture.create_from_image(image)
	texture = _mask_texture


func _coordinate_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in values:
		var cell: Vector2i = Mapper.coordinate_from_variant(value)
		if Mapper.is_authority_cell_valid(cell):
			result[_cell_key(cell)] = cell
	return result


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
