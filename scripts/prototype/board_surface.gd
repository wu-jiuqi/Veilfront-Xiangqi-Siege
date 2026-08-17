extends Control

signal point_pressed(cell: Array)
signal annotation_changed(cell: Array, marker: String)
signal selection_cancel_requested()

const BOARD_WIDTH: int = 9
const BOARD_HEIGHT: int = 24
const RED: String = "red"
const BLACK: String = "black"

@export_range(40.0, 80.0, 1.0) var cell_size: float = 64.0
@export var board_padding: Vector2 = Vector2(32.0, 32.0)

var point_spacing: Vector2 = Vector2(64.0, 64.0)

var _player_view: Dictionary = {}
var _action_previews: Array = []
var _selected_piece_id: String = ""
var _selected_origin: Array = []
var _action_mode: String = "move"
var _can_interact: bool = false
var _annotations: Dictionary = {}
var _annotation_cell: Array = []

@onready var annotation_menu: PopupMenu = $AnnotationMenu


func _ready() -> void:
	_apply_cell_size(cell_size)
	annotation_menu.id_pressed.connect(_on_annotation_menu_id_pressed)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_cell_size(value: float) -> void:
	_apply_cell_size(clampf(roundf(value), 40.0, 80.0))


func layout_snapshot() -> Dictionary:
	var labels: Array = []
	for spec: Dictionary in _region_label_specs():
		var row_count: int = int(spec["last_y"]) - int(spec["first_y"]) + 1
		labels.append({
			"text": str(spec["text"]),
			"first_y": int(spec["first_y"]),
			"last_y": int(spec["last_y"]),
			"font_size": _region_label_font_size(row_count, str(spec["text"])),
			"region_height": point_spacing.y * float(row_count),
		})
	return {
		"cell_size": cell_size,
		"point_spacing": [point_spacing.x, point_spacing.y],
		"fog_style": "cell_mask",
		"region_separator_lines": false,
		"region_labels": labels,
		"vision_overlay_style": {
			"rook": "blue_grid_path_line",
			"elephant": "yellow_field_grid_outline",
			"elephant_reveal_outline": false,
		},
	}


func set_board_data(
	player_view: Dictionary,
	action_previews: Array,
	selected_piece_id: String,
	selected_origin: Array,
	action_mode: String,
	can_interact: bool
) -> void:
	_player_view = player_view.duplicate(true)
	_action_previews = action_previews.duplicate(true)
	_selected_piece_id = selected_piece_id
	_selected_origin = selected_origin.duplicate()
	_action_mode = action_mode
	_can_interact = can_interact
	queue_redraw()


func clear_annotations() -> void:
	_annotations.clear()
	queue_redraw()


func annotation_snapshot() -> Dictionary:
	return _annotations.duplicate(true)


func logical_to_local(cell: Vector2i) -> Vector2:
	var display := _logical_to_display(cell)
	return board_padding + Vector2(display.x * point_spacing.x, display.y * point_spacing.y)


func local_to_logical(local_position: Vector2) -> Vector2i:
	var relative: Vector2 = local_position - board_padding
	var display := Vector2i(
		roundi(relative.x / point_spacing.x),
		roundi(relative.y / point_spacing.y)
	)
	if display.x < 0 or display.x >= BOARD_WIDTH or display.y < 0 or display.y >= BOARD_HEIGHT:
		return Vector2i.ZERO
	var center: Vector2 = board_padding + Vector2(display.x * point_spacing.x, display.y * point_spacing.y)
	if absf(local_position.x - center.x) > point_spacing.x * 0.46 \
	or absf(local_position.y - center.y) > point_spacing.y * 0.46:
		return Vector2i.ZERO
	return _display_to_logical(display)


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	var cell: Vector2i = local_to_logical(mouse_event.position)
	if cell == Vector2i.ZERO:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		point_pressed.emit([cell.x, cell.y])
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if not _selected_piece_id.is_empty():
			_annotation_cell = []
			selection_cancel_requested.emit()
			accept_event()
			return
		_annotation_cell = [cell.x, cell.y]
		annotation_menu.position = Vector2i(get_viewport().get_mouse_position())
		annotation_menu.popup()
		accept_event()


