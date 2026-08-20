extends Node3D

const PRESET_RED := "red"
const PRESET_OVERVIEW := "overview"
const PRESET_BLACK := "black"

@export_node_path("Camera3D") var camera_path := NodePath("PitchPivot/Camera3D")
@export var transition_seconds := 0.35
@export var red_position := Vector3(0.0, 18.0, 24.60363)
@export var overview_position := Vector3(0.0, 48.0, 33.607735)
@export var black_position := Vector3(0.0, 18.0, 0.60363)

@onready var _camera := get_node(camera_path) as Camera3D
var _transition: Tween


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


func show_preset(preset: StringName, immediate := false) -> void:
	var target := _position_for_preset(preset)
	if _transition != null and _transition.is_valid():
		_transition.kill()
	if immediate:
		_camera.position = target
		return
	_transition = create_tween()
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(_camera, "position", target, transition_seconds)


func _position_for_preset(preset: StringName) -> Vector3:
	match preset:
		PRESET_RED:
			return red_position
		PRESET_BLACK:
			return black_position
		_:
			return overview_position
