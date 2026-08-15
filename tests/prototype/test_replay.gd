extends RefCounted

const ReplayRunner = preload("res://scripts/prototype/replay/replay_runner.gd")


static func run_suite() -> bool:
	var failures: Array[String] = []
	var intents: Array = [
		{
			"piece_id": "red-cannon-1",
			"action_type": "bombard",
			"target_cell": [5, 12],
			"skill_type": "area_bombardment",
		},
		{"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""},
		{"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""},
	]
	var recording: Dictionary = ReplayRunner.capture(6606, intents)
	_expect(recording["schema_version"] == "prototype-replay-v1", "回放schema版本", failures)
	_expect(recording["action_events"].size() == 3, "回放包含三条行动事件", failures)
	_expect(recording["action_events"][0]["schema_version"] == "action-event-v1", "行动事件schema版本", failures)
	_expect(recording["action_events"][0]["random_samples"].size() == 3, "炮击记录三个随机落点", failures)
	var verified: Dictionary = ReplayRunner.replay(recording)
	_expect(verified["ok"], "回放验证成功: %s" % str(verified), failures)
	_expect(verified["event_digest_matches"] and verified["state_summary_matches"] \
		and verified["execution_results_matches"] and verified["execution_results_digest_matches"],
		"事件、状态摘要与执行结果一致", failures)
	var tampered_intent: Dictionary = recording.duplicate(true)
	tampered_intent["intents"][0]["target_cell"] = [4, 12]
	_expect(not ReplayRunner.replay(tampered_intent)["ok"], "篡改intent必须拒绝", failures)
	var tampered_event: Dictionary = recording.duplicate(true)
	tampered_event["action_events"][0]["event_id"] = "tampered-event"
	_expect(not ReplayRunner.replay(tampered_event)["ok"], "篡改event必须拒绝", failures)
	var tampered_summary: Dictionary = recording.duplicate(true)
	tampered_summary["final_state_summary"]["state_digest"] = "tampered-state"
	_expect(not ReplayRunner.replay(tampered_summary)["ok"], "篡改summary必须拒绝", failures)
	var tampered_execution: Dictionary = recording.duplicate(true)
	tampered_execution["execution_results"][0]["consumed"] = false
	var execution_verification: Dictionary = ReplayRunner.replay(tampered_execution)
	_expect(not execution_verification["ok"] and not execution_verification["execution_results_digest_matches"],
		"篡改execution_results必须由版本化digest拒绝", failures)
	for failure: String in failures:
		push_error("REPLAY_FAIL: %s" % failure)
	return failures.is_empty()


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