func _on_annotation_menu_id_pressed(id: int) -> void:
	if _annotation_cell.size() != 2:
		return
	var key: String = _cell_key(Vector2i(int(_annotation_cell[0]), int(_annotation_cell[1])))
	var marker: String = {1: "circle", 2: "cross", 3: "square", 4: ""}.get(id, "")
	if marker.is_empty():
		_annotations.erase(key)
	else:
		_annotations[key] = marker
	annotation_changed.emit(_annotation_cell.duplicate(), marker)
	queue_redraw()


func _draw() -> void:
	_draw_region_bands()
	_draw_grid_lines()
	_draw_fog_and_contacts()
	_draw_region_labels()
	_draw_walls()
	_draw_vision_overlays()
	_draw_annotations()
	_draw_capture_ghosts()
	_draw_action_highlights()
	_draw_discovered_flags()
	_draw_pieces()
	_draw_coordinate_labels()


func _draw_region_bands() -> void:
	var left: float = board_padding.x - point_spacing.x * 0.5
	var width: float = point_spacing.x * float(BOARD_WIDTH)
	for logical_y: int in range(1, BOARD_HEIGHT + 1):
		var center_y: float = logical_to_local(Vector2i(1, logical_y)).y
		var band := Rect2(
			Vector2(left, center_y - point_spacing.y * 0.5),
			Vector2(width, point_spacing.y)
		)
		draw_rect(band, _region_color(logical_y), true)


func _draw_grid_lines() -> void:
	var top: float = logical_to_local(_display_to_logical(Vector2i(0, 0))).y
	var bottom: float = logical_to_local(_display_to_logical(Vector2i(0, BOARD_HEIGHT - 1))).y
	for display_x: int in BOARD_WIDTH:
		var x: float = board_padding.x + display_x * point_spacing.x
		draw_line(Vector2(x, top), Vector2(x, bottom), Color(0.075, 0.09, 0.11, 0.72), 1.6, true)
	for display_y: int in BOARD_HEIGHT:
		var y: float = board_padding.y + display_y * point_spacing.y
		draw_line(
			Vector2(board_padding.x, y),
			Vector2(board_padding.x + point_spacing.x * float(BOARD_WIDTH - 1), y),
			Color(0.075, 0.09, 0.11, 0.72), 1.6, true
		)


func _draw_walls() -> void:
	var left: float = board_padding.x - point_spacing.x * 0.5
	var right: float = board_padding.x + point_spacing.x * 8.5
	for wall_y: int in [4, 21]:
		var wall_color: Color = Color(0.95, 0.34, 0.27, 0.96) if wall_y == 4 \
			else Color(0.38, 0.68, 1.0, 0.96)
		var y: float = logical_to_local(Vector2i(1, wall_y)).y
		draw_line(Vector2(left, y), Vector2(right, y), wall_color, 7.0, true)


func _draw_region_labels() -> void:
	var left: float = board_padding.x - point_spacing.x * 0.5
	var width: float = point_spacing.x * float(BOARD_WIDTH)
	for spec: Dictionary in _region_label_specs():
		var first_y: int = int(spec["first_y"])
		var last_y: int = int(spec["last_y"])
		var top_center: float = logical_to_local(Vector2i(5, first_y)).y
		var bottom_center: float = logical_to_local(Vector2i(5, last_y)).y
		var center_y: float = (top_center + bottom_center) * 0.5
		var row_count: int = last_y - first_y + 1
		var font_size: int = _region_label_font_size(row_count, str(spec["text"]))
		draw_string(
			ThemeDB.fallback_font,
			Vector2(left, center_y + float(font_size) * 0.34),
			str(spec["text"]),
			HORIZONTAL_ALIGNMENT_CENTER,
			width,
			font_size,
			Color(1.0, 1.0, 1.0, 0.16)
		)


