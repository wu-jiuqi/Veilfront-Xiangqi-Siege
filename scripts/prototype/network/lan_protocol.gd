extends RefCounted

const PROTOCOL_VERSION: int = 3
const ACTION_REQUEST_SCHEMA: String = "lan-action-request-v3"
const PLAYER_DELIVERY_SCHEMA: String = "lan-player-delivery-v3"
const NETWORK_PLAYER_VIEW_SCHEMA: String = "lan-player-view-v3"

const INTENT_KEYS: Array[String] = [
	"action_type",
	"piece_id",
	"skill_type",
	"target_cell",
]
const REQUEST_KEYS: Array[String] = [
	"action_index",
	"intent",
	"protocol_version",
	"request_id",
	"schema_version",
]
const DELIVERY_KEYS: Array[String] = [
	"player_view",
	"protocol_version",
	"schema_version",
	"seat",
]
const PLAYER_VIEW_KEYS: Array[String] = [
	"action_index",
	"active_side",
	"board_height",
	"board_width",
	"capture_ghosts",
	"casualties",
	"contact_intel",
	"flags",
	"full_round_index",
	"full_round_limit_hypothesis",
	"hidden_detection_cells",
	"implementation_revision",
	"pieces",
	"player_events",
	"round_limit_status",
	"rules_revision",
	"schema_version",
	"terminal",
	"viewer_side",
	"visible_cells",
	"vision_overlays",
	"walls",
	"win_reason",
	"winner",
]
const PUBLIC_FLAG_KEYS: Array[String] = [
	"capturing_side",
	"capture_progress",
	"contested",
	"discovered",
	"id",
	"owner",
	"position",
]
const CASUALTY_KEYS: Array[String] = ["piece_id", "piece_type", "side"]
const CAPTURE_GHOST_KEYS: Array[String] = ["piece_id", "piece_type", "position", "side"]
const VISION_OVERLAY_KEYS: Array[String] = [
	"elephant_block_fields", "elephant_reveal_zones", "rook_paths",
]
const VISION_SOURCE_KEYS: Array[String] = ["cells", "piece_id"]
const FORBIDDEN_DELIVERY_KEYS: Array[String] = [
	"board",
	"event_log_digest",
	"events",
	"full_state",
	"match_seed",
	"prepared_action",
	"random_samples",
	"rng",
	"state_digest",
	"state_summary",
	"vision_sources",
]


static func build_action_request(
	request_id: String,
	action_index: int,
	intent: Dictionary
) -> Dictionary:
	return {
		"schema_version": ACTION_REQUEST_SCHEMA,
		"protocol_version": PROTOCOL_VERSION,
		"request_id": request_id,
		"action_index": action_index,
		"intent": normalize_intent(intent),
	}


