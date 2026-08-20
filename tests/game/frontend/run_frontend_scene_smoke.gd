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
	assert(start_root.get_node("%EnterPrompt").text == "点击任意位置进入")
	assert(start_root.get_node("%Background").texture.resource_path == "res://assets/art/ui/concepts/main_menu_background_v7_denoised.png")
	start_root.queue_free()
	await process_frame

	var main_root := main_scene.instantiate()
	root.add_child(main_root)
	await process_frame
	assert(main_root.get_node("%LanButton").text == "局域网联机对战")
	assert(main_root.get_node("%LevelModeButton").text == "关卡模式")
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