func _draw_vision_overlays() -> void:
	var overlays: Dictionary = _player_view.get("vision_overlays", {})
	for source: Dictionary in overlays.get("rook_paths", []):
		_draw_rook_grid_path(source.get("cells", []))
	for source: Dictionary in overlays.get("elephant_block_fields", []):
		_draw_elephant_field_grid_outline(source.get("cells", []))


func _draw_rook_grid_path(cells: Array) -> void:
	var points: Array[Vector2i] = _normalized_overlay_cells(cells)
	if points.size() < 2:
		return
	points.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	var from: Vector2 = logical_to_local(points.front())
	var to: Vector2 = logical_to_local(points.back())
	draw_line(from, to, Color(0.04, 0.32, 0.78, 0.42), 9.0, true)
	draw_line(from, to, Color(0.28, 0.78, 1.0, 0.98), 4.5, true)


func _draw_elephant_field_grid_outline(cells: Array) -> void:
	var points: Array[Vector2i] = _normalized_overlay_cells(cells)
	if points.is_empty():
		return
	var min_x: int = points[0].x
	var max_x: int = points[0].x
	var min_y: int = points[0].y
	var max_y: int = points[0].y
	for cell: Vector2i in points:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	var top_left: Vector2 = logical_to_local(Vector2i(min_x, min_y))
	var top_right: Vector2 = logical_to_local(Vector2i(max_x, min_y))
	var bottom_right: Vector2 = logical_to_local(Vector2i(max_x, max_y))
	var bottom_left: Vector2 = logical_to_local(Vector2i(min_x, max_y))
	var outline := PackedVector2Array([top_left, top_right, bottom_right, bottom_left, top_left])
	draw_polyline(outline, Color(0.72, 0.48, 0.02, 0.44), 9.0, true)
	draw_polyline(outline, Color(1.0, 0.82, 0.18, 0.98), 4.5, true)


