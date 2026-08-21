extends SubViewportContainer

signal point_activated(cell: Vector2i)
signal cancel_or_marker_requested(cell: Vector2i)
signal hovered_cell_changed(cell: Vector2i)
signal overview_changed(state: Dictionary)

const BOARD_WORLD_SIZE := Vector2(1152.0, 3072.0)
const SCREEN_MARGIN: float = 24.0
const PAN_SPEED: float = 720.0
const PAN_ACCELERATION: float = 3600.0
const WHEEL_PAN_SPEED: float = 420.0
const CAMERA_SCROLL_DURATION: float = 0.32
const HOVER_RADIUS_RATIO: float = 0.46

@onready var _sub_viewport: SubViewport = $BoardSubViewport
@onready var _board_world: Node2D = $BoardSubViewport/BoardWorld
@onready var _camera: Camera2D = $BoardSubViewport/BoardWorld/BoardCamera2D
@onready var _screen_input_surface: Control = $ScreenInputSurface
@onready var _scroll_bar: VScrollBar = $VerticalScrollBar

var _fit_zoom: float = 1.0
var _zoom_multiplier: float = 1.0
var _focused_cell := Vector2i.ZERO
var _hovered_cell := Vector2i.ZERO
var _hover_pointer_local := Vector2(INF, INF)
var _camera_motion_tween: Tween
var _camera_target_y: float = BOARD_WORLD_SIZE.y * 0.5
var _keyboard_pan_velocity: float = 0.0


func _ready() -> void:
	resized.connect(_sync_layout)
	_board_world.point_activated.connect(_on_point_activated)
	_board_world.cancel_or_marker_requested.connect(_on_cancel_or_marker_requested)
	_board_world.zoom_requested.connect(_apply_zoom_step)
	_board_world.pan_requested.connect(_on_pan_requested)
	_screen_input_surface.gui_input.connect(_on_screen_input_surface_gui_input)
	_screen_input_surface.mouse_exited.connect(_clear_hover)
	_scroll_bar.value_changed.connect(_on_scroll_bar_value_changed)
	var world_input_surface := _board_world.get_node_or_null("InputSurface") as Control
	if world_input_surface != null:
		world_input_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camera.position_smoothing_enabled = false
	_sync_layout()


func _process(delta: float) -> void:
	var direction: Vector2 = Input.get_vector(
		&"board_pan_left", &"board_pan_right", &"board_pan_up", &"board_pan_down"
	)
	var zoom_y := maxf(_camera.zoom.y, 0.01)
	var target_velocity := direction.y * PAN_SPEED / zoom_y
	_keyboard_pan_velocity = move_toward(
		_keyboard_pan_velocity,
		target_velocity,
		PAN_ACCELERATION * delta / zoom_y
	)
	if is_zero_approx(_keyboard_pan_velocity):
		return
	_cancel_camera_motion()
	_apply_camera_y(_clamp_camera_y(_camera.position.y + _keyboard_pan_velocity * delta))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"board_zoom_in"):
		_apply_zoom_step(1.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"board_zoom_out"):
		_apply_zoom_step(-1.0)
		get_viewport().set_input_as_handled()


func toggle_presentation_side() -> void:
	var current_side: String = _board_world.get_display_side()
	set_presentation_side("black" if current_side == "red" else "red")


func set_presentation_side(side: String) -> void:
	_board_world.set_presentation_side(side)
	if BoardCoordinateMapper.is_authority_cell_valid(_focused_cell):
		focus_authority_cell(_focused_cell)
	else:
		reset_camera()


func get_presentation_side() -> String:
	return _board_world.get_display_side()


func render_player_view(view: Dictionary) -> void:
	_board_world.render_player_view(view)
	if BoardCoordinateMapper.is_authority_cell_valid(_focused_cell):
		focus_authority_cell(_focused_cell)
	else:
		reset_camera()


func set_marker(cell: Vector2i, marker_type: String) -> void:
	_board_world.set_marker(cell, marker_type)


func clear_marker(cell: Vector2i) -> void:
	_board_world.clear_marker(cell)


func has_marker(cell: Vector2i) -> bool:
	return _board_world.has_marker(cell)


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
		str(_board_world.get_display_side()),
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
	snapshot["camera_target_y"] = _camera_target_y
	snapshot["camera_motion_active"] = _camera_motion_tween != null \
		and _camera_motion_tween.is_valid() and _camera_motion_tween.is_running()
	snapshot["camera_scroll_duration"] = CAMERA_SCROLL_DURATION
	snapshot["hovered_cell"] = _hovered_cell
	snapshot["coordinate_text"] = "坐标：（%d, %d）" % [_hovered_cell.x, _hovered_cell.y] \
		if BoardCoordinateMapper.is_authority_cell_valid(_hovered_cell) else "坐标：—"
	snapshot["overview_state"] = get_overview_state()
	return snapshot


