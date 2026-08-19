extends Control

const LAN_SCENE := "res://scenes/prototype/network/lan_lobby.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/game/frontend/level_select.tscn"

@onready var _lan_button: Button = %LanButton
@onready var _level_mode_button: Button = %LevelModeButton
@onready var _quit_button: Button = %QuitButton
@onready var _quit_dialog: ConfirmationDialog = %QuitDialog
@onready var _version_label: Label = %VersionLabel

var _transitioning := false


func _ready() -> void:
	_lan_button.pressed.connect(func() -> void: _open_scene(LAN_SCENE))
	_level_mode_button.pressed.connect(func() -> void: _open_scene(LEVEL_SELECT_SCENE))
	_quit_button.pressed.connect(_quit_dialog.popup_centered)
	_quit_dialog.confirmed.connect(get_tree().quit)
	_version_label.text = "灰盒版本 · Godot 4.7.1 · Iteration 3"
	_lan_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not _quit_dialog.visible:
		_quit_dialog.popup_centered()
		get_viewport().set_input_as_handled()


func _open_scene(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_transitioning = false
		$FatalErrorDialog.dialog_text = "无法打开界面：%s" % path
		$FatalErrorDialog.popup_centered()

