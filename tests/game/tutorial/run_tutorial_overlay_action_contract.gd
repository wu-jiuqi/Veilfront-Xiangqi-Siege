extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("veilfront_selected_level_id", "T6")
	var level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	root.add_child(level)
	await process_frame
	await process_frame
	var screen: Control = level.get_node("MatchScreen") as Control
	var overlay: Control = level.get_node("TutorialOverlay") as Control
	screen.handle_board_point(Vector2i(4, 1))
	screen.handle_board_point(Vector2i(5, 2))
	screen.confirm_prepared_action()
	await process_frame
	await process_frame
	var continue_button: Button = overlay.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null and continue_button.visible, "T6 sacrifice action button is not visible")
	if continue_button != null:
		continue_button.pressed.emit()
		await process_frame
		_expect(
			str(screen.get_presentation_snapshot().get("action_mode", "")) == "resurrect",
			"T6 sacrifice action button did not switch the match screen to resurrect mode"
		)
		var decision_panel := overlay.find_child("DecisionPanel", true, false) as Control
		_expect(
			decision_panel != null and not decision_panel.visible,
			"T6 sacrifice action prompt did not close after entering resurrect mode"
		)
	if _failures.is_empty():
		print("TUTORIAL_OVERLAY_ACTION_CONTRACT_PASS level=T6")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_OVERLAY_ACTION_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
