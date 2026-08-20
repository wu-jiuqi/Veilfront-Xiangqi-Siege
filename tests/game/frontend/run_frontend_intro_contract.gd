extends SceneTree

const START_SCREEN_SCENE := preload("res://scenes/game/frontend/start_screen.tscn")


func _init() -> void:
	await _verify_start_sequence_gate()
	await _verify_inline_menu_input_gate()
	print("FRONTEND_INTRO_CONTRACT_PASS sequence_gate=ok menu_input_gate=ok")
	quit()


func _verify_start_sequence_gate() -> void:
	var start_screen := START_SCREEN_SCENE.instantiate() as Control
	var sequence_player := start_screen.get_node("SequencePlayer") as AnimationPlayer
	sequence_player.speed_scale = 0.0
	root.add_child(start_screen)
	current_scene = start_screen
	await process_frame

	start_screen.request_entry()
	start_screen.request_entry()
	assert(sequence_player.current_animation == &"opening_sequence", "entry must start the cinematic sequence")
	assert(current_scene == start_screen, "scene routing must wait until the cinematic finishes")

	sequence_player.speed_scale = 1.0
	sequence_player.advance(5.2)
	await process_frame
	assert(current_scene == start_screen, "cinematic completion must keep the start scene as the menu background")
	var menu_overlay := start_screen.get_node("MenuOverlay")
	assert(menu_overlay.call(&"is_active"), "cinematic completion must activate the inline menu")
	assert(is_equal_approx((start_screen.get_node("Stage/SoldierLayer/IdleSoldiers") as TextureRect).modulate.a, 1.0), "soldiers must return to their standing pose")
	assert(is_zero_approx((start_screen.get_node("Stage/SoldierLayer/PushSoldiers") as TextureRect).modulate.a), "pushing pose must be hidden after the doors open")

	current_scene.queue_free()
	await process_frame


func _verify_inline_menu_input_gate() -> void:
	var start_screen := START_SCREEN_SCENE.instantiate() as Control
	root.add_child(start_screen)
	await process_frame

	var menu_overlay := start_screen.get_node("MenuOverlay")
	var intro_animation := menu_overlay.get_node("MenuIntroPlayer") as AnimationPlayer
	var lan_button := menu_overlay.get_node("UiRoot/MenuPanel/LanButton") as Button
	var level_button := menu_overlay.get_node("UiRoot/MenuPanel/LevelModeButton") as Button
	var community_button := menu_overlay.get_node("UiRoot/MenuPanel/CommunityButton") as Button
	var quit_button := menu_overlay.get_node("UiRoot/MenuPanel/QuitButton") as Button
	assert(not lan_button.get_signal_connection_list(&"pressed").is_empty(), "LAN button must keep its previous routing logic")
	assert(not level_button.get_signal_connection_list(&"pressed").is_empty(), "level button must keep its previous routing logic")
	assert(not community_button.get_signal_connection_list(&"pressed").is_empty(), "community button must provide a configured-state notice")
	assert(not quit_button.get_signal_connection_list(&"pressed").is_empty(), "quit button must keep its confirmation logic")
	assert(lan_button.disabled and level_button.disabled and community_button.disabled and quit_button.disabled, "menu buttons must stay disabled before reveal")

	menu_overlay.call(&"reveal_menu")
	intro_animation.advance(1.0)
	await process_frame
	assert(not lan_button.disabled and not level_button.disabled and not community_button.disabled and not quit_button.disabled, "menu buttons must enable after fade-in")
	assert(menu_overlay.visible, "inline menu must remain visible after fade-in")

	start_screen.queue_free()
	await process_frame
