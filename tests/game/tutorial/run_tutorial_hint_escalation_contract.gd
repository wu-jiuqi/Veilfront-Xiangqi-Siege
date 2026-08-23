extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("veilfront_selected_level_id", "T10")
	var level: Control = LEVEL_SCENE.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var screen: Control = level.get_node("MatchScreen")
	var overlay: Control = level.get_node("TutorialOverlay") as Control
	_expect(not bool(overlay.get_public_snapshot().get("hint_visible", true)), "hint starts visible")
	_expect(_tutorial_target(screen) == Vector2i.ZERO, "assessment target starts revealed")

	_reject_wrong_actor(screen)
	_expect(_tutorial_target(screen) == Vector2i.ZERO, "first mistake revealed assessment target")
	_reject_wrong_actor(screen)
	_expect(_tutorial_target(screen) == Vector2i(5, 12), "second mistake did not reveal target")
	_expect(not bool(overlay.get_public_snapshot().get("hint_visible", true)), "hint opened before third mistake")

	_reject_wrong_actor(screen)
	_expect(bool(overlay.get_public_snapshot().get("hint_visible", false)), "third mistake did not open hint")
	_reject_wrong_actor(screen)
	_expect(bool(overlay.get_public_snapshot().get("step_reset_visible", false)), "fourth mistake did not open step reset")

	var reset_button: Button = overlay.find_child("ResetButton", true, false)
	reset_button.pressed.emit()
	await process_frame
	_expect(_tutorial_target(screen) == Vector2i.ZERO, "step reset did not hide assessment target")
	_expect(not bool(overlay.get_public_snapshot().get("hint_visible", true)), "step reset did not reset hint tier")

	if _failures.is_empty():
		print("TUTORIAL_HINT_ESCALATION_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _reject_wrong_actor(screen: Control) -> void:
	screen.handle_board_point(Vector2i(2, 9))


func _tutorial_target(screen: Control) -> Vector2i:
	return screen.get_board_render_snapshot().get("tutorial_target", Vector2i.ZERO)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
