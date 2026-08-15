extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")


static func capture(seed_value: int, intents: Array) -> Dictionary:
	var state: Dictionary = RuleEngine.create_match(seed_value)
	var execution_results: Array = []
	for intent_value: Variant in intents:
		var result: Dictionary = RuleEngine.submit_action(state, intent_value)
		execution_results.append({
			"ok": result.get("ok", false),
			"consumed": result.get("consumed", false),
			"error": result.get("error", {}).duplicate(true),
		})
	return {
		"schema_version": "prototype-replay-v1",
		"seed": seed_value,
		"intents": intents.duplicate(true),
		"execution_results": execution_results,
		"action_events": state["events"].duplicate(true),
		"final_state_summary": MatchState.summary(state),
	}


static func replay(recording: Dictionary) -> Dictionary:
	if recording.get("schema_version", "") != "prototype-replay-v1":
		return {"ok": false, "error_code": "unsupported_replay_schema"}
	var reproduced: Dictionary = capture(int(recording["seed"]), recording["intents"])
	var event_digest_matches: bool = Canonical.digest(reproduced["action_events"]) \
		== Canonical.digest(recording["action_events"])
	var state_summary_matches: bool = reproduced["final_state_summary"] == recording["final_state_summary"]
	return {
		"ok": event_digest_matches and state_summary_matches,
		"schema_version": "replay-verification-v1",
		"event_digest_matches": event_digest_matches,
		"state_summary_matches": state_summary_matches,
		"expected_event_digest": Canonical.digest(recording["action_events"]),
		"actual_event_digest": Canonical.digest(reproduced["action_events"]),
		"expected_state_digest": recording["final_state_summary"]["state_digest"],
		"actual_state_digest": reproduced["final_state_summary"]["state_digest"],
		"reproduced": reproduced,
	}
