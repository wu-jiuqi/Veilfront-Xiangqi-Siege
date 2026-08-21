class_name TacticalMinimap
extends Control

signal overview_navigation_requested(display_ratio: Vector2)

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")
const BOARD_SIZE := Vector2i(9, 24)
const VIEWPORT_COLOR := Color(0.94, 0.72, 0.28, 0.98)
const VIEWPORT_FILL := Color(0.94, 0.72, 0.28, 0.1)
const ROOK_PATH_COLOR := Color(0.2, 0.64, 1.0, 0.9)
const ELEPHANT_FIELD_COLOR := Color(1.0, 0.78, 0.18, 0.92)

var _view: Dictionary = {}
var _display_side: String = "red"
var _overview_state: Dictionary = {
	"display_side": "red",
	"viewport_rect_normalized": Rect2(0.0, 0.0, 1.0, 1.0),
	"camera_center_normalized": Vector2(0.5, 0.5),
}
var _navigation_dragging: bool = false


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func render_player_view(view: Dictionary, display_side: String = "red") -> void:
	_view = view.duplicate(true)
	set_presentation_side(display_side)


func set_presentation_side(side: String) -> void:
	_display_side = side if side in ["red", "black"] else "red"
	queue_redraw()


func set_overview_state(state: Dictionary) -> void:
	_overview_state = state.duplicate(true)
	var side := str(_overview_state.get("display_side", _display_side))
	if side in ["red", "black"]:
		_display_side = side
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
	var ghost_count := 0
	for ghost_value: Variant in _view.get("capture_ghosts", []):
		if ghost_value is Dictionary \
		and Mapper.is_authority_cell_valid(Mapper.coordinate_from_variant(
			ghost_value.get("position", [])
		)):
			ghost_count += 1
	var wall_segment_count := 0
	for wall_value: Variant in _view.get("walls", []):
		if wall_value is Dictionary and str(wall_value.get("side", "")) in ["red", "black"]:
			wall_segment_count += BOARD_SIZE.x
	return {
		"display_side": _display_side,
		"visible_cell_count": visible_count,
		"piece_count": piece_count,
		"flag_count": flag_count,
		"ghost_count": ghost_count,
		"wall_segment_count": wall_segment_count,
		"region_band_count": 5,
		"uses_player_view_only": true,
		"bird_eye_mode": true,
		"interactive_navigation": true,
		"viewport_rect_normalized": _overview_state.get(
			"viewport_rect_normalized", Rect2(0.0, 0.0, 1.0, 1.0)
		),
		"camera_center_normalized": _overview_state.get(
			"camera_center_normalized", Vector2(0.5, 0.5)
		),
	}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			if not _board_rect().has_point(mouse_event.position):
				return
			_navigation_dragging = true
			_request_navigation(mouse_event.position)
		else:
			_navigation_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _navigation_dragging:
		_request_navigation((event as InputEventMouseMotion).position)
		accept_event()


func _draw() -> void:
	var board_rect := _board_rect()
	draw_rect(board_rect, Color(0.018, 0.025, 0.022, 0.98), true)
	_draw_region_bands(board_rect)
	_draw_grid(board_rect)
	_draw_fog(board_rect)
	_draw_walls(board_rect)
	_draw_flags(board_rect)
	_draw_capture_ghosts(board_rect)
	_draw_pieces(board_rect)
	_draw_public_overlays(board_rect)
	_draw_camera_viewport(board_rect)
	draw_rect(board_rect, Color(0.54, 0.43, 0.24, 0.9), false, 1.5)


func _draw_region_bands(board_rect: Rect2) -> void:
	var cell_size := _cell_size(board_rect)
	for display_y: int in range(BOARD_SIZE.y):
		var authority_y := Mapper.display_to_authority(Vector2i(0, display_y), _display_side).y
		var color := Color(0.20, 0.16, 0.12, 0.9)
		if authority_y <= 3 or authority_y >= 22:
			color = Color(0.28, 0.20, 0.13, 0.92)
		elif authority_y <= 8 or authority_y >= 17:
			color = Color(0.23, 0.18, 0.13, 0.92)
		draw_rect(Rect2(
			board_rect.position + Vector2(0.0, float(display_y) * cell_size.y),
			Vector2(board_rect.size.x, cell_size.y)
		), color, true)


