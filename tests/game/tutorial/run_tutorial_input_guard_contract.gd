extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")

var _rejections: Array[String] = []
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("veilfront_selected_level_id", "T1")
	var level: Control = LEVEL_SCENE.instantiate() as Control
	root.add_child(level)
	await process_frame
	await process_frame
	var screen: Control = level.get_node("MatchScreen") as Control
	var director: Node = level.get_node("TutorialDirector")
	screen.tutorial_input_rejected.connect(func(message: String) -> void: _rejections.append(message))
	var checkpoint_before := str(director.get_public_checkpoint_id())
	var action_index_before := int(screen.get_presentation_snapshot().get("action_index", -1))

	screen.handle_board_point(Vector2i(4, 13))
	screen.handle_board_point(Vector2i(5, 10))
	screen.handle_board_point(Vector2i(5, 12))
	screen.find_child("BombardButton", true, false).pressed.emit()
	await process_frame

	_expect(_rejections.size() == 3, "wrong actor, target, and mode were not all rejected")
	_expect(str(director.get_public_checkpoint_id()) == checkpoint_before, "wrong input advanced tutorial checkpoint")
	var snapshot: Dictionary = screen.get_presentation_snapshot()
	_expect(int(snapshot.get("action_index", -1)) == action_index_before, "wrong input consumed a formal action")
	_expect(str(snapshot.get("prepared_preview_id", "")).is_empty(), "wrong target prepared an action")
	_expect(str(snapshot.get("action_mode", "")) == "move", "wrong mode replaced required tutorial mode")

	if _failures.is_empty():
		print("TUTORIAL_INPUT_GUARD_CONTRACT_PASS rejections=3")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_INPUT_GUARD_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
