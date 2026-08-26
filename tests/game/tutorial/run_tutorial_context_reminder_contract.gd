extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var policy := TutorialContextReminderPolicy.new()
	var public_events: Array = [{
		"visible_sequence": 7,
		"message_key": "wall.breached",
		"actor_side_public": "red",
	}]
	var hidden_variant := public_events.duplicate(true)
	hidden_variant[0]["full_state_hidden_piece_id"] = "black-horse-secret"
	var left := policy.reminder_for_events(public_events)
	var right := policy.reminder_for_events(hidden_variant)
	_expect(left == right, "hidden-only fields changed the public reminder")
	_expect(str(left.get("id", "")) == "wall_breached", "wall breach reminder was not selected")
	var completed := policy.reminder_for_events(public_events, {"W-02": TutorialProgressStore.COMPLETED})
	_expect(completed.is_empty(), "completed capability still produced a reminder")
	var unrelated := policy.reminder_for_error({"message_key": "move.out_of_bounds"})
	_expect(unrelated.is_empty(), "unrelated public error produced a reminder")
	if _failures.is_empty():
		print("TUTORIAL_CONTEXT_REMINDER_CONTRACT_PASS observer_safe=true")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
