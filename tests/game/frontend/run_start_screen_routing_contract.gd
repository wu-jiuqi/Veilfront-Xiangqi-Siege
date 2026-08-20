extends SceneTree

const START_SCREEN_SCENE := preload("res://scenes/game/frontend/start_screen.tscn")
const SEQUENCE_COMPLETION_TIME := 5.0


func _init() -> void:
	var start_screen := _add_start_screen()
	await process_frame

	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	start_screen._gui_input(click_event)
	start_screen._gui_input(click_event)
	(start_screen.get_node("SequencePlayer") as AnimationPlayer).advance(SEQUENCE_COMPLETION_TIME)
	await process_frame
	_assert_inline_menu(start_screen, "left_click")

	current_scene.queue_free()
	await process_frame
	start_screen = _add_start_screen()
	await process_frame
	var touch_event := InputEventScreenTouch.new()
	touch_event.pressed = true
	start_screen._gui_input(touch_event)
	(start_screen.get_node("SequencePlayer") as AnimationPlayer).advance(SEQUENCE_COMPLETION_TIME)
	await process_frame
	_assert_inline_menu(start_screen, "touch")

	current_scene.queue_free()
	await process_frame
	start_screen = _add_start_screen()
	await process_frame
	var accept_event := InputEventAction.new()
	accept_event.action = &"ui_accept"
	accept_event.pressed = true
	start_screen._unhandled_input(accept_event)
	(start_screen.get_node("SequencePlayer") as AnimationPlayer).advance(SEQUENCE_COMPLETION_TIME)
	await process_frame
	_assert_inline_menu(start_screen, "ui_accept")

	print("START_SCREEN_ROUTING_CONTRACT_PASS inputs=left_click,touch,ui_accept inline_menu=ok duplicate_guard=ok")
	quit()


func _add_start_screen() -> Control:
	var start_screen := START_SCREEN_SCENE.instantiate() as Control
	root.add_child(start_screen)
	current_scene = start_screen
	return start_screen


func _assert_inline_menu(start_screen: Control, input_name: String) -> void:
	assert(current_scene == start_screen, "%s must keep the start scene as the menu background" % input_name)
	var menu_overlay := start_screen.get_node("MenuOverlay")
	assert(menu_overlay.visible, "%s must reveal the inline menu" % input_name)
	assert(menu_overlay.call(&"is_active"), "%s must activate the inline menu" % input_name)
