extends SceneTree

const LEVEL_SELECT_SCENE := preload("res://scenes/game/frontend/level_select.tscn")
const TEST_PROGRESS_PATH := "user://level-select-ui-contract.cfg"


func _init() -> void:
	_remove_test_progress()
	var level_select := LEVEL_SELECT_SCENE.instantiate() as Control
	level_select.progress_path = TEST_PROGRESS_PATH
	root.add_child(level_select)
	await process_frame

	var scene_text := FileAccess.get_file_as_string("res://scenes/game/frontend/level_select.tscn")
	var card_text := FileAccess.get_file_as_string("res://scenes/game/frontend/level_card.tscn")
	assert(not scene_text.contains("terracotta_hud_v2"))
	assert(not scene_text.contains("ui_theme_binder"))
	assert(level_select.theme.resource_path == "res://resources/game/ui/themes/level_select_master_v2_theme.tres")
	assert(not scene_text.contains("level_campaign_map_background_v1"))
	assert(not card_text.contains("level_node_states_v1"))
	assert(level_select.get_node("%DesignCanvas").get_node("CampaignBackground") is TextureRect)
	assert(level_select.get_node("%DesignCanvas").get_node("CampaignBackground").texture.resource_path == "res://assets/art/ui/level_select/level_select_empty_background_v3.png")
	assert(level_select.get_node("%TutorialGrid").get_child_count() == 1)
	assert(level_select.get_node("%ChallengeGrid").get_child_count() == 3)
	assert(not level_select.has_node("%RewardSlot"), "level details must not show a military-order reward slot")
	assert(not level_select.has_node("%DetailStatus"), "level details must not show military-order status text")
	assert(level_select.get_node("%CategoryTabs").tabs_visible == false)
	assert(level_select.get_node("%TutorialCategoryButton").button_pressed)
	assert(level_select.get_node("%DetailCode").text == "P0")
	assert(level_select.get_node("%EnterButton").text == "进入关卡")
	assert(level_select.get_node("%EnterButton").size.y >= 44.0)
	var detail_backdrop := level_select.get_node("%DesignCanvas").get_node("DetailTextBackdrop") as PanelContainer
	var detail_summary := level_select.get_node("%DetailSummary") as Label
	var detail_objective := level_select.get_node("%DetailObjective") as Label
	assert(detail_backdrop != null, "level details must provide a dedicated text backdrop")
	for detail_label: Label in [detail_summary, detail_objective]:
		assert(detail_label.get_theme_font_size("font_size") >= 16, "%s text is still too small" % detail_label.name)
		assert(detail_label.get_theme_font("font") is FontVariation, "%s does not use the semibold font" % detail_label.name)
		assert((detail_label.get_theme_font("font") as FontVariation).variation_embolden > 0.0)
		assert(detail_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART)
		assert(detail_label.clip_text)
		assert(_rect_contains_rect(detail_backdrop.get_global_rect(), detail_label.get_global_rect()))
		assert(detail_label.get_line_count() == detail_label.get_visible_line_count(), "%s text is clipped" % detail_label.name)
	assert(not detail_summary.get_global_rect().intersects(detail_objective.get_global_rect()))
	var tutorial_category := level_select.get_node("%TutorialCategoryButton") as Button
	var challenge_category := level_select.get_node("%ChallengeCategoryButton") as Button
	assert(not tutorial_category.get_global_rect().intersects(challenge_category.get_global_rect()))
	var progress_ring := level_select.get_node("%DesignCanvas").get_node("ProgressRing") as TextureRect
	var codex_button := level_select.get_node("%CodexButton") as Button
	var footer_hints := level_select.get_node("%DesignCanvas").get_node("FooterHints") as Control
	assert(not progress_ring.get_global_rect().intersects(codex_button.get_global_rect()))
	assert(not codex_button.get_global_rect().intersects(footer_hints.get_global_rect()))
	for footer_label: Label in footer_hints.get_children():
		assert(_rect_contains_rect(footer_hints.get_global_rect(), footer_label.get_global_rect()))
	_assert_button_content_fits(level_select.get_node("%BackButton") as Button)
	_assert_button_content_fits(tutorial_category)
	_assert_button_content_fits(challenge_category)
	_assert_button_content_fits(codex_button)
	_assert_button_content_fits(level_select.get_node("%EnterButton") as Button)
	var foundation_button := level_select.get_node("%FoundationRouteButton") as Button
	foundation_button.pressed.emit()
	await process_frame
	assert(foundation_button.button_pressed)
	assert((level_select.get_node("%RouteStrip") as Control).visible)
	assert(_rect_contains_rect(
		(level_select.get_node("%RouteStrip") as Control).get_global_rect(),
		(level_select.get_node("%RouteSummary") as Label).get_global_rect()
	))
	assert(level_select.get_node("%TutorialGrid").get_child_count() == 18)
	assert(level_select.get_node("%TutorialGrid").get_child(0).position == Vector2(12, 4))
	assert(level_select.get_node("%TutorialGrid").get_child(17).position == Vector2(276, 358))
	_assert_cards_do_not_overlap(level_select.get_node("%TutorialGrid") as Control)
	var first_card := level_select.get_node("%TutorialGrid").get_child(0) as LevelCard
	assert(first_card.get_node("%StateTexture").texture.resource_path == "res://assets/art/ui/level_select/components/node_selected_v2.png")
	assert(not first_card.get_node("%StateTexture").get_global_rect().intersects(first_card.get_node("%StatusLabel").get_global_rect()))
	assert(_rect_contains_rect(first_card.get_global_rect(), first_card.get_node("%CodeLabel").get_global_rect()))
	assert(_rect_contains_rect(first_card.get_global_rect(), first_card.get_node("%StatusLabel").get_global_rect()))
	assert(_rect_contains_rect(
		(first_card.get_node("StatusBackdrop") as Control).get_global_rect(),
		(first_card.get_node("%StatusLabel") as Label).get_global_rect()
	))
	assert(_count_texture_rects(first_card) == 1, "each level card must use one state texture canvas item")
	assert(
		_count_texture_rects(level_select) == 27,
		"level select must keep 23 screen textures, the codex page, and 3 dialog textures"
	)
	var experienced_button := level_select.get_node("%ExperiencedRouteButton") as Button
	experienced_button.pressed.emit()
	await process_frame
	assert(level_select.get_node("%TutorialGrid").get_child_count() == 15)

	var challenge_button := level_select.get_node("%ChallengeCategoryButton") as Button
	challenge_button.pressed.emit()
	await process_frame
	assert(level_select.get_node("%CategoryTabs").current_tab == 1)
	assert(level_select.get_node("%DetailCode").text == "C1")
	assert(not (level_select.get_node("%RouteStrip") as Control).visible)
	(level_select.get_node("%TutorialCategoryButton") as Button).pressed.emit()
	await process_frame
	assert((level_select.get_node("%RouteStrip") as Control).visible)
	var codex := level_select.get_node("%TutorialCodex") as TutorialCodex
	codex.open_codex()
	for _frame: int in 120:
		await process_frame
		if not str(codex.get_public_snapshot().get("image_path", "")).is_empty():
			break
	assert(codex.visible)
	assert(codex.z_index >= 200)
	assert(codex.get_node("Backdrop").mouse_filter == Control.MOUSE_FILTER_STOP)
	assert((codex.get_node("Panel") as Control).clip_contents)
	assert(_rect_contains_rect(codex.get_global_rect(), (codex.get_node("Panel") as Control).get_global_rect()))
	for codex_label_name: String in [
		"%PageLabel",
		"%PageCategory",
		"%PageTitle",
		"%KeyRule",
		"%StepsText",
		"%PitfallText",
		"%VisualCaption",
	]:
		var codex_label := codex.get_node(codex_label_name) as Label
		assert(not codex_label.text.is_empty(), "%s must expose tutorial text" % codex_label.name)
		assert(
			codex_label.get_line_count() == codex_label.get_visible_line_count(),
			"%s text is clipped: lines=%d visible=%d size=%s" % [
				codex_label.name,
				codex_label.get_line_count(),
				codex_label.get_visible_line_count(),
				codex_label.size,
			]
		)
	codex.close_codex()
	level_select.queue_free()
	await process_frame

	for viewport_size: Vector2i in [
		Vector2i(960, 540),
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(1600, 720),
		Vector2i(1024, 768),
	]:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		root.add_child(viewport)
		var responsive_level_select := LEVEL_SELECT_SCENE.instantiate() as Control
		responsive_level_select.progress_path = TEST_PROGRESS_PATH
		viewport.add_child(responsive_level_select)
		await process_frame
		await process_frame
		assert(responsive_level_select.size.round() == Vector2(viewport_size), "level-select root must fill %s" % viewport_size)
		var expected_scale := minf(float(viewport_size.x) / 1280.0, float(viewport_size.y) / 720.0)
		assert(is_equal_approx(responsive_level_select.get_node("%DesignCanvas").scale.x, expected_scale))
		assert(is_equal_approx(responsive_level_select.get_node("%DesignCanvas").scale.y, expected_scale))
		assert(_rect_contains_rect(
			Rect2(Vector2.ZERO, Vector2(viewport_size)),
			(responsive_level_select.get_node("%DesignCanvas") as Control).get_global_rect()
		))
		assert(responsive_level_select.get_node("%EnterButton").get_global_rect().end.x <= viewport_size.x)
		assert(responsive_level_select.get_node("%EnterButton").get_global_rect().end.y <= viewport_size.y)
		viewport.queue_free()
		await process_frame

	_remove_test_progress()
	print("LEVEL_SELECT_UI_CONTRACT_PASS source=approved_master_v3 modules=18 routes=2 resolutions=5")
	quit()


