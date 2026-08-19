extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")
const RESOLUTIONS: Array[Vector2] = [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080)]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("veilfront_selected_level_id", "T0")
	var level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	root.add_child(level)
	await process_frame
	_expect(level.has_method("get_layout_snapshot"), "TutorialLevel has no layout contract snapshot")
	if level.has_method("get_layout_snapshot"):
		for resolution: Vector2 in RESOLUTIONS:
			level.size = resolution
			await process_frame
			await process_frame
			var snapshot: Dictionary = level.get_layout_snapshot()
			var board_rect: Rect2 = snapshot.get("board_rect", Rect2())
			var tutorial_rect: Rect2 = snapshot.get("tutorial_rect", Rect2())
			_expect(tutorial_rect.position.x >= -0.5, "%s tutorial panel starts outside screen" % resolution)
			_expect(tutorial_rect.end.x <= resolution.x + 0.5, "%s tutorial panel exceeds screen" % resolution)
			_expect(board_rect.end.x <= tutorial_rect.position.x + 0.5, "%s board is covered by tutorial panel" % resolution)
			_expect(
				bool(snapshot.get("buttons_inside", false)) or bool(snapshot.get("actions_scrollable", false)),
				"%s tutorial actions are neither visible nor scrollable" % resolution
			)

	if _failures.is_empty():
		print("TUTORIAL_LAYOUT_CONTRACT_PASS resolutions=3")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_LAYOUT_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
