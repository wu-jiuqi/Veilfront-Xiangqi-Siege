extends SceneTree

const START_SCREEN_SCENE := preload("res://scenes/game/frontend/start_screen.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var start_screen := START_SCREEN_SCENE.instantiate() as Control
	root.add_child(start_screen)
	current_scene = start_screen
	await process_frame
	_expect(start_screen != null, "start screen did not instantiate")
	if start_screen == null:
		_finish()
		return

	var overlay := start_screen.get_node("%MenuOverlay") as Control
	_expect(overlay != null, "inline menu overlay is missing")
	_expect(not overlay.visible, "menu must remain hidden before the gate sequence completes")
	var sequence := start_screen.get_node("%SequencePlayer") as AnimationPlayer
	_expect(sequence != null and sequence.has_animation(&"opening_sequence"), "opening sequence is missing")
	start_screen.request_entry()
	start_screen.request_entry()
	_expect(sequence.current_animation == &"opening_sequence", "entry must start the opening sequence once")
	start_screen.call("_on_sequence_animation_finished", &"opening_sequence")
	await process_frame
	_expect(overlay.call(&"is_active"), "opening completion must activate the inline menu")
	_expect(overlay.visible, "opening completion must reveal the inline menu")

	var buttons: Array[Button] = []
	for button_name: String in ["LanButton", "LevelModeButton", "CommunityButton", "SettingsButton", "QuitButton"]:
		var button := overlay.get_node("%%%s" % button_name) as Button
		buttons.append(button)
		_expect(button != null, "%s is missing" % button_name)
		if button == null:
			continue
		_expect(not button.get_signal_connection_list(&"pressed").is_empty(), "%s lost its action binding" % button_name)
		_expect(button.has_method("set_reduced_motion"), "%s must use the reusable motion button" % button_name)
		_expect(button.custom_minimum_size.y >= 44.0, "%s is below the interaction target" % button_name)
		_expect(button.get_theme_stylebox(&"normal") is StyleBoxFlat, "%s must use the unified scalable surface" % button_name)

	var intro := overlay.get_node("%MenuIntroPlayer") as AnimationPlayer
	_expect(intro.current_animation == &"menu_intro", "menu entrance animation did not start")
	intro.advance(1.0)
	await process_frame
	for button: Button in buttons:
		if button != null:
			_expect(not button.disabled, "%s stayed disabled after menu reveal" % button.name)
	_expect((overlay.get_node("%LanButton") as Button).has_focus(), "first menu action must receive keyboard focus")

	current_scene = null
	start_screen.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FRONTEND_INTRO_CONTRACT_PASS sequence_gate=ok unified_menu=ok focus=ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FRONTEND_INTRO_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)
