extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.set_meta("veilfront_selected_level_id", "T0")
	var level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	root.add_child(level)
	current_scene = level
	await process_frame
	await process_frame

	var screen: Control = level.get_node("MatchScreen") as Control
	var board_viewport: SubViewportContainer = screen.find_child("BoardViewport", true, false) as SubViewportContainer
	var board_world: Node = board_viewport.get_node("BoardSubViewport/BoardWorld")
	var camera: Camera2D = board_viewport.get_node("BoardSubViewport/BoardWorld/BoardCamera2D")
	var initial_y := camera.position.y
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.factor = 1.0
	wheel_up.pressed = true
	board_viewport.get_node("BoardSubViewport/BoardWorld/InputSurface")._gui_input(wheel_up)
	await _wait_frames(6)
	if is_equal_approx(camera.position.y, initial_y):
		var wheel_down := wheel_up.duplicate() as InputEventMouseButton
		wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
		board_viewport.get_node("BoardSubViewport/BoardWorld/InputSurface")._gui_input(wheel_down)
		await _wait_frames(6)
	_expect(not is_equal_approx(camera.position.y, initial_y), "wheel pan did not move the V3 board camera")

	var red_cell_world := BoardCoordinateMapper.authority_to_world(
		Vector2i(5, 4), "red", board_world.get_cell_size()
	)
	screen.find_child("MirrorButton", true, false).pressed.emit()
	await process_frame
	var black_cell_world := BoardCoordinateMapper.authority_to_world(
		Vector2i(5, 4), "black", board_world.get_cell_size()
	)
	_expect(
		board_viewport.get_presentation_side() == "black",
		"mirror button did not switch the presentation side"
	)
	_expect(red_cell_world != black_cell_world, "mirror presentation did not change display mapping")

	var overlay: Control = level.get_node("TutorialOverlay") as Control
	_expect(bool(overlay.get_public_snapshot().get("prompt_expanded", false)), "level guide should start expanded")
	overlay.set_collapsed(true)
	await process_frame
	_expect(not bool(overlay.get_public_snapshot().get("prompt_expanded", true)), "level guide did not collapse")
	overlay.set_collapsed(false)
	await process_frame
	_expect(bool(overlay.get_public_snapshot().get("prompt_expanded", false)), "level guide did not expand")
	var next_button: Button = overlay.find_child("NextChapterButton", true, false) as Button
	_expect(next_button != null, "tutorial completion is missing the next chapter button")
	var return_button: Button = screen.find_child("ReturnButton", true, false) as Button
	_expect(return_button != null, "match header is missing the return button")
	_expect(return_button != null and return_button.visible, "tutorial return button is not visible")
	if return_button != null:
		return_button.pressed.emit()
		await _wait_for_scene("LevelSelect", 120)
		_expect(current_scene != null and current_scene.name == "LevelSelect", "return button did not open level select")
		await _wait_for_transition_idle(120)

	root.set_meta("veilfront_selected_level_id", "T0")
	change_scene_to_file("res://scenes/game/tutorial/tutorial_level.tscn")
	await _wait_for_scene("TutorialLevel", 120)
	_expect(current_scene != null and current_scene.name == "TutorialLevel", "direct tutorial reload did not finish")
	if current_scene == null or current_scene.name != "TutorialLevel":
		_finish()
		return
	var completed_level: Control = current_scene as Control
	var completed_overlay: Control = completed_level.get_node("TutorialOverlay") as Control
	completed_overlay.render_public_step({"id": "completed", "step_index": 2, "step_count": 3})
	var completed_next_button: Button = completed_overlay.find_child("NextChapterButton", true, false) as Button
	completed_next_button.pressed.emit()
	await _wait_for_selected_level("T1", 120)
	_expect(str(root.get_meta("veilfront_selected_level_id", "")) == "T1", "next chapter did not select T1")
	_expect(
		current_scene != null and current_scene.name == "TutorialLevel",
		"next chapter did not open the tutorial scene"
	)
	var skipped_overlay: Control = current_scene.get_node("TutorialOverlay") as Control
	skipped_overlay.request_skip()
	await _wait_for_selected_level("T2", 120)
	_expect(
		str(root.get_meta("veilfront_selected_level_id", "")) == "T2",
		"skipping T1 did not advance to T2"
	)

	if _failures.is_empty():
		print("TUTORIAL_NAVIGATION_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_NAVIGATION_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _wait_frames(count: int) -> void:
	for _index: int in count:
		await process_frame


func _wait_for_scene(scene_name: String, maximum_frames: int) -> void:
	for _index: int in maximum_frames:
		if current_scene != null and current_scene.name == scene_name:
			return
		await process_frame


func _wait_for_selected_level(level_id: String, maximum_frames: int) -> void:
	for _index: int in maximum_frames:
		var transition := root.get_node_or_null("SceneTransition")
		var transition_idle := transition == null or not bool(transition.call("is_transitioning"))
		if str(root.get_meta("veilfront_selected_level_id", "")) == level_id \
		and current_scene != null and current_scene.name == "TutorialLevel" \
		and transition_idle:
			return
		await process_frame


func _wait_for_transition_idle(maximum_frames: int) -> void:
	var transition := root.get_node_or_null("SceneTransition")
	for _index: int in maximum_frames:
		if transition == null or not bool(transition.call("is_transitioning")):
			return
		await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("TUTORIAL_NAVIGATION_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_NAVIGATION_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)
