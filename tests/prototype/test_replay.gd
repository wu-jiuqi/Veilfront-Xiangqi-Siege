extends RefCounted

const ReplayRunner = preload("res://scripts/prototype/replay/replay_runner.gd")


static func run_suite() -> bool:
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
	assert(recording["schema_version"] == "prototype-replay-v1")
	assert(recording["action_events"].size() == 3)
	assert(recording["action_events"][0]["schema_version"] == "action-event-v1")
	assert(recording["action_events"][0]["random_samples"].size() == 3)
	var verified: Dictionary = ReplayRunner.replay(recording)
	assert(verified["ok"], str(verified))
	assert(verified["event_digest_matches"] and verified["state_summary_matches"])
	return true
