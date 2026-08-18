class_name PlayerViewCodec
extends RefCounted

const Support = preload("res://scripts/game/contracts/observer_codec_support.gd")

const SCHEMA_VERSION: String = "veilfront-player-view-v1"
const ROOT_FIELDS: Array[String] = [
	"schema_version", "match_id", "rules_revision", "viewer_side", "board",
	"active_side", "action_index", "full_round_index", "round_limit_public",
	"terminal", "winner", "win_reason", "visible_cells", "hidden_detection_cells",
	"pieces", "flags", "walls", "casualties", "capture_ghosts", "vision_overlays",
	"contact_intel", "visible_event_cursor",
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
	return Support.is_string(value.get("match_id"), false) \
		and Support.is_string(value.get("rules_revision"), false) \
		and Support.is_side(value.get("viewer_side")) \
		and _is_board(value.get("board")) \
		and Support.is_side(value.get("active_side")) \
		and Support.is_integer(value.get("action_index"), 0) \
		and Support.is_integer(value.get("full_round_index"), 1) \
		and Support.is_integer(value.get("round_limit_public"), 1) \
		and value.get("terminal") is bool \
		and _is_winner(value.get("winner")) \
		and Support.is_string(value.get("win_reason")) \
		and Support.is_coordinate_array(value.get("visible_cells")) \
		and Support.is_coordinate_array(value.get("hidden_detection_cells")) \
		and _is_record_array(value.get("pieces"), Callable(PlayerViewCodec, "_is_piece")) \
		and _is_record_array(value.get("flags"), Callable(PlayerViewCodec, "_is_flag")) \
		and _is_record_array(value.get("walls"), Callable(PlayerViewCodec, "_is_wall")) \
		and _is_record_array(value.get("casualties"), Callable(PlayerViewCodec, "_is_casualty")) \
		and _is_record_array(value.get("capture_ghosts"), Callable(PlayerViewCodec, "_is_capture_ghost")) \
		and _is_vision_overlays(value.get("vision_overlays")) \
		and _is_record_array(value.get("contact_intel"), Callable(PlayerViewCodec, "_is_contact_intel")) \
		and Support.is_integer(value.get("visible_event_cursor"), 0)


static func _is_board(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var board: Dictionary = value
	return Support.has_exact_fields(board, ["width", "height"]) \
		and board.get("width") == 9 and board.get("height") == 24


static func _is_winner(value: Variant) -> bool:
	return value is String and str(value) in ["", "red", "black", "draw"]


static func _is_record_array(value: Variant, validator: Callable) -> bool:
	if not value is Array:
		return false
	for record_value: Variant in value:
		if not record_value is Dictionary or not bool(validator.call(record_value)):
			return false
	return true


static func _is_piece(value: Dictionary) -> bool:
	var required: Array[String] = [
		"id", "side", "piece_type", "position", "alive", "in_reserve", "status_tags",
	]
	if not Support.has_exact_fields(value, required, ["bombard_ammo"]):
		return false
	return Support.is_string(value.get("id"), false) \
		and Support.is_side(value.get("side")) \
		and Support.is_string(value.get("piece_type"), false) \
		and Support.is_coordinate(value.get("position"), true) \
		and value.get("alive") is bool \
		and value.get("in_reserve") is bool \
		and Support.is_string_array(value.get("status_tags")) \
		and (not value.has("bombard_ammo") or Support.is_integer(value.get("bombard_ammo"), 0))


static func _is_flag(value: Dictionary) -> bool:
	if not Support.has_exact_fields(value, [
		"id", "owner", "capturing_side", "capture_progress", "contested", "discovered", "position",
	]):
		return false
	var discovered: bool = value.get("discovered") is bool and bool(value.get("discovered"))
	return Support.is_string(value.get("id"), false) \
		and Support.is_side(value.get("owner"), true) \
		and Support.is_side(value.get("capturing_side"), true) \
		and Support.is_integer(value.get("capture_progress"), 0) \
		and int(value.get("capture_progress", 0)) <= 3 \
		and value.get("contested") is bool \
		and value.get("discovered") is bool \
		and ((discovered and Support.is_coordinate(value.get("position"))) \
			or (not discovered and value.get("position") is Array and value.get("position").is_empty()))


static func _is_wall(value: Dictionary) -> bool:
	return Support.has_exact_fields(value, ["side", "status"]) \
		and Support.is_side(value.get("side")) \
		and value.get("status") is String \
		and str(value.get("status")) in ["INTACT", "BREACHED", "REPAIRING"]


static func _is_casualty(value: Dictionary) -> bool:
	return Support.has_exact_fields(value, ["piece_id", "piece_type", "side"]) \
		and Support.is_string(value.get("piece_id"), false) \
		and Support.is_string(value.get("piece_type"), false) \
		and Support.is_side(value.get("side"))


static func _is_capture_ghost(value: Dictionary) -> bool:
	return Support.has_exact_fields(value, ["piece_id", "piece_type", "side", "position"]) \
		and Support.is_string(value.get("piece_id"), false) \
		and Support.is_string(value.get("piece_type"), false) \
		and Support.is_side(value.get("side")) \
		and Support.is_coordinate(value.get("position"))


static func _is_vision_overlays(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var overlays: Dictionary = value
	if not Support.has_exact_fields(overlays, [
		"rook_paths", "elephant_reveal_zones", "elephant_block_fields",
	]):
		return false
	for field_name: String in ["rook_paths", "elephant_reveal_zones", "elephant_block_fields"]:
		if not _is_record_array(overlays[field_name], Callable(PlayerViewCodec, "_is_overlay_record")):
			return false
	return true


static func _is_overlay_record(value: Dictionary) -> bool:
	return Support.has_exact_fields(value, ["piece_id", "cells"]) \
		and Support.is_string(value.get("piece_id"), false) \
		and Support.is_coordinate_array(value.get("cells"))


static func _is_contact_intel(value: Dictionary) -> bool:
	return Support.has_exact_fields(value, [
		"schema_version", "kind", "cell", "revealed_identity",
		"created_at_action_index", "persistent_tracking",
	]) \
		and value.get("schema_version") == "contact-intel-v1" \
		and Support.is_string(value.get("kind"), false) \
		and Support.is_coordinate(value.get("cell")) \
		and Support.is_string(value.get("revealed_identity")) \
		and Support.is_integer(value.get("created_at_action_index"), 0) \
		and value.get("persistent_tracking") is bool
