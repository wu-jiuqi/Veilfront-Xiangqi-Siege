extends SceneTree

const PAUSE_MENU_SCENE: PackedScene = preload(
	"res://scenes/game/ui/tutorial_pause_menu.tscn"
)
const MATCH_HUD_SCENE: PackedScene = preload("res://scenes/game/ui/match_hud_v2.tscn")
const PANEL_TEXTURE_PATH: String = \
	"res://assets/art/ui/system_dialog/system_dialog_panel_v1.png"
const PRIMARY_TEXTURE_PATH: String = \
	"res://assets/art/ui/system_dialog/system_dialog_button_primary_v1.png"
const SECONDARY_TEXTURE_PATH: String = \
	"res://assets/art/ui/system_dialog/system_dialog_button_secondary_v1.png"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu: TutorialPauseMenu = PAUSE_MENU_SCENE.instantiate() as TutorialPauseMenu
	root.add_child(menu)
	await process_frame

	var continue_button: Button = menu.get_node("%ContinueButton") as Button
	var restart_button: Button = menu.get_node("%RestartChapterButton") as Button
	var exit_button: Button = menu.get_node("%ExitTutorialButton") as Button
	_expect(menu.process_mode == Node.PROCESS_MODE_ALWAYS, "pause menu must process while paused")
	_expect(not menu.visible and not menu.is_open(), "pause menu must start closed")
	for button: Button in [continue_button, restart_button, exit_button]:
		_expect(button.focus_mode == Control.FOCUS_ALL, "%s must accept keyboard focus" % button.name)
		_expect(button.flat, "%s must leave rendering to the preset texture frame" % button.name)
	_expect(
		(menu.get_node("%PanelArt") as TextureRect).texture.resource_path == PANEL_TEXTURE_PATH,
		"pause menu does not reuse the online system dialog panel"
	)
	_expect(
		(menu.get_node("DialogCenter/DialogCanvas/ActionColumn/ContinueSlot/ContinueFrame") as TextureRect).texture.resource_path == PRIMARY_TEXTURE_PATH,
		"continue action does not reuse the system dialog primary button"
	)
	for frame_path: String in [
		"DialogCenter/DialogCanvas/ActionColumn/RestartSlot/RestartFrame",
		"DialogCenter/DialogCanvas/ActionColumn/ExitSlot/ExitFrame",
	]:
		_expect(
			(menu.get_node(frame_path) as TextureRect).texture.resource_path == SECONDARY_TEXTURE_PATH,
			"%s does not reuse the system dialog secondary button" % frame_path
		)
	_expect(
		not FileAccess.get_file_as_string("res://scenes/game/ui/tutorial_pause_menu.tscn").contains(
			"terracotta_pause_menu/tutorial_pause_button_v1.png"
		),
		"pause menu still references the retired standalone theme button asset"
	)

	var escape_event := InputEventAction.new()
	escape_event.action = &"ui_cancel"
	escape_event.pressed = true
	menu._unhandled_input(escape_event)
	_expect(menu.visible and menu.is_open(), "Escape did not open the pause menu")
	_expect(paused, "opening the pause menu did not pause the scene tree")
	_expect(menu.get_viewport().gui_get_focus_owner() == continue_button, "continue button did not receive focus")

	menu._unhandled_input(escape_event)
	_expect(not menu.visible and not menu.is_open(), "second Escape did not close the pause menu")
	_expect(not paused, "closing the pause menu did not resume the scene tree")

	var emissions := {"restart": 0, "exit": 0}
	menu.restart_requested.connect(func() -> void: emissions["restart"] += 1)
	menu.exit_requested.connect(func() -> void: emissions["exit"] += 1)
	menu.open_menu()
	restart_button.pressed.emit()
	_expect(int(emissions["restart"]) == 1, "restart button did not emit restart_requested")
	_expect(not paused and not menu.visible, "restart button did not close and resume")
	menu.open_menu()
	exit_button.pressed.emit()
	_expect(int(emissions["exit"]) == 1, "exit button did not emit exit_requested")
	_expect(not paused and not menu.visible, "exit button did not close and resume")

	var match_hud: Control = MATCH_HUD_SCENE.instantiate() as Control
	_expect(
		match_hud.get_node_or_null("Minimap/MinimapExpandButton") == null,
		"minimap expand button must be removed"
	)
	match_hud.free()
	menu.free()

	if _failures.is_empty():
		print("TUTORIAL_PAUSE_MENU_CONTRACT_PASS buttons=3")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_PAUSE_MENU_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
