extends SceneTree

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchSimulator = preload("res://scripts/prototype/simulation/match_simulator.gd")
const ReplayRunner = preload("res://scripts/prototype/replay/replay_runner.gd")

const FAILURE_SEED: int = 471016
const ROUND_LIMIT: int = 50


func _init() -> void:
	var live: Dictionary = MatchSimulator.run_match(FAILURE_SEED, {
		"full_round_limit_hypothesis": ROUND_LIMIT,
		"verify_replay": false,
		"include_replay": true,
	})
	if not live.get("ok", false):
		print("QA_DIAGNOSTIC_SETUP_FAILED %s" % Canonical.json(live.get("failures", [])))
		quit(2)
		return
	var recording: Dictionary = ReplayRunner.capture(
		FAILURE_SEED,
		live["intents"],
		{"full_round_limit_hypothesis": ROUND_LIMIT}
	)
	var live_events: Array = live["action_events"]
	var replay_events: Array = recording["action_events"]
	var execution_results: Array = recording["execution_results"]
	var first_event_mismatch: int = _first_mismatch(live_events, replay_events)
	var first_rejected_intent: int = -1
	for index: int in execution_results.size():
		var execution: Dictionary = execution_results[index]
		if not execution.get("ok", false) or not execution.get("consumed", false):
			first_rejected_intent = index
			break
	var summary: Dictionary = {
		"seed": FAILURE_SEED,
		"round_limit": ROUND_LIMIT,
		"intent_count": live["intents"].size(),
		"live_event_count": live_events.size(),
		"replay_event_count": replay_events.size(),
		"first_event_mismatch": first_event_mismatch,
		"first_rejected_intent": first_rejected_intent,
		"live_state_digest": live["state_digest"],
		"replay_state_digest": recording["final_state_summary"]["state_digest"],
		"live_event_digest": live["event_log_digest"],
		"replay_event_digest": Canonical.digest(replay_events),
		"state_digest_matches": live["state_digest"] == recording["final_state_summary"]["state_digest"],
		"event_digest_matches": live["event_log_digest"] == Canonical.digest(replay_events),
	}
	print("QA_SEED_471016_DIAGNOSTIC %s" % Canonical.json(summary))
	if first_rejected_intent >= 0:
		print("QA_FIRST_REJECTED_INTENT %s" % Canonical.json({
			"index": first_rejected_intent,
			"intent": live["intents"][first_rejected_intent],
			"execution": execution_results[first_rejected_intent],
		}))
	if first_event_mismatch >= 0:
		print("QA_FIRST_EVENT_MISMATCH %s" % Canonical.json({
			"index": first_event_mismatch,
			"intent": live["intents"][first_event_mismatch] if first_event_mismatch < live["intents"].size() else {},
			"live_event": live_events[first_event_mismatch] if first_event_mismatch < live_events.size() else {},
			"replay_event": replay_events[first_event_mismatch] if first_event_mismatch < replay_events.size() else {},
		}))
	quit(0)


static func _first_mismatch(first: Array, second: Array) -> int:
	var shared: int = mini(first.size(), second.size())
	for index: int in shared:
		if Canonical.digest(first[index]) != Canonical.digest(second[index]):
			return index
	return shared if first.size() != second.size() else -1
