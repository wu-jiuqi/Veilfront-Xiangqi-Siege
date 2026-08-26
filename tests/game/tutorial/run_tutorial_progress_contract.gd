extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")
const TEST_PROGRESS_PATH := "user://tutorial-progress-contract.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_progress()
	root.set_meta("veilfront_selected_level_id", "T0")
	var level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	level.progress_path = TEST_PROGRESS_PATH
	var board_render_target := level.find_child("BoardSubViewport", true, false) as SubViewport
	board_render_target.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(level)
	await process_frame
	await process_frame
	var screen: Control = level.get_node("MatchScreen") as Control
	screen.handle_board_point(Vector2i(5, 4))
	screen.handle_cancel_or_marker(Vector2i(4, 5))
	screen.apply_marker(Vector2i(4, 5), "circle")
	screen.handle_board_point(Vector2i(5, 4))
	await process_frame
	screen.handle_board_point(Vector2i(5, 5))
	await process_frame
	screen.confirm_prepared_action()
	await process_frame
	await process_frame
	var director: Node = level.get_node("TutorialDirector")
	var overlay: Control = level.get_node("TutorialOverlay") as Control
	var quiz_guard := 0
	while str(director.get_public_checkpoint_id()) != "completed" and quiz_guard < 10:
		var option := overlay.find_child("Option0", true, false) as Button
		if option == null or not option.visible:
			break
		option.pressed.emit()
		quiz_guard += 1
		await process_frame
	var config := ConfigFile.new()
	_expect(config.load(TEST_PROGRESS_PATH) == OK, "tutorial completion did not create progress file")
	var completed_ids: Variant = config.get_value("progress", "completed_ids", [])
	_expect(completed_ids is Array and "T0" in completed_ids, "tutorial completion did not record T0")
	_remove_test_progress()
	level.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TUTORIAL_PROGRESS_CONTRACT_PASS level=T0")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_PROGRESS_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _remove_test_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