func _normalized_overlay_cells(cells: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary = {}
	for cell_value: Variant in cells:
		if not cell_value is Array or cell_value.size() != 2:
			continue
		var cell := Vector2i(int(cell_value[0]), int(cell_value[1]))
		var key: String = _cell_key(cell)
		if seen.has(key):
			continue
		seen[key] = true
		result.append(cell)
	return result


func _draw_annotations() -> void:
	var color := Color(0.72, 0.5, 1.0, 0.5)
	for key: String in _annotations.keys():
		var parts: PackedStringArray = key.split(",")
		var center: Vector2 = logical_to_local(Vector2i(int(parts[0]), int(parts[1])))
		match str(_annotations[key]):
			"circle":
				draw_arc(center, 10.0, 0.0, TAU, 24, color, 2.0, true)
			"cross":
				draw_line(center + Vector2(-7, -7), center + Vector2(7, 7), color, 2.0, true)
				draw_line(center + Vector2(-7, 7), center + Vector2(7, -7), color, 2.0, true)
			"square":
				draw_rect(Rect2(center - Vector2(8, 8), Vector2(16, 16)), color, false, 2.0)


func _draw_fog_and_contacts() -> void:
	var visible: Dictionary = _coordinate_set(_player_view.get("visible_cells", []))
	var half_cell: Vector2 = point_spacing * 0.5
	for y: int in range(1, BOARD_HEIGHT + 1):
		for x: int in range(1, BOARD_WIDTH + 1):
			var cell := Vector2i(x, y)
			if not visible.has(_cell_key(cell)):
				var center: Vector2 = logical_to_local(cell)
				draw_rect(Rect2(center - half_cell, point_spacing), Color(0.01, 0.014, 0.02, 0.7), true)
	for contact: Dictionary in _player_view.get("contact_intel", []):
		var cell_value: Array = contact.get("cell", [])
		if cell_value.size() == 2:
			var center: Vector2 = logical_to_local(Vector2i(int(cell_value[0]), int(cell_value[1])))
			draw_arc(center, 13.0, 0.0, TAU, 24, Color(1.0, 0.46, 0.18, 0.95), 3.0, true)


func _draw_capture_ghosts() -> void:
	for ghost: Dictionary in _player_view.get("capture_ghosts", []):
		var value: Array = ghost.get("position", [])
		if value.size() != 2:
			continue
		var center: Vector2 = logical_to_local(Vector2i(int(value[0]), int(value[1])))
		var side: String = str(ghost.get("side", ""))
		var color: Color = Color(0.95, 0.3, 0.25, 0.25) if side == RED else Color(0.55, 0.7, 0.95, 0.25)
		draw_circle(center, 15.0, color)
		draw_arc(center, 15.0, 0.0, TAU, 28, Color(color, 0.46), 2.0, true)
		_draw_piece_text(center, _piece_mark(str(ghost.get("piece_type", "")), side), Color(1, 1, 1, 0.38))


func _draw_action_highlights() -> void:
	if _selected_piece_id.is_empty():
		return
	for preview: Dictionary in _action_previews:
		if str(preview.get("piece_id", "")) != _selected_piece_id \
		or str(preview.get("action_type", "")) != _action_mode:
			continue
		var value: Array = preview.get("target_cell", [])
		if value.size() != 2:
			continue
		var color: Color
		match str(preview.get("classification", "")):
			"KNOWN_LEGAL": color = Color(0.3, 1.0, 0.48, 0.96)
			"TENTATIVE": color = Color(1.0, 0.78, 0.18, 0.96)
			_: color = Color(0.42, 0.44, 0.48, 0.45)
		var center: Vector2 = logical_to_local(Vector2i(int(value[0]), int(value[1])))
		draw_circle(center, 7.0, Color(color, 0.24))
		draw_arc(center, 9.0, 0.0, TAU, 20, color, 2.5, true)
	if _selected_origin.size() == 2:
		var selected_center: Vector2 = logical_to_local(Vector2i(int(_selected_origin[0]), int(_selected_origin[1])))
		draw_arc(selected_center, 19.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.35, 1.0), 3.5, true)


func _draw_discovered_flags() -> void:
	for flag: Dictionary in _player_view.get("flags", []):
		if not bool(flag.get("discovered", false)):
			continue
		var value: Array = flag.get("position", [])
		if value.size() != 2:
			continue
		var center: Vector2 = logical_to_local(Vector2i(int(value[0]), int(value[1]))) + Vector2(11, -16)
		var owner: String = str(flag.get("owner", "neutral"))
		var color: Color = Color(0.95, 0.82, 0.28, 1.0)
		if owner == RED:
			color = Color(1.0, 0.34, 0.28, 1.0)
		elif owner == BLACK:
			color = Color(0.38, 0.68, 1.0, 1.0)
		draw_line(center + Vector2(-5, -4), center + Vector2(-5, 9), color, 2.0, true)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-4, -4), center + Vector2(8, 0), center + Vector2(-4, 5)
		]), color)


func _draw_pieces() -> void:
	for piece: Dictionary in _player_view.get("pieces", []):
		if not bool(piece.get("alive", false)) or bool(piece.get("in_reserve", false)):
			continue
		var value: Array = piece.get("position", [])
		if value.size() != 2:
			continue
		var center: Vector2 = logical_to_local(Vector2i(int(value[0]), int(value[1])))
		var side: String = str(piece.get("side", ""))
		var fill: Color = Color(0.62, 0.12, 0.1, 0.98) if side == RED else Color(0.11, 0.2, 0.34, 0.98)
		var border: Color = Color(1.0, 0.55, 0.4, 1.0) if side == RED else Color(0.55, 0.78, 1.0, 1.0)
		var radius: float = clampf(cell_size * 0.29, 13.0, 22.0)
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, 30, border, 2.3, true)
		_draw_piece_text(center, _piece_mark(str(piece.get("piece_type", "")), side), Color.WHITE)


