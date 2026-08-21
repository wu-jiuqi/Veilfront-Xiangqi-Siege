class_name FormalLanProtocol
extends RefCounted

const Support = preload("res://scripts/game/contracts/observer_codec_support.gd")
const PlayerViewCodec = preload("res://scripts/game/contracts/player_view_codec.gd")
const VisibleEventCodec = preload("res://scripts/game/contracts/visible_event_codec.gd")
const VisibleErrorCodec = preload("res://scripts/game/contracts/visible_error_codec.gd")
const ActionPreviewCodec = preload("res://scripts/game/contracts/action_preview_codec.gd")

const PROTOCOL_VERSION: String = "veilfront-formal-lan-v1"
const CONTROL_SCHEMA: String = "veilfront-formal-lan-control-v1"
const ACTION_REQUEST_SCHEMA: String = "veilfront-formal-lan-action-request-v1"
const PUBLIC_STATE_SCHEMA: String = "veilfront-formal-lan-public-state-v1"
const OBSERVER_BATCH_SCHEMA: String = "veilfront-formal-lan-observer-batch-v1"
const FEEDBACK_SCHEMA: String = "veilfront-formal-lan-feedback-v1"

const CONTROL_FIELDS: Array[String] = [
	"schema_version", "protocol_version", "request_id", "command", "ready",
]
const ACTION_REQUEST_FIELDS: Array[String] = [
	"schema_version", "protocol_version", "request_id", "expected_action_index",
	"piece_id", "action_type", "target_cell", "skill_type",
]
const PUBLIC_STATE_FIELDS: Array[String] = [
	"schema_version", "protocol_version", "state", "role", "local_seat",
	"local_peer_id", "host_peer_id", "endpoint", "peer_connected",
	"red_ready", "black_ready", "can_start", "match_started",
	"action_index", "active_side", "terminal", "error_code",
]
const OBSERVER_BATCH_FIELDS: Array[String] = [
	"schema_version", "protocol_version", "seat", "frame_sequence", "action_index",
	"player_view_json", "visible_event_jsons", "visible_error_json",
	"action_preview_jsons",
]
const FEEDBACK_FIELDS: Array[String] = [
	"schema_version", "protocol_version", "request_id", "accepted", "consumed",
	"error_code", "action_index",
]
const CONTROL_COMMANDS: Array[String] = ["join", "ready", "start"]
const ACTION_TYPES: Array[String] = [
	"move", "bombard", "resurrect", "pass", "skip", "timeout",
]
const PUBLIC_STATES: Array[String] = [
	"disconnected", "hosting", "connecting", "connected_transport", "lobby", "match",
	"connection_error", "connection_failed", "join_rejected", "protocol_error",
	"server_disconnected", "peer_disconnected",
]
const PUBLIC_ROLES: Array[String] = ["", "host", "client"]
const REQUEST_ID_CHARACTERS: String = \
	"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:._-"


static func encode_control_request(
	request_id: String,
	command: String,
	ready: bool = false
) -> Dictionary:
	var value: Dictionary = {
		"schema_version": CONTROL_SCHEMA,
		"protocol_version": PROTOCOL_VERSION,
		"request_id": request_id,
		"command": command,
		"ready": ready,
	}
	if not _is_valid_control(value):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	return Support.encode_canonical(value, CONTROL_SCHEMA, CONTROL_FIELDS)


static func decode_control_request(encoded: String) -> Dictionary:
	var result: Dictionary = Support.decode_canonical(
		encoded, CONTROL_SCHEMA, CONTROL_FIELDS
	)
	if not bool(result.get("ok", false)):
		return result
	if not _is_valid_control(result.get("value", {})):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	return result


static func encode_action_request(
	request_id: String,
	expected_action_index: int,
	intent: Dictionary
) -> Dictionary:
	var value: Dictionary = {
		"schema_version": ACTION_REQUEST_SCHEMA,
		"protocol_version": PROTOCOL_VERSION,
		"request_id": request_id,
		"expected_action_index": expected_action_index,
		"piece_id": str(intent.get("piece_id", "")),
		"action_type": str(intent.get("action_type", "")),
		"target_cell": intent.get("target_cell", []).duplicate(),
		"skill_type": str(intent.get("skill_type", "")),
	}
	if not _is_valid_action_request(value):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	return Support.encode_canonical(value, ACTION_REQUEST_SCHEMA, ACTION_REQUEST_FIELDS)


static func decode_action_request(encoded: String) -> Dictionary:
	var result: Dictionary = Support.decode_canonical(
		encoded, ACTION_REQUEST_SCHEMA, ACTION_REQUEST_FIELDS
	)
	if not bool(result.get("ok", false)):
		return result
	if not _is_valid_action_request(result.get("value", {})):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	return result