func _draw_grid(board_rect: Rect2) -> void:
	var cell_size := _cell_size(board_rect)
	for x: int in range(BOARD_SIZE.x + 1):
		var px := board_rect.position.x + cell_size.x * x
		draw_line(
			Vector2(px, board_rect.position.y), Vector2(px, board_rect.end.y),
			Color(0.46, 0.39, 0.27, 0.24), 1.0
		)
	for y: int in range(BOARD_SIZE.y + 1):
		var py := board_rect.position.y + cell_size.y * y
		draw_line(
			Vector2(board_rect.position.x, py), Vector2(board_rect.end.x, py),
			Color(0.46, 0.39, 0.27, 0.2), 1.0
		)


func _draw_fog(board_rect: Rect2) -> void:
	var visible_display_cells: Dictionary = {}
	for cell_value: Variant in _view.get("visible_cells", []):
		var authority_cell := Mapper.coordinate_from_variant(cell_value)
		if Mapper.is_authority_cell_valid(authority_cell):
			visible_display_cells[Mapper.authority_to_display(authority_cell, _display_side)] = true
	var cell_size := _cell_size(board_rect)
	for display_y: int in range(BOARD_SIZE.y):
		for display_x: int in range(BOARD_SIZE.x):
			var display_cell := Vector2i(display_x, display_y)
			if visible_display_cells.has(display_cell):
				continue
			draw_rect(Rect2(
				board_rect.position + Vector2(display_cell) * cell_size,
				cell_size
			), Color(0.005, 0.008, 0.008, 0.72), true)


func _draw_walls(board_rect: Rect2) -> void:
	var cell_size := _cell_size(board_rect)
	for wall_value: Variant in _view.get("walls", []):
		if not wall_value is Dictionary:
			continue
		var wall_side := str(wall_value.get("side", ""))
		if wall_side not in ["red", "black"]:
			continue
		var authority_y := 4 if wall_side == "red" else 21
		var display_y := Mapper.authority_to_display(Vector2i(1, authority_y), _display_side).y
		var y := board_rect.position.y + (float(display_y) + 0.5) * cell_size.y
		var intact := str(wall_value.get("status", "")) == "INTACT"
		var color := _side_color(wall_side) if intact else Color(0.42, 0.4, 0.34, 0.68)
		draw_line(
			Vector2(board_rect.position.x + cell_size.x * 0.25, y),
			Vector2(board_rect.end.x - cell_size.x * 0.25, y),
			color, 2.0 if intact else 1.0
		)


func _draw_flags(board_rect: Rect2) -> void:
	for flag_value: Variant in _view.get("flags", []):
		if not flag_value is Dictionary or not _flag_is_drawable(flag_value):
			continue
		var cell := Mapper.coordinate_from_variant(flag_value.get("position", []))
		var center := _cell_center(cell, board_rect)
		var radius := maxf(2.0, minf(_cell_size(board_rect).x, _cell_size(board_rect).y) * 0.34)
		var color := _side_color(str(flag_value.get("owner", "")))
		var points := PackedVector2Array([
			center + Vector2(0.0, -radius), center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius), center + Vector2(-radius, 0.0),
		])
		draw_colored_polygon(points, color)


func _draw_capture_ghosts(board_rect: Rect2) -> void:
	for ghost_value: Variant in _view.get("capture_ghosts", []):
		if not ghost_value is Dictionary:
			continue
		var cell := Mapper.coordinate_from_variant(ghost_value.get("position", []))
		if not Mapper.is_authority_cell_valid(cell):
			continue
		var center := _cell_center(cell, board_rect)
		var radius := maxf(2.0, minf(_cell_size(board_rect).x, _cell_size(board_rect).y) * 0.28)
		draw_arc(center, radius, 0.0, TAU, 12, Color(0.76, 0.72, 0.64, 0.72), 1.0)
		draw_line(center - Vector2(radius, radius), center + Vector2(radius, radius), Color(0.76, 0.72, 0.64, 0.72), 1.0)


