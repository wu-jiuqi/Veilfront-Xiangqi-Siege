extends SubViewportContainer

signal point_activated(cell: Vector2i)
signal cancel_or_marker_requested(cell: Vector2i)

const BOARD_WORLD_SIZE := Vector2(1152.0, 3072.0)
const SCREEN_MARGIN: float = 24.0
const PAN_SPEED: float = 720.0

@onready var _sub_viewport: SubViewport = $BoardSubViewport
@onready var _board_world: Node2D = $BoardSubViewport/BoardWorld
@onready var _camera: Camera2D = $BoardSubViewport/BoardWorld/BoardCamera2D

var _fit_zoom: float = 1.0
var _zoom_multiplier: float = 1.0
var _focused_cell := Vector2i.ZERO


func _ready() -> void:
	resized.connect(_sync_layout)
	_board_world.point_activated.connect(_on_point_activated)
	_board_world.cancel_or_marker_requested.connect(_on_cancel_or_marker_requested)
	_board_world.zoom_requested.connect(_apply_zoom_step)
	_sync_layout()


func _process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector(
		&"board_pan_left", &"board_pan_right", &"board_pan_up", &"board_pan_down"
	)
	if direction.is_zero_approx():
		return
	_camera.position.y += direction.y * PAN_SPEED * delta / maxf(_camera.zoom.y, 0.01)
	_clamp_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"board_zoom_in"):
		_apply_zoom_step(1.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"board_zoom_out"):
		_apply_zoom_step(-1.0)
		get_viewport().set_input_as_handled()


func render_player_view(view: Dictionary) -> void:
	_board_world.render_player_view(view)
	if BoardCoordinateMapper.is_authority_cell_valid(_focused_cell):
		focus_authority_cell(_focused_cell)
	else:
		reset_camera()


func set_marker(cell: Vector2i, marker_type: String) -> void:
	_board_world.set_marker(cell, marker_type)


func set_interaction(selected_cell: Vector2i, action_previews: Array) -> void:
	_board_world.set_interaction(selected_cell, action_previews)


func clear_interaction() -> void:
	_board_world.clear_interaction()


func focus_authority_cell(cell: Vector2i) -> void:
	if not BoardCoordinateMapper.is_authority_cell_valid(cell):
		return
	_focused_cell = cell
	_zoom_multiplier = 1.0
	_update_camera_zoom()
	var world_position: Vector2 = BoardCoordinateMapper.authority_to_world(
		cell,
		str(_board_world.get_viewer_side()),
		_board_world.get_cell_size()
	)
	_camera.position = Vector2(BOARD_WORLD_SIZE.x * 0.5, world_position.y)
	_clamp_camera()


func set_tutorial_target(cell: Vector2i) -> void:
	_board_world.set_tutorial_target(cell)


func reset_camera() -> void:
	_zoom_multiplier = 1.0
	_update_camera_zoom()
	var visible_world_height: float = size.y / maxf(_camera.zoom.y, 0.01)
	_camera.position = Vector2(
		BOARD_WORLD_SIZE.x * 0.5,
		BOARD_WORLD_SIZE.y - visible_world_height * 0.5
	)
	_clamp_camera()


func get_point_spacing() -> Vector2:
	var world_spacing: Vector2 = _board_world.get_point_spacing()
	return world_spacing * _camera.zoom


func get_board_world() -> Node2D:
	return _board_world


func get_render_snapshot() -> Dictionary:
	var snapshot: Dictionary = _board_world.get_render_snapshot()
	snapshot["focused_cell"] = _focused_cell
	snapshot["focused_cell_visible"] = _is_cell_visible(_focused_cell)
	snapshot["camera_position"] = _camera.position
	snapshot["camera_zoom"] = _camera.zoom
	return snapshot


func _sync_layout() -> void:
	var viewport_size := Vector2i(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))
	_fit_zoom = maxf((float(viewport_size.x) - SCREEN_MARGIN) / BOARD_WORLD_SIZE.x, 0.05)
	if BoardCoordinateMapper.is_authority_cell_valid(_focused_cell):
		focus_authority_cell(_focused_cell)
	else:
		reset_camera()


func _is_cell_visible(cell: Vector2i) -> bool:
	if not BoardCoordinateMapper.is_authority_cell_valid(cell):
		return false
	var world_position: Vector2 = BoardCoordinateMapper.authority_to_world(
		cell,
		str(_board_world.get_viewer_side()),
		_board_world.get_cell_size()
	)
	var half_height: float = size.y / maxf(_camera.zoom.y, 0.01) * 0.5
	return world_position.y >= _camera.position.y - half_height \
		and world_position.y <= _camera.position.y + half_height


func _apply_zoom_step(step: float) -> void:
	_zoom_multiplier = clampf(_zoom_multiplier + step * 0.12, 1.0, 1.72)
	_update_camera_zoom()
	_clamp_camera()


func _update_camera_zoom() -> void:
	var zoom_value: float = _fit_zoom * _zoom_multiplier
	_camera.zoom = Vector2(zoom_value, zoom_value)


func _clamp_camera() -> void:
	_camera.position.x = BOARD_WORLD_SIZE.x * 0.5
	var visible_world_height: float = size.y / maxf(_camera.zoom.y, 0.01)
	if visible_world_height >= BOARD_WORLD_SIZE.y:
		_camera.position.y = BOARD_WORLD_SIZE.y * 0.5
		return
	_camera.position.y = clampf(
		_camera.position.y,
		visible_world_height * 0.5,
		BOARD_WORLD_SIZE.y - visible_world_height * 0.5
	)


func _on_point_activated(cell: Vector2i) -> void:
	point_activated.emit(cell)


func _on_cancel_or_marker_requested(cell: Vector2i) -> void:
	cancel_or_marker_requested.emit(cell)
