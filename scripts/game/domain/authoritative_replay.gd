extends RefCounted

const Canonical = preload("res://scripts/game/domain/canonical.gd")
const MatchState = preload("res://scripts/game/domain/match_state.gd")
const RuleEngine = preload("res://scripts/game/domain/rule_engine.gd")
const FullStateCodec = preload("res://scripts/game/domain/full_state_codec.gd")

const SCHEMA_VERSION: String = "veilfront-authoritative-replay-v1"
const SOURCE_COMMIT: String = "6253678157157091584b253470e709bad17c534f"
const CODEC_VERSIONS: Dictionary = {
	"full_state": "veilfront-full-state-v1",
	"domain_event": "veilfront-domain-event-v1",
	"intent": "veilfront-intent-v1",
}


static func capture(seed_value: int, intents: Array, configuration: Dictionary = {}) -> Dictionary:
	var state: Dictionary = RuleEngine.create_match(seed_value, configuration)
	var execution_results: Array = []
	var state_digests: Array = []
	var event_digests: Array = []
	var rng_checkpoints: Array = []
	for intent_value: Variant in intents:
		var intent: Dictionary = intent_value
		var prepared: Dictionary = RuleEngine.prepare_action(state)
		var result: Dictionary = RuleEngine.submit_action(state, intent, {
			"trusted_generated_action": true,
			"include_state_summary": false,
			"preparation_token": str(prepared.get("preparation", {}).get("token", "")),
		})
		execution_results.append({
			"ok": bool(result.get("ok", false)),
			"consumed": bool(result.get("consumed", false)),
			"error": result.get("error", {}).duplicate(true),
		})
		state_digests.append(FullStateCodec.encode(state).get("digest", ""))
		event_digests.append(Canonical.digest(state["events"]))
		rng_checkpoints.append({
			"action_index": int(state["action_index"]),
			"state": int(state["rng"]["state"]),
			"draw_index": int(state["rng"]["draw_index"]),
		})
	var record: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"rules_revision": str(state["rules_revision"]),
		"source_commit": SOURCE_COMMIT,
		"initial_full_state_or_seed": {
			"seed": seed_value,
			"match_id": str(state["match_id"]),
		},
		"configuration": state["configuration"].duplicate(true),
		"normalized_intents": intents.duplicate(true),
		"execution_results": execution_results,
		"domain_events": state["events"].duplicate(true),
		"state_digests": state_digests,
		"event_digests": event_digests,
		"rng_checkpoints": rng_checkpoints,
		"final_state_digest": FullStateCodec.encode(state).get("digest", ""),
		"codec_versions": CODEC_VERSIONS.duplicate(true),
		"audit_digest": "",
	}
	var audit_surface: Dictionary = record.duplicate(true)
	audit_surface["audit_digest"] = ""
	record["audit_digest"] = Canonical.digest(audit_surface)
	return record


static func verify(record: Dictionary) -> Dictionary:
	if not _has_exact_fields(record) or str(record.get("schema_version", "")) != SCHEMA_VERSION:
		return {"ok": false, "error_code": "unsupported_or_invalid_replay"}
	if str(record.get("source_commit", "")) != SOURCE_COMMIT:
		return {"ok": false, "error_code": "source_commit_mismatch"}
	if record.get("codec_versions") != CODEC_VERSIONS:
		return {"ok": false, "error_code": "codec_version_mismatch"}
	var seed_record: Variant = record.get("initial_full_state_or_seed")
	if not seed_record is Dictionary or seed_record.size() != 2 \
	or not seed_record.has("seed") or typeof(seed_record.get("seed")) != TYPE_INT \
	or not seed_record.has("match_id") or not seed_record.get("match_id") is String \
	or str(seed_record.get("match_id", "")).is_empty():
		return {"ok": false, "error_code": "invalid_initial_state_or_seed"}
	var expected_rules: String = str(RuleEngine.create_match(1)["rules_revision"])
	if str(record.get("rules_revision", "")) != expected_rules:
		return {"ok": false, "error_code": "rules_revision_mismatch"}
	var audit_surface: Dictionary = record.duplicate(true)
	var expected_audit: String = str(audit_surface.get("audit_digest", ""))
	audit_surface["audit_digest"] = ""
	if Canonical.digest(audit_surface) != expected_audit:
		return {"ok": false, "error_code": "audit_digest_mismatch"}
	var reproduction_configuration: Dictionary = record.get("configuration", {}).duplicate(true)
	reproduction_configuration["match_id"] = str(seed_record["match_id"])
	var reproduced: Dictionary = capture(
		int(seed_record.get("seed", 0)),
		record.get("normalized_intents", []),
		reproduction_configuration
	)
	var matches: bool = str(reproduced.get("final_state_digest", "")) \
		== str(record.get("final_state_digest", "")) \
		and Canonical.digest(reproduced.get("domain_events", [])) \
		== Canonical.digest(record.get("domain_events", [])) \
		and Canonical.digest(reproduced.get("execution_results", [])) \
		== Canonical.digest(record.get("execution_results", [])) \
		and reproduced.get("state_digests", []) == record.get("state_digests", []) \
		and reproduced.get("event_digests", []) == record.get("event_digests", []) \
		and reproduced.get("rng_checkpoints", []) == record.get("rng_checkpoints", [])
	return {
		"ok": matches,
		"error_code": "" if matches else "replay_divergence",
		"reproduced": reproduced,
	}


static func _has_exact_fields(record: Dictionary) -> bool:
	var fields: Array[String] = [
		"schema_version", "rules_revision", "source_commit", "initial_full_state_or_seed",
		"configuration", "normalized_intents", "execution_results", "domain_events",
		"state_digests", "event_digests", "rng_checkpoints", "final_state_digest",
		"codec_versions", "audit_digest",
	]
	if record.size() != fields.size():
		return false
	for field_name: String in fields:
		if not record.has(field_name):
			return false
	return true
