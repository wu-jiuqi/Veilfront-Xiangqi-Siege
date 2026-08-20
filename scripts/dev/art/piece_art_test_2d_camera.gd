extends Node2D

const PRESET_RED: StringName = &"red"
const PRESET_OVERVIEW: StringName = &"overview"
const PRESET_BLACK: StringName = &"black"

@onready var _camera: Camera2D = $PreviewCamera2D


func _ready() -> void:
	show_preset(PRESET_OVERVIEW, true)


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
	var target_position := Vector2(576.0, 1536.0)
	var target_zoom := Vector2(0.32, 0.32)
	match preset:
		PRESET_RED:
			target_position = Vector2(576.0, 2590.0)
			target_zoom = Vector2(0.82, 0.82)
		PRESET_BLACK:
			target_position = Vector2(576.0, 482.0)
			target_zoom = Vector2(0.82, 0.82)
	_camera.make_current()
	if immediate:
		_camera.position = target_position
		_camera.zoom = target_zoom
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "position", target_position, 0.3)
	tween.tween_property(_camera, "zoom", target_zoom, 0.3)
