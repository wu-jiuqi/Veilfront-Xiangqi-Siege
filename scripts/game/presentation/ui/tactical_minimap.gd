class_name TacticalMinimap
extends Control

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")
const BOARD_SIZE := Vector2i(9, 24)

var _view: Dictionary = {}
var _display_side: String = "red"


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func render_player_view(view: Dictionary, display_side: String = "red") -> void:
	_view = view.duplicate(true)
	set_presentation_side(display_side)


func set_presentation_side(side: String) -> void:
	_display_side = side if side in ["red", "black"] else "red"
	queue_redraw()


func get_state_snapshot() -> Dictionary:
	var visible_count := 0
	for cell_value: Variant in _view.get("visible_cells", []):
		if Mapper.is_authority_cell_valid(Mapper.coordinate_from_variant(cell_value)):
			visible_count += 1
	var piece_count := 0
	for piece_value: Variant in _view.get("pieces", []):
		if piece_value is Dictionary and _piece_is_drawable(piece_value):
			piece_count += 1
	var flag_count := 0
	for flag_value: Variant in _view.get("flags", []):
		if flag_value is Dictionary and _flag_is_drawable(flag_value):
			flag_count += 1
	return {
		"display_side": _display_side,
		"visible_cell_count": visible_count,
		"piece_count": piece_count,
		"flag_count": flag_count,
		"uses_player_view_only": true,
	}


func _draw() -> void:
	var board_rect := _board_rect()
	draw_rect(board_rect, Color(0.018, 0.025, 0.022, 0.96), true)
	_draw_grid(board_rect)
	_draw_visibility(board_rect)
	_draw_flags(board_rect)
	_draw_pieces(board_rect)
	draw_rect(board_rect, Color(0.54, 0.43, 0.24, 0.9), false, 1.5)


func _draw_grid(board_rect: Rect2) -> void:
	var cell_size := Vector2(board_rect.size.x / BOARD_SIZE.x, board_rect.size.y / BOARD_SIZE.y)
	for x: int in range(BOARD_SIZE.x + 1):
		var px := board_rect.position.x + cell_size.x * x
		draw_line(Vector2(px, board_rect.position.y), Vector2(px, board_rect.end.y), Color(0.35, 0.34, 0.27, 0.2), 1.0)
	for y: int in range(BOARD_SIZE.y + 1):
		var py := board_rect.position.y + cell_size.y * y
		draw_line(Vector2(board_rect.position.x, py), Vector2(board_rect.end.x, py), Color(0.35, 0.34, 0.27, 0.16), 1.0)


func _draw_visibility(board_rect: Rect2) -> void:
	var cell_size := Vector2(board_rect.size.x / BOARD_SIZE.x, board_rect.size.y / BOARD_SIZE.y)
	for cell_value: Variant in _view.get("visible_cells", []):
		var cell := Mapper.coordinate_from_variant(cell_value)
		if not Mapper.is_authority_cell_valid(cell):
			continue
		var display_cell := Mapper.authority_to_display(cell, _display_side)
		var rect := Rect2(board_rect.position + Vector2(display_cell) * cell_size, cell_size)
		draw_rect(rect.grow(-0.5), Color(0.32, 0.38, 0.25, 0.34), true)


func _draw_flags(board_rect: Rect2) -> void:
	for flag_value: Variant in _view.get("flags", []):
		if not flag_value is Dictionary or not _flag_is_drawable(flag_value):
			continue
		var cell := Mapper.coordinate_from_variant(flag_value.get("position", []))
		var center := _cell_center(cell, board_rect)
		var radius := maxf(2.0, minf(board_rect.size.x / BOARD_SIZE.x, board_rect.size.y / BOARD_SIZE.y) * 0.34)
		var color := _side_color(str(flag_value.get("owner", "")))
		var points := PackedVector2Array([
			center + Vector2(0.0, -radius), center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius), center + Vector2(-radius, 0.0),
		])
		draw_colored_polygon(points, color)


func _draw_pieces(board_rect: Rect2) -> void:
	for piece_value: Variant in _view.get("pieces", []):
		if not piece_value is Dictionary or not _piece_is_drawable(piece_value):
			continue
		var cell := Mapper.coordinate_from_variant(piece_value.get("position", []))
		var center := _cell_center(cell, board_rect)
		var radius := maxf(1.8, minf(board_rect.size.x / BOARD_SIZE.x, board_rect.size.y / BOARD_SIZE.y) * 0.26)
		draw_circle(center, radius, _side_color(str(piece_value.get("side", ""))))
		draw_arc(center, radius, 0.0, TAU, 12, Color(0.9, 0.8, 0.56, 0.86), 1.0)


func _board_rect() -> Rect2:
	var cell_scale := minf(size.x / BOARD_SIZE.x, size.y / BOARD_SIZE.y)
	var board_size := Vector2(BOARD_SIZE) * cell_scale
	return Rect2((size - board_size) * 0.5, board_size)


func _cell_center(cell: Vector2i, board_rect: Rect2) -> Vector2:
	var display_cell := Mapper.authority_to_display(cell, _display_side)
	var cell_size := Vector2(board_rect.size.x / BOARD_SIZE.x, board_rect.size.y / BOARD_SIZE.y)
	return board_rect.position + (Vector2(display_cell) + Vector2(0.5, 0.5)) * cell_size


func _piece_is_drawable(piece: Dictionary) -> bool:
	return bool(piece.get("alive", false)) \
		and not bool(piece.get("in_reserve", false)) \
		and Mapper.is_authority_cell_valid(Mapper.coordinate_from_variant(piece.get("position", [])))


func _flag_is_drawable(flag: Dictionary) -> bool:
	return bool(flag.get("discovered", false)) \
		and Mapper.is_authority_cell_valid(Mapper.coordinate_from_variant(flag.get("position", [])))


func _side_color(side: String) -> Color:
	match side:
		"red":
			return Color(0.72, 0.25, 0.18, 0.96)
		"black":
			return Color(0.25, 0.42, 0.34, 0.96)
	return Color(0.8, 0.67, 0.36, 0.96)
