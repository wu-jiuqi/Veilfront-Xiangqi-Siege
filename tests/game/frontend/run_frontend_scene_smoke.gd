extends SceneTree

const CATALOG := preload("res://resources/game/levels/level_catalog.tres")


func _init() -> void:
	var start_scene := load("res://scenes/game/frontend/start_screen.tscn") as PackedScene
	var main_scene := load("res://scenes/game/frontend/main_menu.tscn") as PackedScene
	var level_scene := load("res://scenes/game/frontend/level_select.tscn") as PackedScene
	assert(start_scene != null, "start screen scene must load")
	assert(main_scene != null, "main menu scene must load")
	assert(level_scene != null, "level select scene must load")
	assert(CATALOG.levels.size() == 14, "catalog must contain T0-T10 and C1-C3")
	assert(CATALOG.find_level("T0").available, "T0 must be available")
	assert(CATALOG.find_level("T1").unlock_after == "T0", "tutorial unlock chain must start at T0")
	assert(CATALOG.find_level("C1").category == "challenge", "C1 must be a challenge")

	var start_root := start_scene.instantiate()
	root.add_child(start_root)
	await process_frame
	var enter_prompt := start_root.get_node("%EnterPrompt") as Label
	var prompt_animation := start_root.get_node("%PromptAnimation") as AnimationPlayer
	var sequence_player := start_root.get_node("%SequencePlayer") as AnimationPlayer
	assert(enter_prompt.text == "点击任意位置继续")
	assert(start_root.get_node("Stage/Environment").texture.resource_path == "res://assets/art/ui/start_sequence/gate_environment_open_v1.png")
	assert(sequence_player.has_animation(&"opening_sequence"))
	assert(is_equal_approx(sequence_player.get_animation(&"opening_sequence").length, 6.4))
	assert(start_root.get_node("Stage/DoorLayer/LeftDoor").texture.resource_path == "res://assets/art/ui/start_sequence/gate_left_door_v2.png")
	assert(start_root.get_node("Stage/DoorLayer/RightDoor").texture.resource_path == "res://assets/art/ui/start_sequence/gate_right_door_v2.png")
	var menu_overlay := start_root.get_node("MenuOverlay")
	assert(menu_overlay.get_node("UiRoot/VerticalLogo").texture.resource_path == "res://assets/art/ui/start_sequence/veilfront_logo_vertical_v2.png")
	assert(menu_overlay.get_node("UiRoot/GameSubtitle").texture.resource_path == "res://assets/art/ui/start_sequence/veilfront_subtitle_horizontal_v1.png")
	assert(menu_overlay.get_node("UiRoot/MenuPanel/LanButton").text == "联机对战")
	assert(menu_overlay.get_node("UiRoot/MenuPanel/LevelModeButton").text == "关卡模式")
	assert(menu_overlay.get_node("UiRoot/MenuPanel/CommunityButton").text == "社群")
	assert(menu_overlay.get_node("UiRoot/MenuPanel/QuitButton").text == "退出游戏")
	var fog_shader := load("res://assets/shaders/ui/gate_fog_curtain.gdshader") as Shader
	assert(fog_shader.code.contains("random_gradient"), "fog must use smooth gradient noise instead of moving square cells")
	assert(fog_shader.code.contains("vec2 warp"), "fog must use a domain-warped irregular flow field")
	assert(fog_shader.code.contains("density_boost"), "fog must expose a persistent density control")
	var prompt_font := enter_prompt.get_theme_font(&"font") as FontVariation
	assert(prompt_font.resource_path == "res://resources/game/ui/start_prompt_font.tres")
	assert(prompt_font.base_font.resource_path == "res://assets/fonts/ramega_zhang_qingping/ramega_zhang_qingping_xingshu.ttf")
	for character: String in enter_prompt.text:
		assert(prompt_font.has_char(character.unicode_at(0)), "start prompt font must contain character: %s" % character)
	assert(enter_prompt.get_theme_font_size(&"font_size") == 32)
	var prompt_color := enter_prompt.get_theme_color(&"font_color")
	assert(prompt_color.r > prompt_color.g and prompt_color.g > prompt_color.b, "start prompt must use a pale gold color")
	var blink_animation := prompt_animation.get_animation(&"prompt_blink")
	assert(blink_animation.loop_mode == Animation.LOOP_LINEAR)
	assert(is_equal_approx(blink_animation.length, 1.8))
	prompt_animation.pause()
	prompt_animation.seek(0.0, true)
	var bright_alpha := enter_prompt.modulate.a
	prompt_animation.seek(0.9, true)
	assert(enter_prompt.modulate.a < bright_alpha, "start prompt animation must blink by reducing alpha")
	start_root.queue_free()
	await process_frame

	var main_root := main_scene.instantiate()
	root.add_child(main_root)
	await process_frame
	assert(main_root.get_node("%LanButton").text == "局域网联机对战")
	main_root.queue_free()
	await process_frame

	var level_root := level_scene.instantiate()
	root.add_child(level_root)
	await process_frame
	assert(level_root.get_node("%TutorialGrid").get_child_count() == 11)
	assert(level_root.get_node("%ChallengeGrid").get_child_count() == 3)
	for card: Control in level_root.get_node("%TutorialGrid").get_children():
		assert(not card.get_node("CardMargin/CardColumn/PlayButton").disabled, "tutorial test card must be open")
	for card: Control in level_root.get_node("%ChallengeGrid").get_children():
		assert(not card.get_node("CardMargin/CardColumn/PlayButton").disabled, "challenge test card must be open")
	assert(level_root.get_node("%BackButton").focus_mode != Control.FOCUS_NONE)
	print("FRONTEND_SCENE_SMOKE_PASS catalog=14 tutorial=11 challenge=3")
	quit()
