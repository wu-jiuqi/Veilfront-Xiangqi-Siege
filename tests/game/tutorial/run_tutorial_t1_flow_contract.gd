extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("veilfront_selected_level_id", "T1")
	var level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	root.add_child(level)
	await process_frame
	await process_frame
	var screen: Control = level.get_node("MatchScreen") as Control
	var director: Node = level.get_node("TutorialDirector")

	_submit_move(screen, Vector2i(5, 10), Vector2i(5, 11))
	await process_frame
	await process_frame
	_expect(str(director.get_public_checkpoint_id()) == "t1_cross", "T1 first move did not advance to crossing step")
	_expect(str(screen.get_player_view_snapshot().get("active_side", "")) == "red", "tutorial opponent did not yield the turn back to red")

	_submit_move(screen, Vector2i(5, 11), Vector2i(5, 15))
	await process_frame
	await process_frame
	_expect(str(director.get_public_checkpoint_id()) == "t1_quiz", "T1 crossing did not advance to quiz")
	var view: Dictionary = screen.get_player_view_snapshot()
	var positions: Dictionary = {}
	for piece: Dictionary in view.get("pieces", []):
		positions[str(piece.get("id", ""))] = piece.get("position", [])
	_expect(positions.get("rp1", []) == [5, 15], "T1 red pawn did not reach (5,15)")
	_expect(positions.get("bs1", []) == [5, 12], "T1 crossing incorrectly removed the black pawn")
	_expect(positions.get("bc1", []) == [5, 13], "T1 crossing incorrectly removed the black cannon")
	director.submit_quiz_answer(1)
	_expect(str(director.get_public_checkpoint_id()) == "completed", "T1 correct quiz answer did not complete the chapter")

	if _failures.is_empty():
		print("TUTORIAL_T1_FLOW_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_T1_FLOW_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _submit_move(screen: Control, origin: Vector2i, target: Vector2i) -> void:
	screen.handle_board_point(origin)
	screen.handle_board_point(target)
	screen.confirm_prepared_action()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
