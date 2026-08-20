extends SceneTree

const START_SCREEN_SCENE := preload("res://scenes/game/frontend/start_screen.tscn")
const MAIN_MENU_SCENE := preload("res://scenes/game/frontend/main_menu.tscn")


func _init() -> void:
	await _verify_start_sequence_gate()
	await _verify_menu_input_gate()
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
	sequence_player.advance(5.0)
	await process_frame
	assert(current_scene != start_screen, "cinematic completion must route away from the start screen")
	assert(current_scene.scene_file_path == "res://scenes/game/frontend/main_menu.tscn", "cinematic must route to the main menu")

	current_scene.queue_free()
	await process_frame


func _verify_menu_input_gate() -> void:
	var main_menu := MAIN_MENU_SCENE.instantiate() as Control
	var intro_animation := main_menu.get_node("IntroAnimation") as AnimationPlayer
	intro_animation.speed_scale = 0.0
	root.add_child(main_menu)
	await process_frame

	var lan_button := main_menu.get_node("SafeMargin/Center/MenuPanel/MenuMargin/MenuColumn/LanButton") as Button
	var level_button := main_menu.get_node("SafeMargin/Center/MenuPanel/MenuMargin/MenuColumn/LevelModeButton") as Button
	var quit_button := main_menu.get_node("SafeMargin/Center/MenuPanel/MenuMargin/MenuColumn/QuitButton") as Button
	assert(lan_button.disabled and level_button.disabled and quit_button.disabled, "menu buttons must stay disabled under the black intro overlay")

	intro_animation.speed_scale = 1.0
	intro_animation.advance(1.0)
	await process_frame
	assert(not lan_button.disabled and not level_button.disabled and not quit_button.disabled, "menu buttons must enable after fade-in")
	assert(not main_menu.get_node("FadeOverlay").visible, "fade overlay must hide after the intro animation")

	main_menu.queue_free()
	await process_frame