func _draw_piece_text(center: Vector2, text: String, color: Color) -> void:
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-15, 6),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		30.0,
		18,
		color
	)


func _draw_coordinate_labels() -> void:
	for display_x: int in BOARD_WIDTH:
		var logical: Vector2i = _display_to_logical(Vector2i(display_x, BOARD_HEIGHT - 1))
		var center: Vector2 = board_padding + Vector2(display_x * point_spacing.x, (BOARD_HEIGHT - 1) * point_spacing.y)
		draw_string(ThemeDB.fallback_font, center + Vector2(-10, 24), str(logical.x), HORIZONTAL_ALIGNMENT_CENTER, 20, 12, Color(0.8, 0.82, 0.86, 0.9))


func _logical_to_display(cell: Vector2i) -> Vector2i:
	if str(_player_view.get("viewer_side", RED)) == BLACK:
		return Vector2i(BOARD_WIDTH - cell.x, cell.y - 1)
	return Vector2i(cell.x - 1, BOARD_HEIGHT - cell.y)


func _display_to_logical(display: Vector2i) -> Vector2i:
	if str(_player_view.get("viewer_side", RED)) == BLACK:
		return Vector2i(BOARD_WIDTH - display.x, display.y + 1)
	return Vector2i(display.x + 1, BOARD_HEIGHT - display.y)


func _coordinate_set(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in cells:
		if value is Array and value.size() == 2:
			result[_cell_key(Vector2i(int(value[0]), int(value[1])))] = true
	return result


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _region_color(y: int) -> Color:
	if y <= 3:
		return Color(0.72, 0.25, 0.2, 1.0)
	if y <= 8:
		return Color(0.59, 0.37, 0.22, 1.0)
	if y <= 16:
		return Color(0.45, 0.52, 0.44, 1.0)
	if y <= 21:
		return Color(0.25, 0.43, 0.64, 1.0)
	return Color(0.2, 0.3, 0.72, 1.0)


func _apply_cell_size(value: float) -> void:
	cell_size = value
	point_spacing = Vector2(cell_size, cell_size)
	custom_minimum_size = Vector2(
		board_padding.x * 2.0 + cell_size * float(BOARD_WIDTH - 1),
		board_padding.y * 2.0 + cell_size * float(BOARD_HEIGHT - 1)
	)
	queue_redraw()


func _region_label_specs() -> Array:
	return [
		{"text": "大本营", "first_y": 1, "last_y": 3},
		{"text": "缓冲区", "first_y": 4, "last_y": 8},
		{"text": "战区", "first_y": 9, "last_y": 16},
		{"text": "缓冲区", "first_y": 17, "last_y": 21},
		{"text": "大本营", "first_y": 22, "last_y": 24},
	]


func _region_label_font_size(row_count: int, text: String) -> int:
	var height_limit: float = point_spacing.y * float(row_count) * 0.34
	var width_limit: float = point_spacing.x * float(BOARD_WIDTH) / maxf(1.0, float(text.length()) * 0.78)
	return int(clampf(minf(height_limit, width_limit), 28.0, 52.0))


func _piece_mark(piece_type: String, side: String) -> String:
	if side == RED:
		return {
			"rook": "车", "horse": "马", "elephant": "相", "advisor": "仕",
			"general": "帅", "cannon": "炮", "pawn": "兵",
		}.get(piece_type, "?")
	return {
		"rook": "车", "horse": "马", "elephant": "象", "advisor": "士",
		"general": "将", "cannon": "炮", "pawn": "卒",
	}.get(piece_type, "?")