func get_overview_state() -> Dictionary:
	var zoom := Vector2(maxf(_camera.zoom.x, 0.01), maxf(_camera.zoom.y, 0.01))
	var visible_world_size := Vector2(size.x / zoom.x, size.y / zoom.y)
	var visible_world_position := _camera.position - visible_world_size * 0.5
	var normalized_position := Vector2(
		clampf(visible_world_position.x / BOARD_WORLD_SIZE.x, 0.0, 1.0),
		clampf(visible_world_position.y / BOARD_WORLD_SIZE.y, 0.0, 1.0)
	)
	var normalized_size := Vector2(
		clampf(visible_world_size.x / BOARD_WORLD_SIZE.x, 0.0, 1.0),
		clampf(visible_world_size.y / BOARD_WORLD_SIZE.y, 0.0, 1.0)
	)
	if normalized_position.x + normalized_size.x > 1.0:
		normalized_position.x = maxf(0.0, 1.0 - normalized_size.x)
	if normalized_position.y + normalized_size.y > 1.0:
		normalized_position.y = maxf(0.0, 1.0 - normalized_size.y)
	return {
		"display_side": _board_world.get_display_side(),
		"viewport_rect_normalized": Rect2(normalized_position, normalized_size),
		"camera_center_normalized": Vector2(
			clampf(_camera.position.x / BOARD_WORLD_SIZE.x, 0.0, 1.0),
			clampf(_camera.position.y / BOARD_WORLD_SIZE.y, 0.0, 1.0)
		),
	}


func navigate_to_overview_ratio(display_ratio: Vector2) -> void:
	_focused_cell = Vector2i.ZERO
	_animate_camera_y_to(
		clampf(display_ratio.y, 0.0, 1.0) * BOARD_WORLD_SIZE.y
	)


