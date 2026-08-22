extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("veilfront_selected_level_id", "T0")
	var tutorial_level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	root.add_child(tutorial_level)
	await process_frame
	await process_frame
	var screen: Control = tutorial_level.get_node("MatchScreen") as Control
	var overlay: Control = tutorial_level.get_node("TutorialOverlay") as Control

	for node_name: String in ["MoveButton", "BombardButton", "ResurrectButton", "PassButton"]:
		_expect(screen.find_child(node_name, true, false) != null, "%s is missing from the LAN-style action panel" % node_name)
	_expect(screen.get_node_or_null("ActionConfirmationPanel") == null, "central confirmation UI was not removed")
	_expect(overlay.find_child("Goal", true, false) != null, "tutorial goal panel is missing")
	_expect(overlay.find_child("StepTitle", true, false) != null, "tutorial step title is missing")
	_expect(overlay.find_child("BackToLevelsButton", true, false) != null, "back-to-levels action is missing")

	_expect(screen.has_method("handle_board_point"), "MatchScreen has no board-point interaction entry")
	if screen.has_method("handle_board_point"):
		_click_board_cell(screen, Vector2i(5, 4))
		await process_frame
		var selected: Dictionary = screen.get_presentation_snapshot()
		_expect(str(selected.get("selected_piece_id", "")) == "rp0", "clicking T0 pawn did not select it")
		_expect(int(selected.get("preview_count", 0)) > 0, "selecting T0 pawn produced no formal previews")
		_click_board_cell(screen, Vector2i(5, 5))
		await process_frame
		_expect(screen.get_local_interaction_state() == "CONFIRMING", "clicking the T0 target did not enter confirmation")
		var move_button: Button = screen.find_child("MoveButton", true, false) as Button
		_expect(move_button != null and move_button.text == "确认移动", "bottom move button did not receive the confirmation state")

	if _failures.is_empty():
		print("TUTORIAL_MATCH_INTERACTION_CONTRACT_PASS level=T0")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_MATCH_INTERACTION_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _click_board_cell(screen: Control, cell: Vector2i) -> void:
	var board_viewport: SubViewportContainer = screen.find_child(
		"BoardViewport", true, false
	) as SubViewportContainer
	var input_surface: Control = board_viewport.get_node("ScreenInputSurface") as Control
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = input_surface.global_position \
		+ board_viewport.get_container_position_for_authority_cell(cell)
	event.global_position = event.position
	root.push_input(event, true)
