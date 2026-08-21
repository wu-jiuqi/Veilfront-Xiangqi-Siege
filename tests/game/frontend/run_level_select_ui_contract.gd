extends SceneTree

const LEVEL_SELECT_SCENE := preload("res://scenes/game/frontend/level_select.tscn")


func _init() -> void:
	var level_select := LEVEL_SELECT_SCENE.instantiate() as Control
	root.add_child(level_select)
	await process_frame

	assert(level_select.get_node("CampaignBackground") is TextureRect)
	assert(level_select.get_node("%TutorialGrid").get_child_count() == 11)
	assert(level_select.get_node("%ChallengeGrid").get_child_count() == 3)
	assert(level_select.get_node("%CategoryTabs").tabs_visible == false)
	assert(level_select.get_node("%TutorialCategoryButton").button_pressed)
	assert(level_select.get_node("%DetailCode").text == "T0")
	assert(level_select.get_node("%EnterButton").text == "进入关卡")
	assert(level_select.get_node("%EnterButton").custom_minimum_size.y >= 44.0)

	var challenge_button := level_select.get_node("%ChallengeCategoryButton") as Button
	challenge_button.pressed.emit()
	await process_frame
	assert(level_select.get_node("%CategoryTabs").current_tab == 1)
	assert(level_select.get_node("%DetailCode").text == "C1")
	level_select.queue_free()
	await process_frame

	var expected_columns := {960: 2, 1280: 3, 1920: 4}
	for viewport_size: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		root.add_child(viewport)
		var responsive_level_select := LEVEL_SELECT_SCENE.instantiate() as Control
		viewport.add_child(responsive_level_select)
		await process_frame
		await process_frame
		assert(responsive_level_select.size.round() == Vector2(viewport_size), "level-select root must fill %s" % viewport_size)
		assert(responsive_level_select.get_node("%BackButton").size.y >= 44.0)
		assert(responsive_level_select.get_node("%EnterButton").size.y >= 44.0)
		assert(responsive_level_select.get_node("%TutorialGrid").columns == expected_columns[viewport_size.x])
		assert(responsive_level_select.get_node("%EnterButton").get_global_rect().end.x <= viewport_size.x)
		assert(responsive_level_select.get_node("%EnterButton").get_global_rect().end.y <= viewport_size.y)
		viewport.queue_free()
		await process_frame

	print("LEVEL_SELECT_UI_CONTRACT_PASS concept=campaign_map nodes=14 resolutions=3 raster_only=true")
	quit()