func _count_texture_rects(node: Node) -> int:
	var is_semantic_visual := node.name == &"ArtLayer" or node.name == &"Icon"
	var count := 1 if node is TextureRect and not is_semantic_visual else 0
	for child: Node in node.get_children():
		count += _count_texture_rects(child)
	return count


func _assert_cards_do_not_overlap(grid: Control) -> void:
	for first_index: int in grid.get_child_count():
		var first := grid.get_child(first_index) as Control
		for second_index: int in range(first_index + 1, grid.get_child_count()):
			var second := grid.get_child(second_index) as Control
			assert(
				not first.get_global_rect().intersects(second.get_global_rect()),
				"level cards overlap: %s and %s" % [first.name, second.name]
			)


func _assert_button_content_fits(button: Button) -> void:
	var minimum := button.get_combined_minimum_size()
	assert(
		minimum.x <= button.size.x + 0.5 and minimum.y <= button.size.y + 0.5,
		"%s content minimum %s exceeds button size %s" % [button.name, minimum, button.size]
	)


func _rect_contains_rect(outer: Rect2, inner: Rect2) -> bool:
	const EPSILON := 0.5
	return (
		inner.position.x >= outer.position.x - EPSILON
		and inner.position.y >= outer.position.y - EPSILON
		and inner.end.x <= outer.end.x + EPSILON
		and inner.end.y <= outer.end.y + EPSILON
	)


func _remove_test_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
