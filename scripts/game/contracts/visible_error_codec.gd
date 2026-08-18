class_name VisibleErrorCodec
extends RefCounted

const Support = preload("res://scripts/game/contracts/observer_codec_support.gd")

const SCHEMA_VERSION: String = "veilfront-visible-error-v1"
const ROOT_FIELDS: Array[String] = [
	"schema_version", "intent_id", "action_index", "resolution", "public_code",
	"message_key", "consumed", "timing_bucket",
]
const RESOLUTIONS: Array[String] = [
	"rejected_without_consumption", "consumed_without_effect",
]
const PUBLIC_CODES: Array[String] = [
	"known_illegal", "intent_unresolved", "stale_intent", "invalid_request",
]


static func decode(encoded: String) -> Dictionary:
	var result: Dictionary = Support.decode_canonical(encoded, SCHEMA_VERSION, ROOT_FIELDS)
	if not bool(result.get("ok", false)):
		return result
	if not _is_valid(result.get("value", {})):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	return result


static func encode(value: Dictionary) -> Dictionary:
	if not _is_valid(value):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	return Support.encode_canonical(value, SCHEMA_VERSION, ROOT_FIELDS)


static func _is_valid(value: Dictionary) -> bool:
	if not Support.is_string(value.get("intent_id"), false) \
	or not Support.is_integer(value.get("action_index"), 0) \
	or not value.get("resolution") is String \
	or not str(value.get("resolution")) in RESOLUTIONS \
	or not value.get("public_code") is String \
	or not str(value.get("public_code")) in PUBLIC_CODES \
	or not Support.is_string(value.get("message_key"), false) \
	or not value.get("consumed") is bool \
	or not value.get("timing_bucket") is String \
	or not str(value.get("timing_bucket")) in ["immediate", "standard"]:
		return false
	var consumed: bool = bool(value.get("consumed"))
	if (value.get("resolution") == "consumed_without_effect") != consumed:
		return false
	if value.get("public_code") == "intent_unresolved" \
	and value.get("message_key") != "action.intent_unresolved":
		return false
	return true
