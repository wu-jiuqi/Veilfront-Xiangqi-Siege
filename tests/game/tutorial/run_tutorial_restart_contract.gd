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
	_expect(str(director.get_public_checkpoint_id()) == "t0_marker", "restart setup did not advance")
	director.request_retry()
	await process_frame
	await process_frame
	_expect(str(director.get_public_checkpoint_id()) == "t0_cancel", "chapter restart did not restore the first checkpoint")
	var pawn_position: Array = []
	for piece: Dictionary in screen.get_player_view_snapshot().get("pieces", []):
		if str(piece.get("id", "")) == "rp0":
			pawn_position = piece.get("position", [])
	_expect(pawn_position == [5, 4], "chapter restart did not restore the fixed position")

	if _failures.is_empty():
		print("TUTORIAL_RESTART_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_RESTART_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
