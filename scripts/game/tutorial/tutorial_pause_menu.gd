class_name TutorialPauseMenu
extends Control

signal restart_requested()
signal exit_requested()

@onready var _continue_button: Button = %ContinueButton

var _opened: bool = false
var _tree_was_paused: bool = false


func _ready() -> void:
	visible = false


func _exit_tree() -> void:
	if _opened and not _tree_was_paused:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _opened:
		close_menu()
	else:
		open_menu()
	get_viewport().set_input_as_handled()


func open_menu() -> void:
	if _opened:
		return
	_tree_was_paused = get_tree().paused
	_opened = true
	visible = true
	get_tree().paused = true
	_continue_button.grab_focus()


func close_menu() -> void:
	if not _opened:
		return
	_opened = false
	visible = false
	get_tree().paused = _tree_was_paused


func is_open() -> bool:
	return _opened


func _on_continue_pressed() -> void:
	close_menu()


func _on_restart_pressed() -> void:
	close_menu()
	restart_requested.emit()


func _on_exit_pressed() -> void:
	close_menu()
	exit_requested.emit()
