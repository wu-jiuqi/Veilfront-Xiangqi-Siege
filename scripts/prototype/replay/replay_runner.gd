extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")


static func capture(seed_value: int, intents: Array, configuration: Dictionary = {}) -> Dictionary:
	var state: Dictionary = RuleEngine.create_match(seed_value, configuration)
	return _capture_state(state, intents, {
		"schema_version": "prototype-replay-v1",
		"seed": seed_value,
		"configuration": state["configuration"].duplicate(true),
	})


static func capture_from_state(initial_state: Dictionary, intents: Array) -> Dictionary:
	var state: Dictionary = MatchState.clone(initial_state)
	return _capture_state(state, intents, {
		"schema_version": "prototype-state-replay-v1",
		"initial_state": MatchState.clone(initial_state),
	})


static func _capture_state(state: Dictionary, intents: Array, header: Dictionary) -> Dictionary:
	var execution_results: Array = []
	for intent_value: Variant in intents:
		var result: Dictionary = RuleEngine.submit_action(state, intent_value, {
			"trusted_generated_action": false,
			"include_state_summary": false,
		})
		execution_results.append({
			"ok": result.get("ok", false),
			"consumed": result.get("consumed", false),
			"error": result.get("error", {}).duplicate(true),
		})
	var recording: Dictionary = header.duplicate(true)
	recording.merge({
		"intents": intents.duplicate(true),
		"execution_results_schema_version": "execution-results-v1",
		"execution_results": execution_results,
		"execution_results_digest": Canonical.digest(execution_results),
		"action_events": state["events"].duplicate(true),
		"final_state_summary": MatchState.summary(state),
	})
	return recording


static func replay(recording: Dictionary) -> Dictionary:
	if recording.get("schema_version", "") not in ["prototype-replay-v1", "prototype-state-replay-v1"]:
		return {"ok": false, "error_code": "unsupported_replay_schema"}
	var reproduced: Dictionary
	if recording["schema_version"] == "prototype-state-replay-v1":
		reproduced = capture_from_state(recording["initial_state"], recording["intents"])
	else:
		reproduced = capture(
			int(recording["seed"]), recording["intents"], recording.get("configuration", {})
		)
	var event_digest_matches: bool = Canonical.digest(reproduced["action_events"]) \
		== Canonical.digest(recording["action_events"])
	var state_summary_matches: bool = reproduced["final_state_summary"] == recording["final_state_summary"]
	var execution_results_matches: bool = Canonical.digest(reproduced["execution_results"]) \
		== Canonical.digest(recording.get("execution_results", []))
	var execution_results_digest_matches: bool = str(recording.get("execution_results_digest", "")) \
		== Canonical.digest(recording.get("execution_results", []))
	return {
		"ok": event_digest_matches and state_summary_matches and execution_results_matches \
			and execution_results_digest_matches,
		"schema_version": "replay-verification-v1",
		"event_digest_matches": event_digest_matches,
		"state_summary_matches": state_summary_matches,
		"execution_results_matches": execution_results_matches,
		"execution_results_digest_matches": execution_results_digest_matches,
		"expected_execution_results_digest": str(recording.get("execution_results_digest", "")),
		"actual_execution_results_digest": Canonical.digest(reproduced["execution_results"]),
		"expected_event_digest": Canonical.digest(recording["action_events"]),
		"actual_event_digest": Canonical.digest(reproduced["action_events"]),
		"expected_state_digest": recording["final_state_summary"]["state_digest"],
		"actual_state_digest": reproduced["final_state_summary"]["state_digest"],
		"reproduced": reproduced,
	}
