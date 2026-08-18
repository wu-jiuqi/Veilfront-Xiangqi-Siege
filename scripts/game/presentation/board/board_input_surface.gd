extends Control

signal point_activated(cell: Vector2i)
signal cancel_or_marker_requested(cell: Vector2i)
signal zoom_requested(step: float)

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

var _side: String = "red"
var _cell_size := Vector2(128.0, 128.0)


func configure(side: String, cell_size: Vector2) -> void:
	_side = side
	_cell_size = cell_size
	custom_minimum_size = Vector2(9.0 * _cell_size.x, 24.0 * _cell_size.y)
	size = custom_minimum_size


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_requested.emit(1.0)
		accept_event()
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_requested.emit(-1.0)
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