func _draw_pieces(board_rect: Rect2) -> void:
	for piece_value: Variant in _view.get("pieces", []):
		if not piece_value is Dictionary or not _piece_is_drawable(piece_value):
			continue
		var cell := Mapper.coordinate_from_variant(piece_value.get("position", []))
		var center := _cell_center(cell, board_rect)
		var radius := maxf(1.8, minf(_cell_size(board_rect).x, _cell_size(board_rect).y) * 0.28)
		draw_circle(center, radius, _side_color(str(piece_value.get("side", ""))))
		draw_arc(center, radius, 0.0, TAU, 12, Color(0.9, 0.8, 0.56, 0.86), 1.0)


func _draw_public_overlays(board_rect: Rect2) -> void:
	var overlays: Dictionary = _view.get("vision_overlays", {})
	for record_value: Variant in overlays.get("rook_paths", []):
		if not record_value is Dictionary:
			continue
		var points := PackedVector2Array()
		for cell_value: Variant in record_value.get("cells", []):
			var cell := Mapper.coordinate_from_variant(cell_value)
			if Mapper.is_authority_cell_valid(cell):
				points.append(_cell_center(cell, board_rect))
		if points.size() >= 2:
			draw_polyline(points, ROOK_PATH_COLOR, 1.5, true)
	for record_value: Variant in overlays.get("elephant_block_fields", []):
		if record_value is Dictionary:
			_draw_field_outline(record_value.get("cells", []), board_rect)


func _draw_field_outline(cells: Array, board_rect: Rect2) -> void:
	var display_cells: Array[Vector2i] = []
	for cell_value: Variant in cells:
		var cell := Mapper.coordinate_from_variant(cell_value)
		if Mapper.is_authority_cell_valid(cell):
			display_cells.append(Mapper.authority_to_display(cell, _display_side))
	if display_cells.is_empty():
		return
	var min_cell := display_cells[0]
	var max_cell := display_cells[0]
	for display_cell: Vector2i in display_cells:
		min_cell.x = mini(min_cell.x, display_cell.x)
		min_cell.y = mini(min_cell.y, display_cell.y)
		max_cell.x = maxi(max_cell.x, display_cell.x)
		max_cell.y = maxi(max_cell.y, display_cell.y)
	var cell_size := _cell_size(board_rect)
	var outline := Rect2(
		board_rect.position + Vector2(min_cell) * cell_size,
		Vector2(max_cell - min_cell + Vector2i.ONE) * cell_size
	)
	draw_rect(outline, ELEPHANT_FIELD_COLOR, false, 1.25)


func _draw_camera_viewport(board_rect: Rect2) -> void:
	var normalized: Rect2 = _overview_state.get(
		"viewport_rect_normalized", Rect2(0.0, 0.0, 1.0, 1.0)
	)
	var viewport_rect := Rect2(
		board_rect.position + normalized.position * board_rect.size,
		normalized.size * board_rect.size
	).intersection(board_rect)
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return
	draw_rect(viewport_rect, VIEWPORT_FILL, true)
	draw_rect(viewport_rect.grow(-0.75), VIEWPORT_COLOR, false, 1.5)


func _request_navigation(local_position: Vector2) -> void:
	var board_rect := _board_rect()
	var clamped := Vector2(
		clampf(local_position.x, board_rect.position.x, board_rect.end.x),
		clampf(local_position.y, board_rect.position.y, board_rect.end.y)
	)
	var ratio := (clamped - board_rect.position) / board_rect.size
	overview_navigation_requested.emit(Vector2(
		clampf(ratio.x, 0.0, 1.0), clampf(ratio.y, 0.0, 1.0)
	))


func _board_rect() -> Rect2:
	var cell_scale := minf(size.x / BOARD_SIZE.x, size.y / BOARD_SIZE.y)
	var board_size := Vector2(BOARD_SIZE) * cell_scale
	return Rect2((size - board_size) * 0.5, board_size)


func _cell_size(board_rect: Rect2) -> Vector2:
	return Vector2(board_rect.size.x / BOARD_SIZE.x, board_rect.size.y / BOARD_SIZE.y)


func _cell_center(cell: Vector2i, board_rect: Rect2) -> Vector2:
	var display_cell := Mapper.authority_to_display(cell, _display_side)
	return board_rect.position + (Vector2(display_cell) + Vector2(0.5, 0.5)) * _cell_size(board_rect)


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
