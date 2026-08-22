extends Control

const FrontendRoutes = preload("res://scripts/integration/frontend_routes.gd")

@onready var _settings_button: Button = %SettingsButton
@onready var _lan_button: Button = %LanButton
@onready var _level_mode_button: Button = %LevelModeButton
@onready var _community_button: Button = %CommunityButton
@onready var _quit_button: Button = %QuitButton
@onready var _version_label: Label = %VersionLabel
@onready var _intro_player: AnimationPlayer = %MenuIntroPlayer
@onready var _notice_dialog: AcceptDialog = %NoticeDialog
@onready var _quit_dialog: ConfirmationDialog = %QuitDialog
@onready var _fatal_error_dialog: AcceptDialog = %FatalErrorDialog

var _active := false
var _transitioning := false


func _ready() -> void:
	visible = false
	_settings_button.pressed.connect(
		func() -> void:
			_open_scene(FrontendRoutes.settings_scene(), "正在展开军帐设置…")
	)
	_lan_button.pressed.connect(
		func() -> void:
			_open_scene(FrontendRoutes.lan_lobby_scene(), "正在联络同袍营帐…")
	)
	_level_mode_button.pressed.connect(
		func() -> void:
			_open_scene(FrontendRoutes.level_select_scene(), "正在铺开九路战图…")
	)
	_community_button.pressed.connect(
		func() -> void: _show_notice("社群入口尚未配置。")
	)
	_quit_button.pressed.connect(_quit_dialog.popup_centered)
	_quit_dialog.confirmed.connect(get_tree().quit)
	_intro_player.animation_finished.connect(_on_intro_animation_finished)
	_version_label.text = "Godot 4.7.1 · Iteration 3"
	_set_menu_enabled(false)


func reveal_menu() -> void:
	if _active:
		return
	_active = true
	visible = true
	_intro_player.play(&"menu_intro")


func reveal_menu_immediately() -> void:
	_active = true
	_transitioning = false
	visible = true
	_intro_player.play(&"menu_intro")
	_intro_player.seek(_intro_player.current_animation_length, true)
	_set_menu_enabled(true)
	_lan_button.grab_focus()


func is_active() -> bool:
	return _active


func _on_intro_animation_finished(animation_name: StringName) -> void:
	if animation_name != &"menu_intro":
		return
	_set_menu_enabled(true)
	_lan_button.grab_focus()


func _set_menu_enabled(enabled: bool) -> void:
	_settings_button.disabled = not enabled
	_lan_button.disabled = not enabled
	_level_mode_button.disabled = not enabled
	_community_button.disabled = not enabled
	_quit_button.disabled = not enabled


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed(&"ui_cancel") and not _quit_dialog.visible:
		_quit_dialog.popup_centered()
		get_viewport().set_input_as_handled()


func _show_notice(message: String) -> void:
	_notice_dialog.dialog_text = message
	_notice_dialog.popup_centered()


func _open_scene(path: String, status: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	var transition := FrontendRoutes.transition_service(get_tree())
	if transition != null:
		transition.connect(
			&"transition_cancelled",
			_on_transition_cancelled,
			CONNECT_ONE_SHOT
		)
	var error := FrontendRoutes.navigate(get_tree(), path, status)
	if error != OK:
		if (
			transition != null
			and transition.is_connected(&"transition_cancelled", _on_transition_cancelled)
		):
			transition.disconnect(&"transition_cancelled", _on_transition_cancelled)
		_transitioning = false
		_fatal_error_dialog.dialog_text = "无法打开界面：%s" % path
		_fatal_error_dialog.popup_centered()


func _on_transition_cancelled(_scene_path: String) -> void:
	_transitioning = false
