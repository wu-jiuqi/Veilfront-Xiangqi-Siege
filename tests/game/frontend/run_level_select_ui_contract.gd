extends SceneTree

const LEVEL_SELECT_SCENE := preload("res://scenes/game/frontend/level_select.tscn")


func _init() -> void:
	var level_select := LEVEL_SELECT_SCENE.instantiate() as Control
	root.add_child(level_select)
	await process_frame

	var scene_text := FileAccess.get_file_as_string("res://scenes/game/frontend/level_select.tscn")
	var card_text := FileAccess.get_file_as_string("res://scenes/game/frontend/level_card.tscn")
	assert(not scene_text.contains("terracotta_hud_v2"))
	assert(scene_text.contains("ui_theme_binder"))
	assert(not scene_text.contains("level_campaign_map_background_v1"))
	assert(not card_text.contains("level_node_states_v1"))
	assert(level_select.get_node("DesignCanvas/CampaignBackground") is TextureRect)
	assert(level_select.get_node("DesignCanvas/CampaignBackground").texture.resource_path == "res://assets/art/ui/level_select/level_select_empty_background_v2.png")
	assert(level_select.get_node("%TutorialGrid").get_child_count() == 11)
	assert(level_select.get_node("%ChallengeGrid").get_child_count() == 3)
	assert(level_select.get_node("%CategoryTabs").tabs_visible == false)
	assert(level_select.get_node("%TutorialCategoryButton").button_pressed)
	assert(level_select.get_node("%DetailCode").text == "T0")
	assert(level_select.get_node("%EnterButton").text == "进入关卡")
	assert(level_select.get_node("%EnterButton").size.y >= 44.0)
	assert(level_select.get_node("%TutorialGrid").get_child(0).position == Vector2(102, 24))
	assert(level_select.get_node("%TutorialGrid").get_child(10).position == Vector2(445, 397))
	assert(level_select.get_node("%TutorialGrid").get_child(0).get_node("%SelectedState").texture.resource_path == "res://assets/art/ui/level_select/components/node_selected_v2.png")

	var challenge_button := level_select.get_node("%ChallengeCategoryButton") as Button
	challenge_button.pressed.emit()
	await process_frame
	assert(level_select.get_node("%CategoryTabs").current_tab == 1)
	assert(level_select.get_node("%DetailCode").text == "C1")
	level_select.queue_free()
	await process_frame

	for viewport_size: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		root.add_child(viewport)
		var responsive_level_select := LEVEL_SELECT_SCENE.instantiate() as Control
		viewport.add_child(responsive_level_select)
		await process_frame
		await process_frame
		assert(responsive_level_select.size.round() == Vector2(viewport_size), "level-select root must fill %s" % viewport_size)
		var expected_scale := minf(float(viewport_size.x) / 1280.0, float(viewport_size.y) / 720.0)
		assert(is_equal_approx(responsive_level_select.get_node("%DesignCanvas").scale.x, expected_scale))
		assert(is_equal_approx(responsive_level_select.get_node("%DesignCanvas").scale.y, expected_scale))
		assert(responsive_level_select.get_node("%EnterButton").get_global_rect().end.x <= viewport_size.x)
		assert(responsive_level_select.get_node("%EnterButton").get_global_rect().end.y <= viewport_size.y)
		viewport.queue_free()
		await process_frame

	print("LEVEL_SELECT_UI_CONTRACT_PASS source=approved_master_v2 nodes=14 resolutions=3 purple_keyed=true old_ui=false")
	quit()