static func validate_action_request(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _invalid("request_not_dictionary")
	var request: Dictionary = value
	if not _has_exact_keys(request, REQUEST_KEYS):
		return _invalid("request_fields_invalid")
	if not request.get("schema_version") is String \
	or not request.get("protocol_version") is int \
	or not request.get("request_id") is String \
	or not request.get("action_index") is int:
		return _invalid("request_types_invalid")
	if str(request.get("schema_version", "")) != ACTION_REQUEST_SCHEMA:
		return _invalid("request_schema_invalid")
	if int(request.get("protocol_version", -1)) != PROTOCOL_VERSION:
		return _invalid("protocol_version_mismatch")
	var request_id: String = str(request.get("request_id", ""))
	if request_id.is_empty() or request_id.length() > 64:
		return _invalid("request_id_invalid")
	var action_index: int = int(request.get("action_index", -1))
	if action_index < 0:
		return _invalid("action_index_invalid")
	var raw_intent: Variant = request.get("intent", {})
	if not raw_intent is Dictionary:
		return _invalid("intent_not_dictionary")
	var intent_dictionary: Dictionary = raw_intent
	if not _has_exact_keys(intent_dictionary, INTENT_KEYS):
		return _invalid("intent_fields_invalid")
	if not intent_dictionary.get("piece_id") is String \
	or not intent_dictionary.get("action_type") is String \
	or not intent_dictionary.get("target_cell") is Array \
	or not intent_dictionary.get("skill_type") is String:
		return _invalid("intent_types_invalid")
	var normalized_intent: Dictionary = normalize_intent(intent_dictionary)
	if normalized_intent.is_empty():
		return _invalid("intent_invalid")
	return {
		"ok": true,
		"request": {
			"schema_version": ACTION_REQUEST_SCHEMA,
			"protocol_version": PROTOCOL_VERSION,
			"request_id": request_id,
			"action_index": action_index,
			"intent": normalized_intent,
		},
	}


static func normalize_intent(value: Dictionary) -> Dictionary:
	var action_type: String = str(value.get("action_type", ""))
	if action_type not in ["move", "bombard", "pass", "resurrect"]:
		return {}
	var target_value: Variant = value.get("target_cell", [])
	if not target_value is Array:
		return {}
	var target_cell: Array = target_value
	if action_type == "pass":
		target_cell = []
	elif action_type == "resurrect":
		if target_cell != [] and target_cell != [0, 0]:
			return {}
		target_cell = [0, 0]
	elif target_cell.size() != 2:
		return {}
	else:
		if not target_cell[0] is int or not target_cell[1] is int:
			return {}
		target_cell = [int(target_cell[0]), int(target_cell[1])]
	return {
		"piece_id": str(value.get("piece_id", "")),
		"action_type": action_type,
		"target_cell": target_cell,
		"skill_type": str(value.get("skill_type", "")),
	}


static func build_player_delivery(seat: String, player_view: Dictionary) -> Dictionary:
	return {
		"schema_version": PLAYER_DELIVERY_SCHEMA,
		"protocol_version": PROTOCOL_VERSION,
		"seat": seat,
		"player_view": sanitize_player_view(player_view),
	}


static func sanitize_player_view(player_view: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in PLAYER_VIEW_KEYS:
		if key == "schema_version":
			result[key] = NETWORK_PLAYER_VIEW_SCHEMA
		elif key == "flags":
			result[key] = _sanitize_flags(player_view.get("flags", []))
		elif player_view.has(key):
			result[key] = _duplicate_variant(player_view[key])
	return result


static func validate_player_delivery(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _invalid("delivery_not_dictionary")
	var delivery: Dictionary = value
	if not _has_exact_keys(delivery, DELIVERY_KEYS):
		return _invalid("delivery_fields_invalid")
	if not delivery.get("schema_version") is String \
	or not delivery.get("protocol_version") is int \
	or not delivery.get("seat") is String:
		return _invalid("delivery_types_invalid")
	if str(delivery.get("schema_version", "")) != PLAYER_DELIVERY_SCHEMA:
		return _invalid("delivery_schema_invalid")
	if int(delivery.get("protocol_version", -1)) != PROTOCOL_VERSION:
		return _invalid("protocol_version_mismatch")
	if str(delivery.get("seat", "")) not in ["red", "black"]:
		return _invalid("delivery_seat_invalid")
	if not delivery.get("player_view", {}) is Dictionary:
		return _invalid("player_view_not_dictionary")
	var player_view: Dictionary = delivery["player_view"]
	if not _has_exact_keys(player_view, PLAYER_VIEW_KEYS):
		return _invalid("player_view_fields_invalid")
	if str(player_view.get("schema_version", "")) != NETWORK_PLAYER_VIEW_SCHEMA:
		return _invalid("player_view_schema_invalid")
	if str(player_view.get("viewer_side", "")) != str(delivery["seat"]):
		return _invalid("player_view_seat_mismatch")
	var forbidden_path: String = first_forbidden_path(delivery)
	if not forbidden_path.is_empty():
		return {
			"ok": false,
			"error": "forbidden_delivery_field",
			"forbidden_path": forbidden_path,
		}
	var flags_validation: Dictionary = _validate_public_flags(player_view.get("flags", []))
	if not bool(flags_validation.get("ok", false)):
		return flags_validation
	var casualties_validation: Dictionary = _validate_casualties(player_view.get("casualties", []))
	if not bool(casualties_validation.get("ok", false)):
		return casualties_validation
	var ghosts_validation: Dictionary = _validate_capture_ghosts(player_view.get("capture_ghosts", []))
	if not bool(ghosts_validation.get("ok", false)):
		return ghosts_validation
	var overlays_validation: Dictionary = _validate_vision_overlays(player_view.get("vision_overlays", {}))
	if not bool(overlays_validation.get("ok", false)):
		return overlays_validation
	return {"ok": true, "delivery": delivery.duplicate(true)}


static func first_forbidden_path(value: Variant, path: String = "$") -> String:
	if value is Dictionary:
		var dictionary: Dictionary = value
		for key_value: Variant in dictionary.keys():
			var key: String = str(key_value)
			var child_path: String = "%s.%s" % [path, key]
			if key in FORBIDDEN_DELIVERY_KEYS or _looks_like_hidden_flag_location_key(key):
				return child_path
			var nested_path: String = first_forbidden_path(dictionary[key_value], child_path)
			if not nested_path.is_empty():
				return nested_path
	elif value is Array:
		var array: Array = value
		for index: int in array.size():
			var nested_path: String = first_forbidden_path(array[index], "%s[%d]" % [path, index])
			if not nested_path.is_empty():
				return nested_path
	return ""


static func _sanitize_flags(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for flag_value: Variant in value:
		if not flag_value is Dictionary:
			continue
		var flag: Dictionary = flag_value
		result.append({
			"id": str(flag.get("id", "")),
			"owner": str(flag.get("owner", "")),
			"capturing_side": str(flag.get("capturing_side", "")),
			"capture_progress": int(flag.get("capture_progress", flag.get("progress", 0))),
			"contested": bool(flag.get("contested", false)),
			"discovered": bool(flag.get("discovered", false)),
			"position": flag.get("position", []).duplicate() \
				if flag.get("position", []) is Array else [],
		})
	return result


static func _validate_public_flags(value: Variant) -> Dictionary:
	if not value is Array:
		return _invalid("flags_not_array")
	var flags: Array = value
	for flag_value: Variant in flags:
		if not flag_value is Dictionary:
			return _invalid("flag_not_dictionary")
		var flag: Dictionary = flag_value
		if not _has_exact_keys(flag, PUBLIC_FLAG_KEYS):
			return _invalid("flag_fields_invalid")
		if not flag.get("id") is String \
		or not flag.get("owner") is String \
		or not flag.get("capturing_side") is String \
		or not flag.get("capture_progress") is int \
		or not flag.get("contested") is bool \
		or not flag.get("discovered") is bool \
		or not flag.get("position") is Array:
			return _invalid("flag_types_invalid")
		var position: Array = flag["position"]
		if bool(flag["discovered"]):
			if position.size() != 2 or not position[0] is int or not position[1] is int:
				return _invalid("discovered_flag_position_invalid")
		elif not position.is_empty():
			return _invalid("undiscovered_flag_position_leak")
	return {"ok": true}


static func _validate_casualties(value: Variant) -> Dictionary:
	if not value is Array:
		return _invalid("casualties_not_array")
	for record_value: Variant in value:
		if not record_value is Dictionary:
			return _invalid("casualty_not_dictionary")
		var record: Dictionary = record_value
		if not _has_exact_keys(record, CASUALTY_KEYS):
			return _invalid("casualty_fields_invalid")
		if not record.get("piece_id") is String or not record.get("piece_type") is String \
		or not record.get("side") is String:
			return _invalid("casualty_types_invalid")
	return {"ok": true}


static func _validate_capture_ghosts(value: Variant) -> Dictionary:
	if not value is Array:
		return _invalid("capture_ghosts_not_array")
	for record_value: Variant in value:
		if not record_value is Dictionary:
			return _invalid("capture_ghost_not_dictionary")
		var record: Dictionary = record_value
		if not _has_exact_keys(record, CAPTURE_GHOST_KEYS):
			return _invalid("capture_ghost_fields_invalid")
		if not record.get("piece_id") is String or not record.get("piece_type") is String \
		or not record.get("side") is String or not _is_coordinate(record.get("position", [])):
			return _invalid("capture_ghost_types_invalid")
	return {"ok": true}


static func _validate_vision_overlays(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return _invalid("vision_overlays_not_dictionary")
	var overlays: Dictionary = value
	if not _has_exact_keys(overlays, VISION_OVERLAY_KEYS):
		return _invalid("vision_overlay_fields_invalid")
	for overlay_key: String in VISION_OVERLAY_KEYS:
		if not overlays[overlay_key] is Array:
			return _invalid("vision_overlay_not_array")
		for source_value: Variant in overlays[overlay_key]:
			if not source_value is Dictionary:
				return _invalid("vision_source_not_dictionary")
			var source: Dictionary = source_value
			if not _has_exact_keys(source, VISION_SOURCE_KEYS) \
			or not source.get("piece_id") is String or not source.get("cells") is Array:
				return _invalid("vision_source_fields_invalid")
			for cell_value: Variant in source["cells"]:
				if not _is_coordinate(cell_value):
					return _invalid("vision_source_cell_invalid")
	return {"ok": true}


static func _is_coordinate(value: Variant) -> bool:
	return value is Array and value.size() == 2 and value[0] is int and value[1] is int


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


static func _looks_like_hidden_flag_location_key(key: String) -> bool:
	var normalized: String = key.to_lower()
	return "flag" in normalized and ("position" in normalized or "cell" in normalized)


static func _has_exact_keys(dictionary: Dictionary, expected: Array[String]) -> bool:
	if dictionary.size() != expected.size():
		return false
	for key: String in expected:
		if not dictionary.has(key):
			return false
	return true


static func _invalid(code: String) -> Dictionary:
	return {"ok": false, "error": code}
