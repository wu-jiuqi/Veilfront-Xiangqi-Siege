extends RefCounted

const Canonical = preload("res://scripts/game/domain/canonical.gd")

const SCHEMA_VERSION: String = "veilfront-domain-event-v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version", "event_id", "action_index", "actor_side", "intent",
	"deployments_before_action", "outcome", "random_samples",
]


static func encode(event: Dictionary) -> Dictionary:
	if not _is_valid(event):
		return _failure("invalid_payload")
	var bytes: String = Canonical.json(event)
	return {"ok": true, "bytes": bytes, "digest": bytes.sha256_text(), "value": event.duplicate(true)}


static func decode(bytes: String) -> Dictionary:
	var parsed: Dictionary = Canonical.parse_lossless(bytes)
	if not bool(parsed.get("ok", false)) or not parsed.get("value") is Dictionary:
		return _failure("invalid_payload")
	var event: Dictionary = parsed["value"]
	if str(event.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("unsupported_schema_version")
	if Canonical.json(event) != bytes:
		return _failure("non_canonical_json")
	if not _is_valid(event):
		return _failure("invalid_payload")
	return {"ok": true, "bytes": bytes, "digest": bytes.sha256_text(), "value": event.duplicate(true)}


static func _is_valid(event: Dictionary) -> bool:
	if event.size() != REQUIRED_FIELDS.size():
		return false
	for field_name: String in REQUIRED_FIELDS:
		if not event.has(field_name):
			return false
	return str(event.get("schema_version", "")) == SCHEMA_VERSION \
		and event.get("event_id") is String \
		and typeof(event.get("action_index")) == TYPE_INT \
		and str(event.get("actor_side", "")) in ["red", "black"] \
		and event.get("intent") is Dictionary \
		and event.get("deployments_before_action") is Array \
		and event.get("outcome") is Dictionary \
		and event.get("random_samples") is Array


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "bytes": "", "digest": "", "value": {}, "error_code": code}
