extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/game/challenge/challenge_level.tscn")

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
		await process_frame
		var screen: Control = level.get_node("MatchScreen") as Control
		var initial_view: Dictionary = screen.get_player_view_snapshot()
		_expect(level.get_level_id() == level_id, "%s did not preserve the selected level id" % level_id)
		_expect(level.get_node_or_null("TutorialOverlay") == null, "%s still routed through tutorial graybox UI" % level_id)
		_expect(not initial_view.is_empty(), "%s did not publish a formal PlayerView" % level_id)
		_expect(initial_view.get("flags", []).is_empty(), "%s must not create flag objectives" % level_id)
		screen.handle_board_point(Vector2i(1, 4))
		await process_frame
		screen.handle_board_point(Vector2i(1, 5))
		await process_frame
		screen.confirm_prepared_action()
		await process_frame
		await process_frame
		await process_frame
		var after_action: Dictionary = screen.get_player_view_snapshot()
		_expect(int(after_action.get("action_index", 0)) == 2, "%s opponent did not complete an AI action" % level_id)
		_expect(str(after_action.get("active_side", "")) == "red", "%s did not return control to red" % level_id)
		level.queue_free()
		await process_frame
	root.remove_meta("veilfront_selected_level_id")
	if _failures.is_empty():
		print("CHALLENGE_TEST_ENTRY_CONTRACT_PASS levels=3 ai=limited-observer-policy")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("CHALLENGE_TEST_ENTRY_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
