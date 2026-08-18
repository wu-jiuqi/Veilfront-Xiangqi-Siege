extends RefCounted

const Canonical = preload("res://scripts/game/domain/canonical.gd")

const SCHEMA_VERSION: String = "veilfront-full-state-v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version", "match_id", "rules_revision", "implementation_revision",
	"configuration", "board_width", "board_height", "active_side", "action_index",
	"full_round_index", "terminal", "winner", "win_reason", "board", "pieces",
	"walls", "flags", "flag_discoveries", "casualty_pools", "capture_ghosts",
	"reserve_queues", "contact_intel", "vision_sources", "events", "player_events", "rng",
]


static func encode(state: Dictionary) -> Dictionary:
	if not _is_valid(state):
		return _failure("invalid_payload")
	var bytes: String = Canonical.json(state)
	return {"ok": true, "bytes": bytes, "digest": bytes.sha256_text(), "value": state.duplicate(true)}


static func decode(bytes: String) -> Dictionary:
	var parsed: Dictionary = Canonical.parse_lossless(bytes)
	if not bool(parsed.get("ok", false)) or not parsed.get("value") is Dictionary:
		return _failure("invalid_payload")
	var state: Dictionary = parsed["value"]
	if str(state.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("unsupported_schema_version")
	if Canonical.json(state) != bytes:
		return _failure("non_canonical_json")
	if not _is_valid(state):
		return _failure("invalid_payload")
	return {"ok": true, "bytes": bytes, "digest": bytes.sha256_text(), "value": state.duplicate(true)}


static func _is_valid(state: Dictionary) -> bool:
	if str(state.get("schema_version", "")) != SCHEMA_VERSION:
		return false
	for field_name: String in REQUIRED_FIELDS:
		if not state.has(field_name):
			return false
	for key_value: Variant in state.keys():
		var key: String = str(key_value)
		if not REQUIRED_FIELDS.has(key) and key != "prepared_action":
			return false
	return state.get("match_id") is String and not str(state["match_id"]).is_empty() \
		and state.get("rules_revision") is String \
		and state.get("configuration") is Dictionary \
		and int(state.get("board_width", 0)) == 9 \
		and int(state.get("board_height", 0)) == 24 \
		and str(state.get("active_side", "")) in ["red", "black"] \
		and typeof(state.get("action_index")) == TYPE_INT \
		and typeof(state.get("full_round_index")) == TYPE_INT \
		and state.get("terminal") is bool \
		and state.get("board") is Dictionary \
		and state.get("pieces") is Dictionary \
		and state.get("events") is Array \
		and state.get("rng") is Dictionary


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "bytes": "", "digest": "", "value": {}, "error_code": code}
