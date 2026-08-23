extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")
const RESOLUTIONS: Array[Vector2] = [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080)]

var _failures: Array[String] = []


func _init() -> void:
	print("TUTORIAL_LAYOUT_CONTRACT_STAGE init")
	call_deferred("_run")


func _run() -> void:
	print("TUTORIAL_LAYOUT_CONTRACT_STAGE setup")
	root.set_meta("veilfront_selected_level_id", "T0")
	var level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	var board_sub_viewport := level.get_node(
		"MatchScreen/MatchHudV2/BoardFrame/BoardViewport/BoardSubViewport"
	) as SubViewport
	board_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(level)
	await process_frame
	var screen: Control = level.get_node("MatchScreen")
	var overlay: TutorialOverlay = level.get_node("TutorialOverlay")
	var foldable: FoldableContainer = overlay.get_node("TutorialFoldable")
	_check_readability(overlay)
	var authored_overlay_rect := Rect2(overlay.position, overlay.size)
	foldable.folded = true
	await process_frame
	_expect(
		not bool(overlay.get_public_snapshot().get("prompt_expanded", true)),
		"tutorial prompt did not collapse inside the reused objective panel"
	)
	_expect(
		_rect_approximately_equal(Rect2(overlay.position, overlay.size), authored_overlay_rect),
		"folding tutorial content must not move its authored objective-panel rect"
	)
	foldable.folded = false
	await process_frame
	for default_label_name: String in [
		"SelectionStatus",
		"OwnFlags",
		"OwnCasualties",
		"EnemyCasualties",
		"BoardPosition",
	]:
		var default_label: Control = screen.find_child(default_label_name, true, false)
		_expect(
			default_label != null and not default_label.visible,
			"tutorial mode must hide default objective label: %s" % default_label_name
		)
	_expect(level.has_method("get_layout_snapshot"), "TutorialLevel has no layout contract snapshot")
	if level.has_method("get_layout_snapshot"):
		for resolution: Vector2 in RESOLUTIONS:
			level.size = resolution
			await process_frame
			await process_frame
			var snapshot: Dictionary = level.get_layout_snapshot()
			var board_rect: Rect2 = snapshot.get("board_rect", Rect2())
			var tutorial_rect: Rect2 = snapshot.get("tutorial_rect", Rect2())
			var tutorial_content_rect: Rect2 = snapshot.get("tutorial_content_rect", Rect2())
			var objective_rect: Rect2 = snapshot.get("objective_rect", Rect2())
			var round_incense_rect: Rect2 = snapshot.get("round_incense_rect", Rect2())
			var round_incense_source_rect: Rect2 = snapshot.get(
				"round_incense_source_rect",
				Rect2()
			)
			_expect(tutorial_rect.position.x >= -0.5, "%s tutorial panel starts outside screen" % resolution)
			_expect(tutorial_rect.end.x <= resolution.x + 0.5, "%s tutorial panel exceeds screen" % resolution)
			_expect(tutorial_rect.position.y >= -0.5, "%s tutorial panel starts above screen" % resolution)
			_expect(tutorial_rect.end.y <= resolution.y + 0.5, "%s tutorial panel exceeds screen height" % resolution)
			if is_equal_approx(resolution.x, 1280.0):
				_expect(
					tutorial_rect.size.x >= 360.0 and tutorial_rect.size.x <= 400.0,
					"1280 tutorial panel width must stay within 360-400px: %s" % tutorial_rect.size.x
				)
			_expect(
				_rect_approximately_equal(objective_rect, tutorial_rect),
				"%s reused objective panel does not follow its preset tutorial node" % resolution
			)
			_expect(
				_rect_approximately_equal(round_incense_rect, round_incense_source_rect),
				"%s round incense does not follow its preset tutorial slot" % resolution
			)
			_expect(
				board_rect.end.x <= tutorial_rect.position.x + 0.5,
				"%s board is covered by tutorial panel" % resolution
			)
			_expect(
				bool(snapshot.get("buttons_inside", false)) or bool(snapshot.get("actions_scrollable", false)),
				"%s tutorial actions are neither visible nor scrollable" % resolution
			)

	if _failures.is_empty():
		print("TUTORIAL_LAYOUT_CONTRACT_PASS resolutions=3")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_LAYOUT_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_readability(overlay: TutorialOverlay) -> void:
	var core_labels: Array[String] = [
		"ChapterTitle", "Goal", "StepTitle", "Instruction", "Feedback", "CompletionSummary",
	]
	for label_name: String in core_labels:
		var label := overlay.find_child(label_name, true, false) as Label
		_expect(label != null, "tutorial core label is missing: %s" % label_name)
		if label != null:
			_expect(
				label.get_theme_font_size("font_size") >= 16,
				"tutorial core label is below 16px: %s" % label_name
			)
	var auxiliary_labels: Array[String] = [
		"ProgressText", "AssessmentStatus", "ChapterCode", "Tags", "StepCounter", "ActionLog",
	]
	for label_name: String in auxiliary_labels:
		var label := overlay.find_child(label_name, true, false) as Label
		_expect(label != null, "tutorial auxiliary label is missing: %s" % label_name)
		if label != null:
			_expect(
				label.get_theme_font_size("font_size") >= 14,
				"tutorial auxiliary label is below 14px: %s" % label_name
			)
	for button_name: String in [
		"Option0", "Option1", "Option2", "ContinueButton", "NextChapterButton", "StayButton",
		"HintButton", "ResetStepButton", "RetryButton", "SkipButton", "BackToLevelsButton",
	]:
		var button := overlay.find_child(button_name, true, false) as Button
		_expect(button != null, "tutorial button is missing: %s" % button_name)
		if button != null:
			_expect(
				button.custom_minimum_size.y >= 44.0,
				"tutorial button touch height is below 44px: %s" % button_name
			)
			_expect(
				button.get_theme_font_size("font_size") >= 16,
				"tutorial button text is below 16px: %s" % button_name
			)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _rect_approximately_equal(left: Rect2, right: Rect2) -> bool:
	return left.position.distance_to(right.position) <= 0.75 \
		and left.size.distance_to(right.size) <= 0.75
