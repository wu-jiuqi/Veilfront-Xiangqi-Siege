extends Control

const FrontendRoutes = preload("res://scripts/integration/frontend_routes.gd")
const SettingsManagerScript = preload("res://scripts/game/settings/settings_manager.gd")

@onready var _menu_overlay: Control = %MenuOverlay
@onready var _prompt_animation: AnimationPlayer = %PromptAnimation
@onready var _sequence_player: AnimationPlayer = %SequencePlayer
@onready var _frontend_audio: FrontendAudioFeedback = %FrontendAudioFeedback

var _transitioning := false
var _opening_audio_enabled := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sequence_player.animation_finished.connect(_on_sequence_animation_finished)
	var settings_manager := get_node_or_null("/root/SettingsManager") as SettingsManagerScript
	var skip_opening := false
	if settings_manager != null:
		skip_opening = (
			settings_manager.should_skip_opening()
			or settings_manager.is_reduced_motion_enabled()
		)
	if (
		FrontendRoutes.consume_start_menu_ready()
		or skip_opening
	):
		_enter_menu_ready_immediately()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			request_entry()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			accept_event()
			request_entry()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		request_entry()


func request_entry() -> void:
	if _transitioning:
		return

	_transitioning = true
	_opening_audio_enabled = true
	_prompt_animation.stop()
	_frontend_audio.play_cue("sfx.ui.confirm")
	_sequence_player.play(&"opening_sequence")


func _on_sequence_animation_finished(animation_name: StringName) -> void:
	if animation_name != &"opening_sequence":
		return
	_menu_overlay.call(&"reveal_menu")


func _enter_menu_ready_immediately() -> void:
	_transitioning = true
	_opening_audio_enabled = false
	_prompt_animation.stop()
	_sequence_player.play(&"opening_sequence")
	_sequence_player.seek(_sequence_player.current_animation_length, true)
	_menu_overlay.call(&"reveal_menu_immediately")


func _play_opening_cue(cue_key: String) -> void:
	if _opening_audio_enabled:
		_frontend_audio.play_cue(cue_key)
