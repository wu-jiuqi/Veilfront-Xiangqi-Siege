extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")
const RESOLUTIONS: Array[Vector2] = [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080)]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("veilfront_selected_level_id", "T3")
	var level := TUTORIAL_LEVEL_SCENE.instantiate() as Control
	var board_sub_viewport := level.find_child("BoardSubViewport", true, false) as SubViewport
	board_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(level)
	await process_frame
	await process_frame

	var screen := level.get_node("MatchScreen") as Control
	var overlay := level.get_node("TutorialOverlay") as Control
	var hud := screen.get_node("MatchHudV3") as Control
	var right_rail := hud.find_child("RightRail", true, false) as Control
	var objective_events := hud.find_child("ObjectiveEvents", true, false) as Control
	var confirmation := hud.find_child("Confirmation", true, false) as Control
	_expect(
		screen.scene_file_path == "res://scenes/game/match/online_match_screen.tscn",
		"formal level does not reuse the approved online match screen"
	)
	_expect(hud.scene_file_path == "res://scenes/game/ui/match_hud_v3.tscn", "formal level does not use MatchHudV3")
	_expect(right_rail.visible, "formal level removed the V3 right-rail layout reservation")
	_expect(not objective_events.visible and not confirmation.visible, "online right-rail content remains visible behind the level guide")
	_check_readability(overlay)

	for resolution: Vector2 in RESOLUTIONS:
		level.size = resolution
		await process_frame
		await process_frame
		var snapshot: Dictionary = level.get_layout_snapshot()
		var board_rect: Rect2 = snapshot.get("board_rect", Rect2())
		var center_rect: Rect2 = snapshot.get("center_column_rect", Rect2())
		var guide_rect: Rect2 = snapshot.get("tutorial_rect", Rect2())
		var rail_rect: Rect2 = snapshot.get("objective_rect", Rect2())
		_expect(_rect_inside(guide_rect, resolution), "%s level guide exceeds the screen" % resolution)
		_expect(_rect_approximately_equal(guide_rect, rail_rect), "%s level guide does not cover the reserved right rail" % resolution)
		_expect(not center_rect.intersects(guide_rect), "%s center column expands beneath the level guide" % resolution)
		_expect(board_rect.end.x <= guide_rect.position.x + 0.5, "%s board is covered by the level guide" % resolution)
		_expect(bool(snapshot.get("buttons_inside", false)), "%s visible guide actions exceed the screen" % resolution)
		if is_equal_approx(resolution.x, 1280.0):
			_expect(
				guide_rect.size.x >= 360.0 and guide_rect.size.x <= 400.0,
				"1280 level guide must use the approved 360-400px width"
			)

	overlay.set_collapsed(true)
	await process_frame
	_expect(not bool(overlay.get_public_snapshot().get("prompt_expanded", true)), "level guide collapse state was not published")
	var collapsed_layout: Dictionary = overlay.get_layout_snapshot()
	_expect((collapsed_layout.get("guide_rect", Rect2()) as Rect2).size.x <= 45.0, "collapsed level guide did not shrink to the authored strip")
	overlay.set_collapsed(false)
	await process_frame

	overlay.render_public_step({
		"id": "layout_quiz",
		"title": "规则确认",
		"prompt": "请选择正确答案。",
		"options": ["答案一", "答案二", "答案三"],
		"step_index": 1,
		"step_count": 3,
	})
	await process_frame
	var quiz_layout: Dictionary = overlay.get_layout_snapshot()
	_check_decision_button_styles(overlay)
	_expect(
		_rect_inside(quiz_layout.get("decision_rect", Rect2()), level.size),
		"quiz decision panel exceeds the screen"
	)
	_expect(str(overlay.get_public_snapshot().get("decision_mode", "")) == "quiz", "quiz step did not open the decision panel")

	level.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TUTORIAL_LAYOUT_CONTRACT_PASS resolutions=3 hud=match-v3 guide=approved")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_LAYOUT_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_readability(overlay: Control) -> void:
	for label_name: String in [
		"GuideTitle", "ObjectiveText", "Step1Text", "CurrentOperationText", "HintText",
	]:
		var label := overlay.find_child(label_name, true, false) as Label
		_expect(label != null, "level guide label is missing: %s" % label_name)
		if label != null:
			_expect(label.get_theme_font_size("font_size") >= 11, "level guide label is below the approved 11px floor: %s" % label_name)
	for button_name: String in ["Option0", "Option1", "Option2", "ContinueButton", "NextChapterButton", "StayButton"]:
		var button := overlay.find_child(button_name, true, false) as Button
		_expect(button != null, "level decision button is missing: %s" % button_name)
		if button != null:
			_expect(button.custom_minimum_size.y >= 44.0, "level decision button is below the 44px target: %s" % button_name)
			_expect(button.get_theme_font_size("font_size") >= 16, "level decision button text is below 16px: %s" % button_name)


func _check_decision_button_styles(overlay: Control) -> void:
	for button_name: String in [
		"Option0", "Option1", "Option2", "ContinueButton",
		"NextChapterButton", "StayButton", "RetryButton", "BackToLevelsButton",
	]:
		var button := overlay.find_child(button_name, true, false) as Button
		_expect(button != null, "level decision button is missing: %s" % button_name)
		if button == null:
			continue
		for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			_expect(
				button.has_theme_stylebox_override(style_name),
				"%s still relies on the global Button skin for %s" % [button_name, style_name]
			)
			_expect(
				button.get_theme_stylebox(style_name) is StyleBoxFlat,
				"%s resolved a non-local textured Button style for %s" % [button_name, style_name]
			)


func _rect_inside(rect: Rect2, bounds: Vector2) -> bool:
	return not rect.has_area() or Rect2(Vector2.ZERO, bounds).encloses(rect)


func _rect_approximately_equal(left: Rect2, right: Rect2) -> bool:
	return left.position.distance_to(right.position) <= 1.0 \
		and left.size.distance_to(right.size) <= 1.0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