static func to_normalized_intent(request: Dictionary) -> Dictionary:
	return {
		"schema_version": "veilfront-intent-v1",
		"intent_id": str(request.get("request_id", "")),
		"expected_action_index": int(request.get("expected_action_index", -1)),
		"piece_id": str(request.get("piece_id", "")),
		"action_type": str(request.get("action_type", "")),
		"target_cell": request.get("target_cell", []).duplicate(),
		"skill_type": str(request.get("skill_type", "")),
		"confirmation_token": "",
	}


static func encode_public_state(public_state: Dictionary) -> Dictionary:
	if not _is_valid_public_state(public_state):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	return Support.encode_canonical(
		public_state, PUBLIC_STATE_SCHEMA, PUBLIC_STATE_FIELDS
	)


static func decode_public_state(encoded: String) -> Dictionary:
	var result: Dictionary = Support.decode_canonical(
		encoded, PUBLIC_STATE_SCHEMA, PUBLIC_STATE_FIELDS
	)
	if not bool(result.get("ok", false)):
		return result
	if not _is_valid_public_state(result.get("value", {})):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	return result


static func encode_observer_batch(
	seat: String,
	payload: Dictionary,
	frame_sequence: int
) -> Dictionary:
	var player_view: Dictionary = payload.get("player_view", {})
	var view_result: Dictionary = PlayerViewCodec.encode(player_view)
	if not bool(view_result.get("ok", false)):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	var event_jsons: Array = []
	for event_value: Variant in payload.get("visible_events", []):
		if not event_value is Dictionary:
			return Support.failure(Support.ERROR_INVALID_PAYLOAD)
		var event_result: Dictionary = VisibleEventCodec.encode(event_value)
		if not bool(event_result.get("ok", false)):
			return Support.failure(Support.ERROR_INVALID_PAYLOAD)
		event_jsons.append(str(event_result.get("bytes", "")))
	var error_json: String = ""
	var visible_error: Dictionary = payload.get("visible_error", {})
	if not visible_error.is_empty():
		var error_result: Dictionary = VisibleErrorCodec.encode(visible_error)
		if not bool(error_result.get("ok", false)):
			return Support.failure(Support.ERROR_INVALID_PAYLOAD)
		error_json = str(error_result.get("bytes", ""))
	var preview_jsons: Array = []
	for preview_value: Variant in payload.get("action_previews", []):
		if not preview_value is Dictionary:
			return Support.failure(Support.ERROR_INVALID_PAYLOAD)
		var preview_result: Dictionary = ActionPreviewCodec.encode(preview_value)
		if not bool(preview_result.get("ok", false)):
			return Support.failure(Support.ERROR_INVALID_PAYLOAD)
		preview_jsons.append(str(preview_result.get("bytes", "")))
	var value: Dictionary = {
		"schema_version": OBSERVER_BATCH_SCHEMA,
		"protocol_version": PROTOCOL_VERSION,
		"seat": seat,
		"frame_sequence": frame_sequence,
		"action_index": int(player_view.get("action_index", -1)),
		"player_view_json": str(view_result.get("bytes", "")),
		"visible_event_jsons": event_jsons,
		"visible_error_json": error_json,
		"action_preview_jsons": preview_jsons,
	}
	if not _is_valid_observer_batch(value):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	return Support.encode_canonical(
		value, OBSERVER_BATCH_SCHEMA, OBSERVER_BATCH_FIELDS
	)


static func decode_observer_batch(encoded: String) -> Dictionary:
	var result: Dictionary = Support.decode_canonical(
		encoded, OBSERVER_BATCH_SCHEMA, OBSERVER_BATCH_FIELDS
	)
	if not bool(result.get("ok", false)):
		return result
	if not _is_valid_observer_batch(result.get("value", {})):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	return result


static func encode_feedback(feedback: Dictionary) -> Dictionary:
	if not _is_valid_feedback(feedback):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	return Support.encode_canonical(feedback, FEEDBACK_SCHEMA, FEEDBACK_FIELDS)


static func decode_feedback(encoded: String) -> Dictionary:
	var result: Dictionary = Support.decode_canonical(
		encoded, FEEDBACK_SCHEMA, FEEDBACK_FIELDS
	)
	if not bool(result.get("ok", false)):
		return result
	if not _is_valid_feedback(result.get("value", {})):
		return Support.failure(Support.ERROR_INVALID_PAYLOAD)
	return result


