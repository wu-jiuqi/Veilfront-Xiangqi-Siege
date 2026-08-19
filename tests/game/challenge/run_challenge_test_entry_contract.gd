extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for level_id: String in ["C1", "C2", "C3"]:
		root.set_meta("veilfront_selected_level_id", level_id)
		var level: Control = LEVEL_SCENE.instantiate() as Control
		root.add_child(level)
		await process_frame
		await process_frame
		var screen: Control = level.get_node("MatchScreen") as Control
		var overlay: Control = level.get_node("TutorialOverlay") as Control
		_expect(level.get_level_id() == level_id, "%s did not preserve the selected level id" % level_id)
		_expect(
			screen.get_player_view_snapshot().get("pieces", []).size() > 0,
			"%s test entry did not publish any formal pieces" % level_id
		)
		var overlay_snapshot: Dictionary = overlay.get_public_snapshot()
		_expect(str(overlay_snapshot.get("level_id", "")) == level_id, "%s test entry was not labelled" % level_id)
		_expect(
			str(overlay_snapshot.get("title", "")) == "挑战灰盒入口",
			"%s test entry did not disclose its graybox status" % level_id
		)
		screen.handle_board_point(Vector2i(1, 4))
		await process_frame
		screen.handle_board_point(Vector2i(1, 5))
		await process_frame
		screen.confirm_prepared_action()
		await process_frame
		await process_frame
		var after_action: Dictionary = screen.get_player_view_snapshot()
		_expect(int(after_action.get("action_index", 0)) == 2, "%s passive opponent did not return the turn" % level_id)
		_expect(str(after_action.get("active_side", "")) == "red", "%s did not return control to red" % level_id)
		level.queue_free()
		await process_frame
	if _failures.is_empty():
		print("CHALLENGE_TEST_ENTRY_CONTRACT_PASS levels=3")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("CHALLENGE_TEST_ENTRY_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
