extends Node3D

const PRESET_RED: StringName = &"red"
const PRESET_OVERVIEW: StringName = &"overview"
const PRESET_BLACK: StringName = &"black"

@export_node_path("Camera3D") var camera_path: NodePath = NodePath("PitchPivot/Camera3D")
@export var transition_seconds: float = 0.35
@export var red_position: Vector3 = Vector3(0.0, 18.0, 24.60363)
@export var overview_position: Vector3 = Vector3(0.0, 48.0, 33.607735)
@export var black_position: Vector3 = Vector3(0.0, 18.0, 0.60363)
@export_category("棋盘导航")
@export var pan_speed: float = 8.0
@export var pan_bounds_min: Vector2 = Vector2(-5.7, -14.7)
@export var pan_bounds_max: Vector2 = Vector2(5.7, 14.7)
@export var pan_left_action: StringName = &"board_pan_left"
@export var pan_right_action: StringName = &"board_pan_right"
@export var pan_forward_action: StringName = &"board_pan_up"
@export var pan_back_action: StringName = &"board_pan_down"
@export_category("中键旋转")
@export var orbit_sensitivity_degrees: float = 0.15
@export_range(-89.0, -1.0, 0.5, "degrees") var min_pitch_degrees: float = -80.0
@export_range(-89.0, -1.0, 0.5, "degrees") var max_pitch_degrees: float = -35.0
@export_range(-180.0, 0.0, 0.5, "degrees") var min_yaw_degrees: float = -75.0
@export_range(0.0, 180.0, 0.5, "degrees") var max_yaw_degrees: float = 75.0

@onready var _camera: Camera3D = get_node(camera_path) as Camera3D
var _transition: Tween
var _orbit_dragging: bool = false


func _ready() -> void:
	_apply_rotation_limits()
	_clamp_to_board()


func _physics_process(delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		pan_left_action,
		pan_right_action,
		pan_forward_action,
		pan_back_action
	)
	apply_pan_input(input_direction, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_orbit_dragging = event.pressed
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _orbit_dragging:
		apply_orbit_delta(event.relative)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_orbit_dragging = false


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_HOME, KEY_1:
			show_preset(PRESET_RED)
		KEY_SPACE, KEY_2:
			show_preset(PRESET_OVERVIEW)
		KEY_END, KEY_3:
			show_preset(PRESET_BLACK)


func show_preset(preset: StringName, immediate: bool = false) -> void:
	var target: Vector3 = _position_for_preset(preset)
	if _transition != null and _transition.is_valid():
		_transition.kill()
	if immediate:
		_camera.position = target
		return
	_transition = create_tween()
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(_camera, "position", target, transition_seconds)


func apply_orbit_delta(mouse_delta: Vector2) -> void:
	var camera_rotation: Vector3 = _camera.rotation_degrees
	camera_rotation.x = clampf(
		camera_rotation.x - mouse_delta.y * orbit_sensitivity_degrees,
		min_pitch_degrees,
		max_pitch_degrees
	)
	camera_rotation.y = 0.0
	camera_rotation.z = 0.0
	_camera.rotation_degrees = camera_rotation
	var rig_rotation: Vector3 = rotation_degrees
	rig_rotation.y = clampf(
		rig_rotation.y - mouse_delta.x * orbit_sensitivity_degrees,
		min_yaw_degrees,
		max_yaw_degrees
	)
	rig_rotation.x = 0.0
	rig_rotation.z = 0.0
	rotation_degrees = rig_rotation


func apply_pan_input(input_direction: Vector2, delta: float) -> void:
	if input_direction.is_zero_approx() or delta <= 0.0:
		return
	var planar_input: Vector2 = input_direction.limit_length(1.0)
	var camera_right: Vector3 = _camera.global_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var camera_forward: Vector3 = -_camera.global_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var movement: Vector3 = camera_right * planar_input.x + camera_forward * -planar_input.y
	if not movement.is_zero_approx():
		global_position += movement.normalized() * pan_speed * delta
		_clamp_to_board()


func is_orbit_dragging() -> bool:
	return _orbit_dragging


func _apply_rotation_limits() -> void:
	var camera_rotation: Vector3 = _camera.rotation_degrees
	camera_rotation.x = clampf(camera_rotation.x, min_pitch_degrees, max_pitch_degrees)
	camera_rotation.y = 0.0
	camera_rotation.z = 0.0
	_camera.rotation_degrees = camera_rotation
	var rig_rotation: Vector3 = rotation_degrees
	rig_rotation.x = 0.0
	rig_rotation.y = clampf(rig_rotation.y, min_yaw_degrees, max_yaw_degrees)
	rig_rotation.z = 0.0
	rotation_degrees = rig_rotation


func _clamp_to_board() -> void:
	global_position = Vector3(
		clampf(global_position.x, pan_bounds_min.x, pan_bounds_max.x),
		global_position.y,
		clampf(global_position.z, pan_bounds_min.y, pan_bounds_max.y)
	)


func _position_for_preset(preset: StringName) -> Vector3:
	match preset:
		PRESET_RED:
			return red_position
		PRESET_BLACK:
			return black_position
		_:
			return overview_position
