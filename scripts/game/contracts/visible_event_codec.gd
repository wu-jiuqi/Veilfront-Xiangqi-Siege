class_name VisibleEventCodec
extends RefCounted

const Support = preload("res://scripts/game/contracts/observer_codec_support.gd")

const SCHEMA_VERSION: String = "veilfront-visible-event-v1"
const ROOT_FIELDS: Array[String] = [
	"schema_version", "visible_sequence", "action_index", "event_type",
	"actor_side_public", "position_public", "piece_public", "message_key",
	"public_payload", "timing_bucket",
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
	return Support.is_integer(value.get("visible_sequence"), 1) \
		and Support.is_integer(value.get("action_index"), 0) \
		and Support.is_string(value.get("event_type"), false) \
		and Support.is_side(value.get("actor_side_public"), true) \
		and Support.is_coordinate(value.get("position_public"), true) \
		and _is_public_piece(value.get("piece_public")) \
		and Support.is_string(value.get("message_key"), false) \
		and value.get("public_payload") is Dictionary \
		and value.get("public_payload").is_empty() \
		and value.get("timing_bucket") is String \
		and str(value.get("timing_bucket")) in ["immediate", "standard"]


static func _is_public_piece(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var piece: Dictionary = value
	if piece.is_empty():
		return true
	return Support.has_exact_fields(piece, ["id", "side", "piece_type"]) \
		and Support.is_string(piece.get("id"), false) \
		and Support.is_side(piece.get("side")) \
		and Support.is_string(piece.get("piece_type"), false)
