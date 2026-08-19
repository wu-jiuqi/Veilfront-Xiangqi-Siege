extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tutorial_level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	root.add_child(tutorial_level)
	await process_frame
	await process_frame

	var host: Node = tutorial_level.get_node("ApplicationHost")
	var screen: Control = tutorial_level.get_node("MatchScreen") as Control
	_expect(host.is_client_port_bound(), "TutorialLevel did not bind a local MatchClientPort")
	var board_snapshot: Dictionary = screen.get_board_render_snapshot()
	_expect(int(board_snapshot.get("piece_count", 0)) > 0, "TutorialLevel rendered no pieces")

	if _failures.is_empty():
		print("TUTORIAL_INITIAL_SESSION_SMOKE_PASS pieces=%d" % int(board_snapshot.get("piece_count", 0)))
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_INITIAL_SESSION_SMOKE_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
