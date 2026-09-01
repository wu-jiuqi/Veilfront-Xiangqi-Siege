extends SceneTree

const LEVEL_SELECT_SCENE := preload("res://scenes/game/frontend/level_select.tscn")
const TEST_PROGRESS_PATH := "user://level-select-ui-contract.cfg"
const VIEWPORTS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_progress()
	var screen := LEVEL_SELECT_SCENE.instantiate() as Control
	screen.progress_path = TEST_PROGRESS_PATH
	root.add_child(screen)
	await process_frame
	await process_frame
	_expect(screen != null, "level select did not instantiate")
	if screen == null:
		_finish()
		return

	var source := FileAccess.get_file_as_string("res://scenes/game/frontend/level_select.tscn")
	var card_source := FileAccess.get_file_as_string("res://scenes/game/frontend/level_card.tscn")
	_expect(
		screen.theme.resource_path == "res://resources/game/ui/themes/veilfront_ui_theme_v2.tres",
		"level select must use the rebuilt unified theme",
	)
	_expect(not source.contains("level_select_master_v2_theme"), "level select still uses the retired private theme")
	_expect(not card_source.contains("node_selected_v2"), "level cards still depend on fixed state-image geometry")
	_expect((screen.get_node("%DesignCanvas") as Control).scale == Vector2.ONE, "level select canvas must remain at native scale")
	_expect(_is_scalable_surface(screen.get_node("DesignCanvas/Page"), &"panel"), "level select page must be a scalable surface")
	_expect((screen.get_node("%CategoryTabs") as TabContainer).tabs_visible == false, "category tabs must remain controlled by the sidebar")
	_expect(screen.get_node("%TutorialGrid").get_child_count() == 1, "onboarding must begin with P0")
	_expect(screen.get_node("%ChallengeGrid").get_child_count() == 3, "challenge catalog count changed")
	_expect((screen.get_node("%DetailCode") as Label).text == "P0", "P0 must be selected on entry")
	_expect((screen.get_node("%EnterButton") as Button).text == "进入关卡", "P0 must remain enterable")

	var button_names: Array[String] = [
		"BackButton", "TutorialCategoryButton", "ChallengeCategoryButton",
		"FoundationRouteButton", "ExperiencedRouteButton", "EnterButton",
	]
	for button_name: String in button_names:
		var button := screen.get_node("%%%s" % button_name) as Button
		_expect(button != null, "%s is missing" % button_name)
		if button == null:
			continue
		_expect(button.custom_minimum_size.y >= 44.0, "%s is below the interaction target" % button_name)
		_expect(button.has_method("set_reduced_motion"), "%s must use the reusable motion button" % button_name)
		_expect(_is_scalable_stylebox(button.get_theme_stylebox(&"normal")), "%s must use a scalable themed surface" % button_name)

	(screen.get_node("%FoundationRouteButton") as Button).pressed.emit()
	await process_frame
	_expect(screen.get_node("%TutorialGrid").get_child_count() == 18, "foundation route must expose 18 modules")
	_assert_cards_do_not_overlap(screen.get_node("%TutorialGrid") as Control)
	_assert_card_surfaces(screen.get_node("%TutorialGrid") as Control)

	(screen.get_node("%ExperiencedRouteButton") as Button).pressed.emit()
	await process_frame
	_expect(screen.get_node("%TutorialGrid").get_child_count() == 15, "experienced route must expose 15 modules")
	_assert_cards_do_not_overlap(screen.get_node("%TutorialGrid") as Control)

	(screen.get_node("%ChallengeCategoryButton") as Button).pressed.emit()
	await process_frame
	_expect((screen.get_node("%CategoryTabs") as TabContainer).current_tab == 1, "challenge category switch failed")
	_expect(not (screen.get_node("%RouteStrip") as Control).visible, "route controls must hide in challenge category")
	(screen.get_node("%TutorialCategoryButton") as Button).pressed.emit()
	await process_frame
	_expect((screen.get_node("%CategoryTabs") as TabContainer).current_tab == 0, "tutorial category switch failed")

	for viewport_size: Vector2i in VIEWPORTS:
		root.size = viewport_size
		await process_frame
		await process_frame
		_expect((screen.get_node("%DesignCanvas") as Control).scale == Vector2.ONE, "canvas shrank at %s" % viewport_size)
		var logical_size := Vector2i(screen.get_viewport_rect().size)
		_assert_inside_viewport(screen.get_node("DesignCanvas/Page") as Control, logical_size, "level page")
		_assert_inside_viewport(screen.get_node("%BackButton") as Control, logical_size, "back button")
		_assert_inside_viewport(screen.get_node("%EnterButton") as Control, logical_size, "enter button")

	screen.queue_free()
	await process_frame
	_remove_test_progress()
	_finish()


func _assert_cards_do_not_overlap(grid: Control) -> void:
	var cards := grid.get_children()
	for index: int in cards.size():
		var card := cards[index] as Control
		for other_index: int in range(index + 1, cards.size()):
			var other := cards[other_index] as Control
			_expect(not card.get_rect().intersects(other.get_rect()), "level cards overlap: %d and %d" % [index, other_index])


func _assert_card_surfaces(grid: Control) -> void:
	for child: Node in grid.get_children():
		var card := child as Control
		var button := card.get_node("%NodeButton") as Button
		_expect(card.custom_minimum_size.y >= 44.0, "level card is below the interaction target")
		_expect(button != null and _is_scalable_stylebox(button.get_theme_stylebox(&"normal")), "level card must use the unified button surface")


func _is_scalable_surface(control: Control, style_name: StringName) -> bool:
	return control != null and _is_scalable_stylebox(control.get_theme_stylebox(style_name))


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


func _assert_inside_viewport(control: Control, viewport_size: Vector2i, label: String) -> void:
	if control == null:
		_expect(false, "%s is missing" % label)
		return
	var rect := control.get_global_rect()
	_expect(rect.position.x >= -0.5 and rect.position.y >= -0.5, "%s starts outside %s" % [label, viewport_size])
	_expect(rect.end.x <= viewport_size.x + 0.5, "%s overflows width at %s" % [label, viewport_size])
	_expect(rect.end.y <= viewport_size.y + 0.5, "%s overflows height at %s" % [label, viewport_size])


func _remove_test_progress() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("LEVEL_SELECT_UI_CONTRACT_PASS theme=unified routes=2 viewports=3")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("LEVEL_SELECT_UI_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)
