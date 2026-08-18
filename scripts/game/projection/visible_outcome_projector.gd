extends RefCounted

const Canonical = preload("res://scripts/game/domain/canonical.gd")


static func project_visible_events(
	state_snapshot: Dictionary,
	viewer_context: RefCounted
) -> Array:
	assert(viewer_context != null and bool(viewer_context.call("is_valid")))
	var side: String = str(viewer_context.call("side"))
	var result: Array = []
	var source_events: Array = state_snapshot.get("player_events", {}).get(side, [])
	for index: int in source_events.size():
		var source: Dictionary = source_events[index]
		var event_type: String = str(source.get("event_type", "event.public"))
		var position: Array = source.get("position", []).duplicate()
		if position.size() != 2:
			position = []
		var payload: Dictionary = {}
		if event_type == "flag.capture_progress":
			payload = {
				"capturing_side": str(source.get("capturing_side", source.get("actor_side", ""))),
				"progress": int(source.get("progress", 1)),
			}
		result.append({
			"schema_version": "veilfront-visible-event-v1",
			"visible_sequence": index + 1,
			"action_index": _source_action_index(source, index),
			"event_type": event_type,
			"actor_side_public": str(source.get("actor_side", "")),
			"position_public": position,
			"piece_public": {},
			"message_key": "event.%s" % event_type,
			"public_payload": payload,
			"timing_bucket": "standard",
		})
	return result


static func project_visible_error(
	domain_result: Dictionary,
	intent_id: String,
	action_index: int
) -> Dictionary:
	if bool(domain_result.get("ok", false)) and bool(domain_result.get("consumed", false)):
		var event: Dictionary = domain_result.get("event", {})
		var outcome: Dictionary = event.get("outcome", {})
		if str(outcome.get("result_code", "")) in [
			"route_unknown_blocked", "target_unknown_occupied", "cannon_path_invalid",
		]:
			return _error(intent_id, action_index, true, "intent_unresolved")
		return {}
	var raw_error: Dictionary = domain_result.get("error", {})
	var raw_code: String = str(raw_error.get("code", ""))
	var public_code: String = "known_illegal"
	if raw_code.contains("stale"):
		public_code = "stale_intent"
	elif str(raw_error.get("category", "")) not in ["known_illegal", "terminal"]:
		public_code = "invalid_request"
	return _error(intent_id, action_index, false, public_code)


static func visible_event_digest(events: Array) -> String:
	return Canonical.digest(events)


static func _error(
	intent_id: String,
	action_index: int,
	consumed: bool,
	public_code: String
) -> Dictionary:
	return {
		"schema_version": "veilfront-visible-error-v1",
		"intent_id": intent_id,
		"action_index": action_index,
		"resolution": "consumed_without_effect" if consumed else "rejected_without_consumption",
		"public_code": public_code,
		"message_key": "action.intent_unresolved" if public_code == "intent_unresolved" \
			else "action.%s" % public_code,
		"consumed": consumed,
		"timing_bucket": "standard",
	}


static func _source_action_index(source: Dictionary, fallback: int) -> int:
	var identifier: String = str(source.get("id", ""))
	var parts: PackedStringArray = identifier.split("-")
	if parts.size() >= 3 and parts[2].is_valid_int():
		return int(parts[2])
	return fallback