static func build_feedback(
	request_id: String,
	accepted: bool,
	consumed: bool,
	error_code: String,
	action_index: int
) -> Dictionary:
	return {
		"schema_version": FEEDBACK_SCHEMA,
		"protocol_version": PROTOCOL_VERSION,
		"request_id": request_id,
		"accepted": accepted,
		"consumed": consumed,
		"error_code": error_code,
		"action_index": action_index,
	}


static func _is_valid_control(value: Dictionary) -> bool:
	return value.get("protocol_version") == PROTOCOL_VERSION \
		and _is_request_id(value.get("request_id")) \
		and value.get("command") is String \
		and str(value.get("command")) in CONTROL_COMMANDS \
		and value.get("ready") is bool \
		and (str(value.get("command")) == "ready" or not bool(value.get("ready")))


static func _is_valid_action_request(value: Dictionary) -> bool:
	if value.get("protocol_version") != PROTOCOL_VERSION \
	or not _is_request_id(value.get("request_id")) \
	or not Support.is_integer(value.get("expected_action_index"), 0) \
	or not Support.is_string(value.get("piece_id")) \
	or not value.get("action_type") is String \
	or not str(value.get("action_type")) in ACTION_TYPES \
	or not Support.is_coordinate(value.get("target_cell"), true) \
	or not Support.is_string(value.get("skill_type")):
		return false
	var action_type: String = str(value.get("action_type"))
	var target_cell: Array = value.get("target_cell")
	return (action_type in ["move", "bombard"] and target_cell.size() == 2) \
		or (action_type in ["resurrect", "pass", "skip", "timeout"] \
		and target_cell.is_empty())


static func _is_valid_public_state(value: Dictionary) -> bool:
	return value.get("protocol_version") == PROTOCOL_VERSION \
		and value.get("state") is String \
		and str(value.get("state")) in PUBLIC_STATES \
		and value.get("role") is String \
		and str(value.get("role")) in PUBLIC_ROLES \
		and Support.is_side(value.get("local_seat"), true) \
		and Support.is_integer(value.get("local_peer_id"), 0) \
		and value.get("host_peer_id") == 1 \
		and Support.is_string(value.get("endpoint")) \
		and value.get("peer_connected") is bool \
		and value.get("red_ready") is bool \
		and value.get("black_ready") is bool \
		and value.get("can_start") is bool \
		and value.get("match_started") is bool \
		and Support.is_integer(value.get("action_index"), 0) \
		and Support.is_side(value.get("active_side"), true) \
		and value.get("terminal") is bool \
		and Support.is_string(value.get("error_code"))


static func _is_valid_observer_batch(value: Dictionary) -> bool:
	if value.get("protocol_version") != PROTOCOL_VERSION \
	or not Support.is_side(value.get("seat")) \
	or not Support.is_integer(value.get("frame_sequence"), 1) \
	or not Support.is_integer(value.get("action_index"), 0) \
	or not Support.is_string(value.get("player_view_json"), false) \
	or not value.get("visible_event_jsons") is Array \
	or not Support.is_string(value.get("visible_error_json")) \
	or not value.get("action_preview_jsons") is Array:
		return false
	var view_result: Dictionary = PlayerViewCodec.decode(str(value.get("player_view_json")))
	if not bool(view_result.get("ok", false)):
		return false
	var player_view: Dictionary = view_result.get("value", {})
	if str(player_view.get("viewer_side", "")) != str(value.get("seat")) \
	or int(player_view.get("action_index", -1)) != int(value.get("action_index", -2)):
		return false
	for event_json: Variant in value.get("visible_event_jsons", []):
		if not event_json is String \
		or not bool(VisibleEventCodec.decode(event_json).get("ok", false)):
			return false
	var visible_error_json: String = str(value.get("visible_error_json", ""))
	if not visible_error_json.is_empty() \
	and not bool(VisibleErrorCodec.decode(visible_error_json).get("ok", false)):
		return false
	for preview_json: Variant in value.get("action_preview_jsons", []):
		if not preview_json is String \
		or not bool(ActionPreviewCodec.decode(preview_json).get("ok", false)):
			return false
	return true


static func _is_valid_feedback(value: Dictionary) -> bool:
	return value.get("protocol_version") == PROTOCOL_VERSION \
		and _is_request_id(value.get("request_id")) \
		and value.get("accepted") is bool \
		and value.get("consumed") is bool \
		and Support.is_string(value.get("error_code")) \
		and str(value.get("error_code", "")).length() <= 64 \
		and Support.is_integer(value.get("action_index"), 0)


static func _is_request_id(value: Variant) -> bool:
	if not value is String:
		return false
	var request_id: String = value
	if request_id.is_empty() or request_id.length() > 96:
		return false
	for index: int in request_id.length():
		if not REQUEST_ID_CHARACTERS.contains(request_id.substr(index, 1)):
			return false
	return true
