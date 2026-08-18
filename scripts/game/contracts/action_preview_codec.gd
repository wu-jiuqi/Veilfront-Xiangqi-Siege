class_name ActionPreviewCodec
extends RefCounted

const Support = preload("res://scripts/game/contracts/observer_codec_support.gd")

const SCHEMA_VERSION: String = "veilfront-action-preview-v1"
const ROOT_FIELDS: Array[String] = [
	"schema_version", "preview_id", "piece_id", "action_type", "target_cell",
	"skill_type", "classification", "confirmation_required", "public_cost", "message_key",
]
const CLASSIFICATIONS: Array[String] = ["KNOWN_LEGAL", "TENTATIVE", "KNOWN_ILLEGAL"]
const ACTION_TYPES: Array[String] = ["move", "bombard", "resurrect", "pass", "skip", "timeout"]


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
	if not Support.is_string(value.get("preview_id"), false) \
	or not Support.is_string(value.get("piece_id")) \
	or not value.get("action_type") is String \
	or not str(value.get("action_type")) in ACTION_TYPES \
	or not Support.is_coordinate(value.get("target_cell"), true) \
	or not Support.is_string(value.get("skill_type")) \
	or not value.get("classification") is String \
	or not str(value.get("classification")) in CLASSIFICATIONS \
	or not value.get("confirmation_required") is bool \
	or not value.get("public_cost") is Dictionary \
	or not value.get("public_cost").is_empty() \
	or not Support.is_string(value.get("message_key"), false):
		return false
	var action_type: String = str(value.get("action_type"))
	var target_cell: Array = value.get("target_cell")
	if action_type in ["move", "bombard"] and target_cell.is_empty():
		return false
	if action_type in ["resurrect", "pass", "skip", "timeout"] and not target_cell.is_empty():
		return false
	return true
