extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("veilfront_selected_level_id", "T1")
	var tutorial_level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	root.add_child(tutorial_level)
	await process_frame
	await process_frame

	var screen: Control = tutorial_level.get_node("MatchScreen") as Control
	var overlay: Control = tutorial_level.get_node("TutorialOverlay") as Control
	var board_snapshot: Dictionary = screen.get_board_render_snapshot()
	var overlay_snapshot: Dictionary = overlay.get_public_snapshot()
	_expect(int(board_snapshot.get("piece_count", 0)) == 4, "T1 must render its four-piece fixed position")
	_expect(str(overlay_snapshot.get("level_id", "")) == "T1", "T1 route did not reach the tutorial overlay")
	_expect(str(overlay_snapshot.get("title", "")) == "穿阵不伤", "T1 title does not match the approved HTML")

	if _failures.is_empty():
		print("TUTORIAL_LEVEL_ROUTING_CONTRACT_PASS level=T1 pieces=4")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_LEVEL_ROUTING_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