func get_container_position_for_authority_cell(cell: Vector2i) -> Vector2:
	if not BoardCoordinateMapper.is_authority_cell_valid(cell):
		return Vector2(INF, INF)
	var world_position := BoardCoordinateMapper.authority_to_world(
		cell, str(_board_world.get_display_side()), _board_world.get_cell_size()
	)
	var viewport_position := _board_world.get_global_transform_with_canvas() * world_position
	var viewport_size := Vector2(_sub_viewport.size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return viewport_position
	return viewport_position * size / viewport_size


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
		str(_board_world.get_display_side()),
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
	_sync_scroll_bar()


func _clamp_camera() -> void:
	_set_camera_y_immediate(_camera.position.y)


func _pan_camera(amount: float) -> void:
	if is_zero_approx(amount):
		return
	var start_y := _camera_target_y if _camera_motion_tween != null \
		and _camera_motion_tween.is_valid() else _camera.position.y
	_animate_camera_y_to(start_y + amount / maxf(_camera.zoom.y, 0.01))


func _on_pan_requested(amount: float) -> void:
	_pan_camera(amount * WHEEL_PAN_SPEED)


func _on_scroll_bar_value_changed(value: float) -> void:
	var visible_world_height: float = size.y / maxf(_camera.zoom.y, 0.01)
	var scrollable_height := maxf(0.0, BOARD_WORLD_SIZE.y - visible_world_height)
	if scrollable_height <= 0.0:
		return
	_animate_camera_y_to(visible_world_height * 0.5 + value * scrollable_height, 0.2)


func _sync_scroll_bar() -> void:
	if not is_instance_valid(_scroll_bar):
		return
	var visible_world_height: float = size.y / maxf(_camera.zoom.y, 0.01)
	var scrollable_height := maxf(0.0, BOARD_WORLD_SIZE.y - visible_world_height)
	_scroll_bar.visible = scrollable_height > 0.0
	if scrollable_height <= 0.0:
		_scroll_bar.set_value_no_signal(0.0)
		return
	var normalized := (_camera.position.y - visible_world_height * 0.5) / scrollable_height
	_scroll_bar.set_value_no_signal(clampf(normalized, 0.0, 1.0))


func _on_point_activated(cell: Vector2i) -> void:
	point_activated.emit(cell)


func _on_cancel_or_marker_requested(cell: Vector2i) -> void:
	cancel_or_marker_requested.emit(cell)


func _on_screen_input_surface_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_pointer_local = (event as InputEventMouseMotion).position
		_update_hover_from_container_position(_hover_pointer_local)
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if mouse_event.ctrl_pressed:
			_apply_zoom_step(1.0)
		else:
			_on_pan_requested(-maxf(mouse_event.factor, 1.0))
		_screen_input_surface.accept_event()
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if mouse_event.ctrl_pressed:
			_apply_zoom_step(-1.0)
		else:
			_on_pan_requested(maxf(mouse_event.factor, 1.0))
		_screen_input_surface.accept_event()
		return
	var cell := _authority_cell_at_container_position(mouse_event.position)
	if not BoardCoordinateMapper.is_authority_cell_valid(cell):
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		point_activated.emit(cell)
		_screen_input_surface.accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_or_marker_requested.emit(cell)
		_screen_input_surface.accept_event()


func _update_hover_from_container_position(local_position: Vector2) -> void:
	if not Rect2(Vector2.ZERO, size).has_point(local_position):
		_clear_hover()
		return
	var world_position := _container_to_world(local_position)
	if not is_finite(world_position.x) or not is_finite(world_position.y):
		_clear_hover()
		return
	var cell := BoardCoordinateMapper.world_to_authority(
		world_position, str(_board_world.get_display_side()), _board_world.get_cell_size()
	)
	if BoardCoordinateMapper.is_authority_cell_valid(cell):
		var point_position := BoardCoordinateMapper.authority_to_world(
			cell, str(_board_world.get_display_side()), _board_world.get_cell_size()
		)
		var hover_radius := minf(
			_board_world.get_cell_size().x, _board_world.get_cell_size().y
		) * HOVER_RADIUS_RATIO
		if world_position.distance_to(point_position) > hover_radius:
			cell = Vector2i.ZERO
	_set_hovered_cell(cell)


func _authority_cell_at_container_position(local_position: Vector2) -> Vector2i:
	var world_position := _container_to_world(local_position)
	if not is_finite(world_position.x) or not is_finite(world_position.y):
		return Vector2i.ZERO
	return BoardCoordinateMapper.world_to_authority(
		world_position, str(_board_world.get_display_side()), _board_world.get_cell_size()
	)


func _container_to_world(local_position: Vector2) -> Vector2:
	var viewport_size := Vector2(_sub_viewport.size)
	if size.x <= 0.0 or size.y <= 0.0 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(INF, INF)
	var viewport_position := local_position * viewport_size / size
	return _board_world.get_global_transform_with_canvas().affine_inverse() * viewport_position


func _set_hovered_cell(cell: Vector2i) -> void:
	if cell == _hovered_cell:
		return
	_hovered_cell = cell
	hovered_cell_changed.emit(cell)


func _clear_hover() -> void:
	_hover_pointer_local = Vector2(INF, INF)
	_set_hovered_cell(Vector2i.ZERO)


func _set_camera_y_immediate(value: float) -> void:
	_cancel_camera_motion()
	_camera_target_y = _clamp_camera_y(value)
	_apply_camera_y(_camera_target_y)


func _animate_camera_y_to(value: float, duration: float = CAMERA_SCROLL_DURATION) -> void:
	_keyboard_pan_velocity = 0.0
	var target_y := _clamp_camera_y(value)
	_cancel_camera_motion()
	_camera_target_y = target_y
	if is_equal_approx(_camera.position.y, target_y) or duration <= 0.0:
		_apply_camera_y(target_y)
		return
	var tween := create_tween()
	_camera_motion_tween = tween
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_apply_camera_y, _camera.position.y, target_y, duration)
	tween.finished.connect(func() -> void:
		if _camera_motion_tween == tween:
			_camera_motion_tween = null
			_apply_camera_y(_camera_target_y)
	)


func _cancel_camera_motion() -> void:
	if _camera_motion_tween != null and _camera_motion_tween.is_valid():
		_camera_motion_tween.kill()
	_camera_motion_tween = null
	_camera_target_y = _camera.position.y


func _clamp_camera_y(value: float) -> float:
	var visible_world_height: float = size.y / maxf(_camera.zoom.y, 0.01)
	if visible_world_height >= BOARD_WORLD_SIZE.y:
		return BOARD_WORLD_SIZE.y * 0.5
	return clampf(
		value,
		visible_world_height * 0.5,
		BOARD_WORLD_SIZE.y - visible_world_height * 0.5
	)


func _apply_camera_y(value: float) -> void:
	_camera.position = Vector2(BOARD_WORLD_SIZE.x * 0.5, _clamp_camera_y(value))
	_sync_scroll_bar()
	_emit_overview_changed()
	if is_finite(_hover_pointer_local.x) and is_finite(_hover_pointer_local.y):
		_update_hover_from_container_position(_hover_pointer_local)


func _emit_overview_changed() -> void:
	if is_node_ready():
		overview_changed.emit(get_overview_state())
