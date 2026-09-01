extends SceneTree

const PAUSE_MENU_SCENE: PackedScene = preload(
	"res://scenes/game/ui/tutorial_pause_menu.tscn"
)
const MATCH_HUD_SCENE: PackedScene = preload("res://scenes/game/ui/match_hud_v2.tscn")
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu: TutorialPauseMenu = PAUSE_MENU_SCENE.instantiate() as TutorialPauseMenu
	root.add_child(menu)
	await process_frame

	var continue_button: Button = menu.get_node("%ContinueButton") as Button
	var restart_button: Button = menu.get_node("%RestartChapterButton") as Button
	var codex_button: Button = menu.get_node("%CodexButton") as Button
	var exit_button: Button = menu.get_node("%ExitTutorialButton") as Button
	_expect(menu.process_mode == Node.PROCESS_MODE_ALWAYS, "pause menu must process while paused")
	_expect(not menu.visible and not menu.is_open(), "pause menu must start closed")
	for button: Button in [continue_button, restart_button, codex_button, exit_button]:
		_expect(button.focus_mode == Control.FOCUS_ALL, "%s must accept keyboard focus" % button.name)
		_expect(button.custom_minimum_size.y >= 44.0, "%s must keep a 44px target" % button.name)
		_expect(_is_scalable_stylebox(button.get_theme_stylebox("normal")), "%s must use a scalable theme surface" % button.name)
	_expect(
		menu.theme != null and menu.theme.resource_path.ends_with("veilfront_ui_theme_v2.tres"),
		"pause menu does not use the unified V2 theme"
	)
	_expect(
		continue_button.theme_type_variation == &"ConfirmButton",
		"continue action is not the unified confirm role"
	)
	_expect(
		exit_button.theme_type_variation == &"DangerButton",
		"exit action is not the unified danger role"
	)
	var scene_text := FileAccess.get_file_as_string("res://scenes/game/ui/tutorial_pause_menu.tscn")
	_expect(not scene_text.contains(".png"), "pause menu still uses layout-defining PNG assets")

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

	var emissions := {"restart": 0, "codex": 0, "exit": 0}
	menu.restart_requested.connect(func() -> void: emissions["restart"] += 1)
	menu.codex_requested.connect(func() -> void: emissions["codex"] += 1)
	menu.exit_requested.connect(func() -> void: emissions["exit"] += 1)
	menu.open_menu()
	codex_button.pressed.emit()
	_expect(int(emissions["codex"]) == 1, "codex button did not emit codex_requested")
	_expect(paused and menu.visible, "opening the codex must preserve pause menu state")
	menu.close_menu()
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
		print("TUTORIAL_PAUSE_MENU_CONTRACT_PASS buttons=4 codex=true")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_PAUSE_MENU_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _is_scalable_stylebox(style: StyleBox) -> bool:
	if style is StyleBoxFlat:
		return true
	if style is StyleBoxTexture:
		var textured := style as StyleBoxTexture
		return textured.texture != null \
			and textured.texture_margin_left > 0.0 \
			and textured.texture_margin_top > 0.0 \
			and textured.texture_margin_right > 0.0 \
			and textured.texture_margin_bottom > 0.0
	return false
