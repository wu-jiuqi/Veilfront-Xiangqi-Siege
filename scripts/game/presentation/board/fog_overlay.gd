extends Control

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

var _side: String = "red"
var _cell_size := Vector2(128.0, 128.0)
var _visible_cells: Dictionary = {}
var _detection_cells: Dictionary = {}


func render(
	visible_cells: Array,
	hidden_detection_cells: Array,
	side: String,
	cell_size: Vector2
) -> void:
	_side = side
	_cell_size = cell_size
	_visible_cells = _coordinate_set(visible_cells)
	_detection_cells = _coordinate_set(hidden_detection_cells)
	custom_minimum_size = Vector2(9.0 * _cell_size.x, 24.0 * _cell_size.y)
	size = custom_minimum_size
	queue_redraw()


func is_cell_fogged(cell: Vector2i) -> bool:
	return not _visible_cells.has(_cell_key(cell))


func _draw() -> void:
	for authority_y: int in range(1, 25):
		for authority_x: int in range(1, 10):
			var cell := Vector2i(authority_x, authority_y)
			var key: String = _cell_key(cell)
			if _visible_cells.has(key):
				continue
			var display_cell: Vector2i = Mapper.authority_to_display(cell, _side)
			var rect := Rect2(Vector2(display_cell) * _cell_size, _cell_size)
			var fog_color := Color(0.01, 0.015, 0.025, 0.56) \
				if _detection_cells.has(key) else Color(0.005, 0.008, 0.015, 0.76)
			draw_rect(rect, fog_color)


func _coordinate_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in values:
		var cell: Vector2i = Mapper.coordinate_from_variant(value)
		if Mapper.is_authority_cell_valid(cell):
			result[_cell_key(cell)] = true
	return result


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
