extends RefCounted

const PROTOCOL_VERSION: int = 1
const ACTION_REQUEST_SCHEMA: String = "lan-action-request-v1"
const PLAYER_DELIVERY_SCHEMA: String = "lan-player-delivery-v1"

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
	"contact_intel",
	"flags",
	"full_round_index",
	"full_round_limit_hypothesis",
	"hidden_detection_cells",
	"implementation_revision",
	"match_seed",
	"pieces",
	"player_events",
	"round_limit_status",
	"rules_revision",
	"schema_version",
	"terminal",
	"viewer_side",
	"visible_cells",
	"walls",
	"win_reason",
	"winner",
]
const FORBIDDEN_DELIVERY_KEYS: Array[String] = [
	"board",
	"event_log_digest",
	"events",
	"full_state",
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
	if action_type not in ["move", "bombard", "pass"]:
		return {}
	var target_value: Variant = value.get("target_cell", [])
	if not target_value is Array:
		return {}
	var target_cell: Array = target_value
	if action_type == "pass":
		target_cell = []
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
		"player_view": player_view.duplicate(true),
	}


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
	if str(player_view.get("schema_version", "")) != "player-view-v1":
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
	return {"ok": true, "delivery": delivery.duplicate(true)}


static func first_forbidden_path(value: Variant, path: String = "$") -> String:
	if value is Dictionary:
		var dictionary: Dictionary = value
		for key_value: Variant in dictionary.keys():
			var key: String = str(key_value)
			var child_path: String = "%s.%s" % [path, key]
			if key in FORBIDDEN_DELIVERY_KEYS:
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


static func _has_exact_keys(dictionary: Dictionary, expected: Array[String]) -> bool:
	if dictionary.size() != expected.size():
		return false
	for key: String in expected:
		if not dictionary.has(key):
			return false
	return true


static func _invalid(code: String) -> Dictionary:
	return {"ok": false, "error": code}
