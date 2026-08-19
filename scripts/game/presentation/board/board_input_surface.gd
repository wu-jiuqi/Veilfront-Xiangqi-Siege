extends Control

signal point_activated(cell: Vector2i)
signal cancel_or_marker_requested(cell: Vector2i)
signal zoom_requested(step: float)
signal pan_requested(amount: float)
signal point_hovered(cell: Vector2i)
signal point_hover_ended()

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

var _side: String = "red"
var _cell_size := Vector2(128.0, 128.0)
var _hovered_cell := Vector2i.ZERO


func _ready() -> void:
	mouse_exited.connect(_clear_hover)


func configure(side: String, cell_size: Vector2) -> void:
	_side = side
	_cell_size = cell_size
	custom_minimum_size = Vector2(9.0 * _cell_size.x, 24.0 * _cell_size.y)
	size = custom_minimum_size


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if mouse_event.ctrl_pressed:
			zoom_requested.emit(1.0)
		else:
			pan_requested.emit(-maxf(mouse_event.factor, 1.0))
		accept_event()
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if mouse_event.ctrl_pressed:
			zoom_requested.emit(-1.0)
		else:
			pan_requested.emit(maxf(mouse_event.factor, 1.0))
		accept_event()
		return
	var cell: Vector2i = Mapper.world_to_authority(mouse_event.position, _side, _cell_size)
	if not Mapper.is_authority_cell_valid(cell):
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		point_activated.emit(cell)
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_or_marker_requested.emit(cell)
		accept_event()


func _update_hover(local_position: Vector2) -> void:
	var cell := Mapper.world_to_authority(local_position, _side, _cell_size)
	if Mapper.is_authority_cell_valid(cell):
		var point_position := Mapper.authority_to_world(cell, _side, _cell_size)
		var hover_radius := minf(_cell_size.x, _cell_size.y) * 0.3
		if local_position.distance_to(point_position) > hover_radius:
			cell = Vector2i.ZERO
	if cell == _hovered_cell:
		return
	_hovered_cell = cell
	if Mapper.is_authority_cell_valid(cell):
		point_hovered.emit(cell)
	else:
		point_hover_ended.emit()


func _clear_hover() -> void:
	if _hovered_cell == Vector2i.ZERO:
		return
	_hovered_cell = Vector2i.ZERO
	point_hover_ended.emit()
