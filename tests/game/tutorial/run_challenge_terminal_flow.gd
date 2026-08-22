extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("veilfront_selected_level_id", "C1")
	var level := TUTORIAL_LEVEL_SCENE.instantiate() as Control
	root.add_child(level)
	await process_frame
	await process_frame
	await process_frame

	_expect(level.call(&"get_level_id") == "C1", "challenge entry must bind selected level")
	var match_screen := level.get_node("MatchScreen") as Control
	var initial_view: Dictionary = match_screen.call(&"get_player_view_snapshot")
	_expect(not initial_view.is_empty(), "challenge entry must publish a local PlayerView")
	if initial_view.is_empty():
		await _finish(level)
		return

	var terminal_view := initial_view.duplicate(true)
	terminal_view["terminal"] = true
	terminal_view["winner"] = "red"
	terminal_view["win_reason"] = "three_flags"
	terminal_view["full_round_index"] = 12
	terminal_view["flags"] = [
		{"discovered": true, "owner": "red"},
		{"discovered": true, "owner": "red"},
		{"discovered": true, "owner": "red"},
	]
	terminal_view["casualties"] = []
	level.call(&"_on_player_view_updated", terminal_view)
	await process_frame

	var terminal_snapshot: Dictionary = match_screen.call(&"get_terminal_snapshot")
	_expect(bool(terminal_snapshot.get("visible", false)), "challenge terminal result must open")
	_expect(
		bool(terminal_snapshot.get("restart_visible", false)) \
		and bool(terminal_snapshot.get("level_select_visible", false)) \
		and not bool(terminal_snapshot.get("lobby_visible", true)),
		"challenge terminal must expose replay and level selection only",
	)

	match_screen.emit_signal("terminal_restart_requested")
	await process_frame
	await process_frame
	terminal_snapshot = match_screen.call(&"get_terminal_snapshot")
	var restarted_view: Dictionary = match_screen.call(&"get_player_view_snapshot")
	_expect(not bool(terminal_snapshot.get("visible", true)), "challenge replay must close terminal result")
	_expect(not bool(restarted_view.get("terminal", true)), "challenge replay must publish a non-terminal view")
	_expect(
		int(restarted_view.get("action_index", -1)) == int(initial_view.get("action_index", -2)),
		"challenge replay must recreate the initial deterministic state",
	)

	await _finish(level)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(level: Node) -> void:
	root.remove_meta("veilfront_selected_level_id")
	if is_instance_valid(level):
		level.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CHALLENGE_TERMINAL_FLOW_PASS actions=replay-level-select")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("CHALLENGE_TERMINAL_FLOW_FAIL failures=%d" % _failures.size())
	quit(1)
