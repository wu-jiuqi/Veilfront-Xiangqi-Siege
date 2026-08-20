extends Control

@export var main_menu_scene: PackedScene

@onready var _error_dialog: AcceptDialog = %ErrorDialog
@onready var _prompt_animation: AnimationPlayer = %PromptAnimation
@onready var _sequence_player: AnimationPlayer = %SequencePlayer

var _transitioning := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sequence_player.animation_finished.connect(_on_sequence_animation_finished)


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
	if main_menu_scene == null:
		_show_routing_error("未配置游戏菜单场景。")
		return

	_transitioning = true
	_prompt_animation.stop()
	_sequence_player.play(&"opening_sequence")


func _on_sequence_animation_finished(animation_name: StringName) -> void:
	if animation_name != &"opening_sequence":
		return
	_open_main_menu()


func _open_main_menu() -> void:
	var error := get_tree().change_scene_to_packed(main_menu_scene)
	if error != OK:
		_transitioning = false
		_show_routing_error("无法打开游戏菜单，错误码：%d" % error)


func _show_routing_error(message: String) -> void:
	_error_dialog.dialog_text = message
	_error_dialog.popup_centered()
