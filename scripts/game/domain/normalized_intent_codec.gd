extends RefCounted

const Canonical = preload("res://scripts/game/domain/canonical.gd")

const SCHEMA_VERSION: String = "veilfront-intent-v1"
const FIELDS: Array[String] = [
	"schema_version", "intent_id", "expected_action_index", "piece_id", "action_type",
	"target_cell", "skill_type", "confirmation_token",
]
const ACTION_TYPES: Array[String] = ["move", "bombard", "resurrect", "pass", "skip", "timeout"]


static func encode(intent: Dictionary) -> Dictionary:
	if not _is_valid(intent):
		return _failure("invalid_payload")
	var bytes: String = Canonical.json(intent)
	return {"ok": true, "bytes": bytes, "digest": bytes.sha256_text(), "value": intent.duplicate(true)}


static func decode(bytes: String) -> Dictionary:
	var parsed: Dictionary = Canonical.parse(bytes)
	if not bool(parsed.get("ok", false)) or not parsed.get("value") is Dictionary:
		return _failure("invalid_payload")
	var intent: Dictionary = parsed["value"]
	if str(intent.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("unsupported_schema_version")
	if Canonical.json(intent) != bytes:
		return _failure("non_canonical_json")
	if not _is_valid(intent):
		return _failure("invalid_payload")
	return {"ok": true, "bytes": bytes, "digest": bytes.sha256_text(), "value": intent.duplicate(true)}


static func to_domain_intent(intent: Dictionary) -> Dictionary:
	return {
		"piece_id": str(intent.get("piece_id", "")),
		"action_type": str(intent.get("action_type", "")),
		"target_cell": intent.get("target_cell", []).duplicate(),
		"skill_type": str(intent.get("skill_type", "")),
	}


static func _is_valid(intent: Dictionary) -> bool:
	if intent.size() != FIELDS.size():
		return false
	for field_name: String in FIELDS:
		if not intent.has(field_name):
			return false
	var action_type: String = str(intent.get("action_type", ""))
	var target: Variant = intent.get("target_cell")
	return str(intent.get("schema_version", "")) == SCHEMA_VERSION \
		and intent.get("intent_id") is String and not str(intent["intent_id"]).is_empty() \
		and typeof(intent.get("expected_action_index")) == TYPE_INT \
		and intent.get("piece_id") is String \
		and action_type in ACTION_TYPES \
		and target is Array and (target.is_empty() or _is_board_coordinate(target)) \
		and intent.get("skill_type") is String \
		and intent.get("confirmation_token") is String \
		and ((action_type in ["move", "bombard"] and target.size() == 2) \
			or (action_type in ["resurrect", "pass", "skip", "timeout"] and target.is_empty()))


static func _is_board_coordinate(target: Array) -> bool:
	return target.size() == 2 \
		and typeof(target[0]) == TYPE_INT and typeof(target[1]) == TYPE_INT \
		and int(target[0]) >= 1 and int(target[0]) <= 9 \
		and int(target[1]) >= 1 and int(target[1]) <= 24


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "bytes": "", "digest": "", "value": {}, "error_code": code}
