extends TextureRect

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

const BOARD_WIDTH: int = 9
const BOARD_HEIGHT: int = 24
const MASK_PIXELS_PER_CELL: int = 16
const CLEAR_RADIUS_CELLS: float = 0.5
const FOG_RADIUS_CELLS: float = 0.84

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
		"boundary_style": "shader_warped_irregular",
		"mask_encoding": "visible_distance_field",
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
	var visible_centers: Array[Vector2] = []
	for key_value: Variant in _visible_cells.keys():
		var authority_cell: Vector2i = _visible_cells[key_value]
		var display_cell: Vector2i = Mapper.authority_to_display(authority_cell, _side)
		visible_centers.append(Vector2(display_cell) + Vector2(0.5, 0.5))
	if visible_centers.is_empty():
		image.fill(Color.WHITE)
	else:
		for pixel_y: int in mask_size.y:
			for pixel_x: int in mask_size.x:
				var board_point := Vector2(
					(float(pixel_x) + 0.5) / float(MASK_PIXELS_PER_CELL),
					(float(pixel_y) + 0.5) / float(MASK_PIXELS_PER_CELL)
				)
				var nearest_distance: float = INF
				for center: Vector2 in visible_centers:
					nearest_distance = minf(nearest_distance, board_point.distance_to(center))
				var fog_amount := _smooth_distance(nearest_distance)
				image.set_pixel(
					pixel_x,
					pixel_y,
					Color(fog_amount, fog_amount, fog_amount, 1.0)
				)
	_mask_texture = ImageTexture.create_from_image(image)
	texture = _mask_texture


func _smooth_distance(distance_cells: float) -> float:
	var weight := clampf(
		(distance_cells - CLEAR_RADIUS_CELLS) \
		/ (FOG_RADIUS_CELLS - CLEAR_RADIUS_CELLS),
		0.0,
		1.0
	)
	return weight * weight * (3.0 - 2.0 * weight)


func _coordinate_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in values:
		var cell: Vector2i = Mapper.coordinate_from_variant(value)
		if Mapper.is_authority_cell_valid(cell):
			result[_cell_key(cell)] = cell
	return result


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
