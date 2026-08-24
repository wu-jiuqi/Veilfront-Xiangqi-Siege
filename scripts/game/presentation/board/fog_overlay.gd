extends TextureRect

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

const BOARD_WIDTH: int = 9
const BOARD_HEIGHT: int = 24
const MASK_PIXELS_PER_CELL: int = 16
const CLEAR_RADIUS_CELLS: float = 0.5
const FOG_RADIUS_CELLS: float = 0.84

var _side: String = "red"
var _cell_size := Vector2(128.0, 128.0)
var _visible_cells: Dictionary = {}
var _detection_cells: Dictionary = {}
var _mask_texture: ImageTexture
var _mask_texture_borrowed: bool = false
var _mask_rebuild_count: int = 0
var _mask_cache_hit_count: int = 0
var _borrowed_mask_count: int = 0


func render(
	visible_cells: Array,
	hidden_detection_cells: Array,
	side: String,
	cell_size: Vector2,
	cached_texture: ImageTexture = null
) -> void:
	var next_side := side if side in ["red", "black"] else "red"
	var next_visible_cells := _coordinate_set(visible_cells)
	var next_detection_cells := _coordinate_set(hidden_detection_cells)
	var mask_changed: bool = _mask_texture == null \
		or next_side != _side \
		or not _sets_equal(next_visible_cells, _visible_cells) \
		or not _sets_equal(next_detection_cells, _detection_cells)
	_side = next_side
	_cell_size = cell_size
	_visible_cells = next_visible_cells
	_detection_cells = next_detection_cells
	custom_minimum_size = Vector2(
		float(BOARD_WIDTH) * _cell_size.x,
		float(BOARD_HEIGHT) * _cell_size.y
	)
	size = custom_minimum_size
	if not mask_changed:
		_mask_cache_hit_count += 1
		return
	if cached_texture != null:
		_mask_texture = cached_texture
		_mask_texture_borrowed = true
		texture = _mask_texture
		_borrowed_mask_count += 1
		return
	_rebuild_mask()


func is_cell_fogged(cell: Vector2i) -> bool:
	return not _visible_cells.has(_cell_index(cell))


func get_visual_snapshot() -> Dictionary:
	return {
		"board_cell_count": BOARD_WIDTH * BOARD_HEIGHT,
		"visible_cell_count": _visible_cells.size(),
		"fogged_cell_count": BOARD_WIDTH * BOARD_HEIGHT - _visible_cells.size(),
		"detection_cell_count": _detection_cells.size(),
		"display_side": _side,
		"boundary_style": "shader_warped_irregular",
		"mask_encoding": "visible_distance_field_with_detection_hint",
		"mask_size": Vector2i(
			BOARD_WIDTH * MASK_PIXELS_PER_CELL,
			BOARD_HEIGHT * MASK_PIXELS_PER_CELL
		),
		"uses_generated_mask": texture != null,
		"uses_player_view_only": true,
		"mask_rebuild_count": _mask_rebuild_count,
		"mask_cache_hit_count": _mask_cache_hit_count,
		"borrowed_mask_count": _borrowed_mask_count,
		"uses_borrowed_mask": _mask_texture_borrowed,
	}


func get_mask_texture() -> ImageTexture:
	return _mask_texture


func _rebuild_mask() -> void:
	var mask_size := Vector2i(
		BOARD_WIDTH * MASK_PIXELS_PER_CELL,
		BOARD_HEIGHT * MASK_PIXELS_PER_CELL
	)
	var image := Image.create(mask_size.x, mask_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.0, 0.0, 1.0))
	for authority_cell_value: Variant in _detection_cells.values():
		var authority_cell: Vector2i = authority_cell_value
		var display_cell: Vector2i = Mapper.authority_to_display(authority_cell, _side)
		image.fill_rect(
			Rect2i(display_cell * MASK_PIXELS_PER_CELL, Vector2i.ONE * MASK_PIXELS_PER_CELL),
			Color(1.0, 1.0, 0.0, 1.0)
		)
	for authority_cell_value: Variant in _visible_cells.values():
		var authority_cell: Vector2i = authority_cell_value
		_stamp_visible_cell(image, authority_cell, mask_size)
	if _mask_texture == null or _mask_texture_borrowed:
		_mask_texture = ImageTexture.create_from_image(image)
		texture = _mask_texture
	else:
		_mask_texture.update(image)
	_mask_texture_borrowed = false
	_mask_rebuild_count += 1


func _stamp_visible_cell(image: Image, authority_cell: Vector2i, mask_size: Vector2i) -> void:
	var display_cell: Vector2i = Mapper.authority_to_display(authority_cell, _side)
	var center_pixels := (Vector2(display_cell) + Vector2(0.5, 0.5)) \
		* float(MASK_PIXELS_PER_CELL)
	var radius_pixels := FOG_RADIUS_CELLS * float(MASK_PIXELS_PER_CELL)
	var min_x := maxi(0, floori(center_pixels.x - radius_pixels - 1.0))
	var max_x := mini(mask_size.x - 1, ceili(center_pixels.x + radius_pixels + 1.0))
	var min_y := maxi(0, floori(center_pixels.y - radius_pixels - 1.0))
	var max_y := mini(mask_size.y - 1, ceili(center_pixels.y + radius_pixels + 1.0))
	for pixel_y: int in range(min_y, max_y + 1):
		for pixel_x: int in range(min_x, max_x + 1):
			var distance_cells := Vector2(
				float(pixel_x) + 0.5,
				float(pixel_y) + 0.5
			).distance_to(center_pixels) / float(MASK_PIXELS_PER_CELL)
			if distance_cells > FOG_RADIUS_CELLS:
				continue
			var current := image.get_pixel(pixel_x, pixel_y)
			var fog_amount := _smooth_distance(distance_cells)
			if fog_amount < current.r:
				image.set_pixel(pixel_x, pixel_y, Color(fog_amount, current.g, 0.0, 1.0))


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
			result[_cell_index(cell)] = cell
	return result


func _sets_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: Variant in a:
		if not b.has(key):
			return false
	return true


func _cell_index(cell: Vector2i) -> int:
	return (cell.y - 1) * BOARD_WIDTH + cell.x - 1
