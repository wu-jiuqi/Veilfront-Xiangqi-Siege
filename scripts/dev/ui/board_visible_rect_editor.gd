class_name BoardVisibleRectEditor
extends Control

signal calibration_rect_changed(rect: Rect2)

const EDGE_LEFT := 1
const EDGE_TOP := 2
const EDGE_RIGHT := 4
const EDGE_BOTTOM := 8

@export var minimum_rect_size := Vector2(240.0, 180.0)
@export var snap_step: float = 8.0

@onready var _move_label: Label = %MoveLabel
@onready var _handles: Dictionary = {
	%HandleTopLeft: EDGE_LEFT | EDGE_TOP,
	%HandleTop: EDGE_TOP,
	%HandleTopRight: EDGE_RIGHT | EDGE_TOP,
	%HandleLeft: EDGE_LEFT,
	%HandleRight: EDGE_RIGHT,
	%HandleBottomLeft: EDGE_LEFT | EDGE_BOTTOM,
	%HandleBottom: EDGE_BOTTOM,
	%HandleBottomRight: EDGE_RIGHT | EDGE_BOTTOM,
}

var _dragging: bool = false
var _drag_edges: int = 0
var _drag_start_mouse := Vector2.ZERO
var _drag_start_rect := Rect2()


func _ready() -> void:
	gui_input.connect(_on_surface_gui_input)
	resized.connect(queue_redraw)
	for handle_value: Variant in _handles:
		var handle := handle_value as Control
		var edges: int = int(_handles[handle])
		handle.gui_input.connect(_on_handle_gui_input.bind(edges))
		_apply_handle_cursor(handle, edges)
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	set_process_input(false)
	queue_redraw()


func set_calibration_rect(requested_rect: Rect2, emit_change: bool = true) -> void:
	var bounded := _clamp_rect(requested_rect)
	position = bounded.position
	size = bounded.size
	queue_redraw()
	if emit_change:
		calibration_rect_changed.emit(get_calibration_rect())


func get_calibration_rect() -> Rect2:
	return Rect2(position, size)


func set_snap_step(value: float) -> void:
	snap_step = maxf(1.0, value)


func get_handle_count() -> int:
	return _handles.size()


func _draw() -> void:
	var inner_rect := Rect2(Vector2.ZERO, size)
	draw_rect(inner_rect, Color(0.08, 0.72, 0.78, 0.13), true)
	draw_rect(inner_rect.grow(-2.0), Color(0.31, 0.95, 0.97, 0.95), false, 3.0)
	draw_line(Vector2(size.x * 0.5, 0.0), Vector2(size.x * 0.5, size.y), Color(0.45, 0.92, 0.94, 0.32), 1.0)
	draw_line(Vector2(0.0, size.y * 0.5), Vector2(size.x, size.y * 0.5), Color(0.45, 0.92, 0.94, 0.32), 1.0)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_update_drag(_get_canvas_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			_end_drag()
			get_viewport().set_input_as_handled()


func _on_surface_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_begin_drag(0)
			accept_event()


func _on_handle_gui_input(event: InputEvent, edges: int) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_begin_drag(edges)
			accept_event()


func _begin_drag(edges: int) -> void:
	_dragging = true
	_drag_edges = edges
	_drag_start_mouse = _get_canvas_mouse_position()
	_drag_start_rect = get_calibration_rect()
	_move_label.text = "棋盘默认可视区域（不是完整棋盘）\n拖动中：%s" % (
		"移动区域" if edges == 0 else "调整边界"
	)
	set_process_input(true)


func _end_drag() -> void:
	_dragging = false
	_drag_edges = 0
	_move_label.text = "棋盘默认可视区域\n不是棋盘完整尺寸\n拖动内部移动 · 拖动八个控制点缩放"
	set_process_input(false)


func _update_drag(mouse_position: Vector2) -> void:
	var delta := mouse_position - _drag_start_mouse
	var next_rect := _drag_start_rect
	if _drag_edges == 0:
		next_rect.position = _snap_vector(_drag_start_rect.position + delta)
	else:
		var left := _drag_start_rect.position.x
		var top := _drag_start_rect.position.y
		var right := _drag_start_rect.end.x
		var bottom := _drag_start_rect.end.y
		if _drag_edges & EDGE_LEFT:
			left = _snap_value(left + delta.x)
		if _drag_edges & EDGE_TOP:
			top = _snap_value(top + delta.y)
		if _drag_edges & EDGE_RIGHT:
			right = _snap_value(right + delta.x)
		if _drag_edges & EDGE_BOTTOM:
			bottom = _snap_value(bottom + delta.y)
		if right - left < minimum_rect_size.x:
			if _drag_edges & EDGE_LEFT:
				left = right - minimum_rect_size.x
			else:
				right = left + minimum_rect_size.x
		if bottom - top < minimum_rect_size.y:
			if _drag_edges & EDGE_TOP:
				top = bottom - minimum_rect_size.y
			else:
				bottom = top + minimum_rect_size.y
		next_rect = Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
	set_calibration_rect(next_rect)


func _clamp_rect(requested_rect: Rect2) -> Rect2:
	var parent_control := get_parent_control()
	if parent_control == null:
		return requested_rect
	var bounds := parent_control.size
	var bounded_size := Vector2(
		clampf(requested_rect.size.x, minimum_rect_size.x, maxf(minimum_rect_size.x, bounds.x)),
		clampf(requested_rect.size.y, minimum_rect_size.y, maxf(minimum_rect_size.y, bounds.y))
	)
	var bounded_position := Vector2(
		clampf(requested_rect.position.x, 0.0, maxf(0.0, bounds.x - bounded_size.x)),
		clampf(requested_rect.position.y, 0.0, maxf(0.0, bounds.y - bounded_size.y))
	)
	return Rect2(bounded_position, bounded_size)


func _snap_vector(value: Vector2) -> Vector2:
	return Vector2(_snap_value(value.x), _snap_value(value.y))


func _snap_value(value: float) -> float:
	return snappedf(value, maxf(1.0, snap_step))


func _get_canvas_mouse_position() -> Vector2:
	var parent_control := get_parent_control()
	return parent_control.get_local_mouse_position() if parent_control != null else get_local_mouse_position()


func _apply_handle_cursor(handle: Control, edges: int) -> void:
	if edges in [EDGE_LEFT, EDGE_RIGHT]:
		handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	elif edges in [EDGE_TOP, EDGE_BOTTOM]:
		handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	elif edges in [EDGE_LEFT | EDGE_TOP, EDGE_RIGHT | EDGE_BOTTOM]:
		handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	else:
		handle.mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE
