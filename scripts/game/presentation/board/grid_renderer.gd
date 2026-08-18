extends Node2D

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

const REGION_LABELS: Dictionary = {
	"red_headquarters": "大本营",
	"red_buffer": "缓冲区",
	"warzone": "战区",
	"black_buffer": "缓冲区",
	"black_headquarters": "大本营",
}

var _board_size := Vector2i(9, 24)
var _cell_size := Vector2(128.0, 128.0)
var _side: String = "red"
var _palette: Dictionary = {}
var _label_style: Dictionary = {}


func configure(board: Dictionary, side: String, board_theme: BoardTheme) -> void:
	_board_size = Vector2i(int(board.get("width", 9)), int(board.get("height", 24)))
	_side = side
	_cell_size = board_theme.cell_size
	_palette = board_theme.grid_palette.duplicate(true)
	_label_style = board_theme.region_label_style.duplicate(true)
	queue_redraw()


func get_point_spacing() -> Vector2:
	return _cell_size


func _draw() -> void:
	_draw_region_bands()
	_draw_grid()


func _draw_region_bands() -> void:
	var start_row: int = 0
	var current_region: String = _region_for_display_row(0)
	for display_row: int in range(1, _board_size.y + 1):
		var next_region: String = _region_for_display_row(display_row) if display_row < _board_size.y else ""
		if next_region == current_region:
			continue
		var row_count: int = display_row - start_row
		var band_rect := Rect2(
			Vector2(0.0, float(start_row) * _cell_size.y),
			Vector2(float(_board_size.x) * _cell_size.x, float(row_count) * _cell_size.y)
		)
		draw_rect(band_rect, _region_color(current_region))
		_draw_region_label(band_rect, str(REGION_LABELS.get(current_region, "")))
		start_row = display_row
		current_region = next_region


func _draw_grid() -> void:
	var line_color := Color(0.13, 0.1, 0.08, 0.72)
	var first_center := _cell_size * 0.5
	var last_center := Vector2(
		(float(_board_size.x) - 0.5) * _cell_size.x,
		(float(_board_size.y) - 0.5) * _cell_size.y
	)
	for display_x: int in _board_size.x:
		var x: float = (float(display_x) + 0.5) * _cell_size.x
		draw_line(Vector2(x, first_center.y), Vector2(x, last_center.y), line_color, 3.0, true)
	for display_y: int in _board_size.y:
		var y: float = (float(display_y) + 0.5) * _cell_size.y
		draw_line(Vector2(first_center.x, y), Vector2(last_center.x, y), line_color, 3.0, true)


func _draw_region_label(rect: Rect2, text: String) -> void:
	if text.is_empty():
		return
	var preferred_size: int = int(_label_style.get("font_size", 72))
	var size_from_height: int = maxi(18, floori(rect.size.y * 0.28))
	var size_from_width: int = maxi(18, floori(rect.size.x / maxf(float(text.length()) * 1.25, 1.0)))
	var font_size: int = mini(preferred_size, mini(size_from_height, size_from_width))
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(
		rect.position.x + (rect.size.x - text_size.x) * 0.5,
		rect.position.y + (rect.size.y + text_size.y * 0.55) * 0.5
	)
	draw_string(
		font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		_label_style.get("font_color", Color(0.94, 0.88, 0.74, 0.24))
	)


func _region_for_display_row(display_row: int) -> String:
	var authority_cell: Vector2i = Mapper.display_to_authority(Vector2i(0, display_row), _side)
	var y: int = authority_cell.y
	if y <= 3:
		return "red_headquarters"
	if y <= 8:
		return "red_buffer"
	if y <= 16:
		return "warzone"
	if y <= 21:
		return "black_buffer"
	return "black_headquarters"


func _region_color(region: String) -> Color:
	match region:
		"red_headquarters", "black_headquarters":
			return _palette.get("headquarters", Color(0.72, 0.58, 0.36, 1.0))
		"red_buffer", "black_buffer":
			return _palette.get("buffer", Color(0.61, 0.46, 0.32, 1.0))
		_:
			return _palette.get("warzone", Color(0.45, 0.36, 0.28, 1.0))
