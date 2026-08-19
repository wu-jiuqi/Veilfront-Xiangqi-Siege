extends Control

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

var _side: String = "red"
var _cell_size := Vector2(128.0, 128.0)
var _previews: Array = []
var _selected_cell := Vector2i.ZERO
var _tutorial_target := Vector2i.ZERO


func render_selection(
	selected_cell: Vector2i,
	action_previews: Array,
	side: String,
	cell_size: Vector2
) -> void:
	_side = side
	_cell_size = cell_size
	_selected_cell = selected_cell
	_previews = action_previews.duplicate(true)
	custom_minimum_size = Vector2(9.0 * _cell_size.x, 24.0 * _cell_size.y)
	size = custom_minimum_size
	queue_redraw()


func clear() -> void:
	_selected_cell = Vector2i.ZERO
	_previews.clear()
	queue_redraw()


func set_tutorial_target(cell: Vector2i) -> void:
	_tutorial_target = cell
	queue_redraw()


func get_preview_count() -> int:
	return _previews.size()


func _draw() -> void:
	if Mapper.is_authority_cell_valid(_tutorial_target):
		var target_center: Vector2 = Mapper.authority_to_world(_tutorial_target, _side, _cell_size)
		draw_circle(
			target_center,
			minf(_cell_size.x, _cell_size.y) * 0.12,
			Color(1.0, 0.78, 0.18, 0.28)
		)
		draw_arc(
			target_center,
			minf(_cell_size.x, _cell_size.y) * 0.22,
			0.0,
			TAU,
			32,
			Color(1.0, 0.82, 0.28, 0.95),
			5.0,
			true
		)
	if Mapper.is_authority_cell_valid(_selected_cell):
		var selected_center: Vector2 = Mapper.authority_to_world(_selected_cell, _side, _cell_size)
		draw_arc(
			selected_center,
			minf(_cell_size.x, _cell_size.y) * 0.34,
			0.0,
			TAU,
			40,
			Color(1.0, 0.88, 0.3, 0.95),
			9.0,
			true
		)
	for preview: Dictionary in _previews:
		var target: Vector2i = Mapper.coordinate_from_variant(preview.get("target_cell", []))
		if not Mapper.is_authority_cell_valid(target):
			continue
		var color: Color = _classification_color(str(preview.get("classification", "")))
		var center: Vector2 = Mapper.authority_to_world(target, _side, _cell_size)
		draw_circle(center, minf(_cell_size.x, _cell_size.y) * 0.12, color)
		draw_arc(center, minf(_cell_size.x, _cell_size.y) * 0.24, 0.0, TAU, 28, color, 5.0, true)


func _classification_color(classification: String) -> Color:
	match classification:
		"KNOWN_LEGAL":
			return Color(0.34, 1.0, 0.45, 0.92)
		"TENTATIVE":
			return Color(1.0, 0.72, 0.18, 0.92)
		_:
			return Color(0.94, 0.3, 0.28, 0.86)
