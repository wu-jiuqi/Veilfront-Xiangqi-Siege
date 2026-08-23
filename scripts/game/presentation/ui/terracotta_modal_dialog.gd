class_name TerracottaModalDialog
extends Control

signal confirmed
signal canceled
signal close_requested

@export var title: String = "" :
	set(value):
		title = value
		_sync_content()
@export_multiline var dialog_text: String = "" :
	set(value):
		dialog_text = value
		_sync_content()
@export var ok_button_text: String = "确定" :
	set(value):
		ok_button_text = value
		_sync_content()
@export var cancel_button_text: String = "取消" :
	set(value):
		cancel_button_text = value
		_sync_content()
@export var show_cancel_button: bool = true :
	set(value):
		show_cancel_button = value
		_sync_content()
@export var focus_cancel_by_default: bool = false
@export var exclusive: bool = true

@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel
@onready var _confirm_slot: Control = %ConfirmSlot
@onready var _cancel_slot: Control = %CancelSlot
@onready var _confirm_frame: TextureRect = %ConfirmFrame
@onready var _cancel_frame: TextureRect = %CancelFrame
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _close_button: Button = %CloseButton

var _previous_focus: Control


func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	visibility_changed.connect(_on_visibility_changed)
	_connect_button_visuals(_confirm_button, _confirm_frame)
	_connect_button_visuals(_cancel_button, _cancel_frame)
	_sync_content()
	set_process_unhandled_input(false)


func popup_centered() -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	_sync_content()
	show()
	move_to_front()
	set_process_unhandled_input(true)
	_focus_default_button.call_deferred()


func get_ok_button() -> Button:
	return _confirm_button


func get_cancel_button() -> Button:
	return _cancel_button


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if show_cancel_button:
		_on_cancel_pressed()
	else:
		_on_confirm_pressed()


func _sync_content() -> void:
	if not is_node_ready():
		return
	_title_label.text = title
	_body_label.text = dialog_text
	_confirm_button.text = ok_button_text
	_cancel_button.text = cancel_button_text
	_cancel_slot.visible = show_cancel_button


func _focus_default_button() -> void:
	if not visible:
		return
	if focus_cancel_by_default and show_cancel_button:
		_cancel_button.grab_focus()
	else:
		_confirm_button.grab_focus()


func _on_confirm_pressed() -> void:
	hide()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	hide()
	canceled.emit()


func _on_close_pressed() -> void:
	if not show_cancel_button:
		_on_confirm_pressed()
		return
	hide()
	close_requested.emit()


func _on_visibility_changed() -> void:
	set_process_unhandled_input(visible)
	if visible or not is_instance_valid(_previous_focus):
		return
	if _previous_focus.is_visible_in_tree() and _previous_focus.focus_mode != Control.FOCUS_NONE:
		_previous_focus.call_deferred(&"grab_focus")
	_previous_focus = null


func _connect_button_visuals(button: Button, frame: TextureRect) -> void:
	button.mouse_entered.connect(_refresh_button_visual.bind(button, frame))
	button.mouse_exited.connect(_refresh_button_visual.bind(button, frame))
	button.focus_entered.connect(_refresh_button_visual.bind(button, frame))
	button.focus_exited.connect(_refresh_button_visual.bind(button, frame))
	button.button_down.connect(_set_button_pressed.bind(frame))
	button.button_up.connect(_on_button_released.bind(button, frame))


func _refresh_button_visual(button: Button, frame: TextureRect) -> void:
	if button.has_focus() or button.is_hovered():
		frame.self_modulate = Color(1.16, 1.08, 0.82, 1.0)
	else:
		frame.self_modulate = Color.WHITE


func _set_button_pressed(frame: TextureRect) -> void:
	frame.self_modulate = Color(0.78, 0.75, 0.68, 1.0)


func _on_button_released(button: Button, frame: TextureRect) -> void:
	_refresh_button_visual(button, frame)
