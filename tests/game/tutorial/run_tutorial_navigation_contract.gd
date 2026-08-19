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
	await process_frame
	await process_frame

	var screen: Control = level.get_node("MatchScreen") as Control
	var board_viewport: SubViewportContainer = screen.find_child("BoardViewport", true, false) as SubViewportContainer
	var board_world: Node = board_viewport.get_node("BoardSubViewport/BoardWorld")
	var camera: Camera2D = board_viewport.get_node("BoardSubViewport/BoardWorld/BoardCamera2D")
	var scroll_bar: VScrollBar = board_viewport.get_node("VerticalScrollBar")
	var initial_y := camera.position.y
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.factor = 1.0
	wheel_up.pressed = true
	board_viewport.get_node("BoardSubViewport/BoardWorld/InputSurface")._gui_input(wheel_up)
	_expect(camera.position.y < initial_y, "wheel pan did not move the board camera up")
	_expect(scroll_bar.visible, "vertical board scrollbar is not visible when the board overflows")

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

	var overlay: TutorialOverlay = level.get_node("TutorialOverlay") as TutorialOverlay
	var prompt_container := overlay.find_child("TutorialFoldable", true, false) as FoldableContainer
	_expect(prompt_container != null, "tutorial prompt is missing the foldable container")
	if prompt_container != null:
		_expect(not prompt_container.folded, "tutorial prompt should start expanded")
		prompt_container.folded = true
		await process_frame
		_expect(not bool(overlay.get_public_snapshot().get("prompt_expanded", true)), "tutorial prompt did not collapse")
		prompt_container.folded = false
		await process_frame
		_expect(bool(overlay.get_public_snapshot().get("prompt_expanded", false)), "tutorial prompt did not expand")
	var next_button: Button = overlay.find_child("NextChapterButton", true, false) as Button
	_expect(next_button != null, "tutorial completion is missing the next chapter button")
	var return_button: Button = screen.find_child("ReturnButton", true, false) as Button
	_expect(return_button != null, "match header is missing the return button")
	_expect(return_button != null and return_button.visible, "tutorial return button is not visible")
	if return_button != null:
		return_button.pressed.emit()
		await _wait_frames(3)
		_expect(current_scene != null and current_scene.name == "LevelSelect", "return button did not open level select")

	root.set_meta("veilfront_selected_level_id", "T0")
	change_scene_to_file("res://scenes/game/tutorial/tutorial_level.tscn")
	await _wait_frames(4)
	var completed_level: Control = current_scene as Control
	var completed_overlay: Control = completed_level.get_node("TutorialOverlay") as Control
	completed_overlay.render_public_step({"id": "completed", "step_index": 2, "step_count": 3})
	var completed_next_button: Button = completed_overlay.find_child("NextChapterButton", true, false) as Button
	completed_next_button.pressed.emit()
	await _wait_frames(4)
	_expect(str(root.get_meta("veilfront_selected_level_id", "")) == "T1", "next chapter did not select T1")
	var root_child_name: String = str(root.get_child(0).name) if root.get_child_count() > 0 else ""
	_expect(
		root_child_name == "TutorialLevel",
		"next chapter did not open the tutorial scene; root child=%s" % root_child_name
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
