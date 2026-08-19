extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("veilfront_selected_level_id", "T0")
	var level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	root.add_child(level)
	await process_frame
	await process_frame
	var screen: Control = level.get_node("MatchScreen") as Control
	var director: Node = level.get_node("TutorialDirector")

	screen.handle_board_point(Vector2i(5, 4))
	screen.handle_cancel_or_marker(Vector2i(4, 5))
	await process_frame
	_expect(str(director.get_public_checkpoint_id()) == "t0_marker", "T0 selection cancel did not advance to marker step")

	screen.apply_marker(Vector2i(4, 5), "circle")
	await process_frame
	_expect(str(director.get_public_checkpoint_id()) == "t0_move", "T0 circle marker did not advance to move step")
	screen.apply_marker(Vector2i(4, 5), "")
	await process_frame
	_expect(
		int(screen.get_board_render_snapshot().get("marker_count", -1)) == 0,
		"T0 marker clear did not remove the local marker"
	)
	_expect(
		str(director.get_public_checkpoint_id()) == "t0_move",
		"clearing a marker outside an annotate step changed tutorial progress"
	)

	screen.handle_board_point(Vector2i(5, 4))
	await process_frame
	screen.handle_board_point(Vector2i(5, 5))
	await process_frame
	screen.confirm_prepared_action()
	await process_frame
	await process_frame
	_expect(str(director.get_public_checkpoint_id()) == "completed", "T0 confirmed move did not complete the chapter")
	_expect(screen.has_method("get_player_view_snapshot"), "MatchScreen does not expose its latest observer-safe PlayerView")
	if screen.has_method("get_player_view_snapshot"):
		var view: Dictionary = screen.get_player_view_snapshot()
		var pawn_position: Array = []
		for piece: Dictionary in view.get("pieces", []):
			if str(piece.get("id", "")) == "rp0":
				pawn_position = piece.get("position", [])
		_expect(pawn_position == [5, 5], "T0 pawn did not move to the approved target")

	if _failures.is_empty():
		print("TUTORIAL_T0_FLOW_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_T0_FLOW_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
