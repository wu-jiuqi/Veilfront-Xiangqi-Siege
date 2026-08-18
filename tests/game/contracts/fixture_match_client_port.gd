extends "res://scripts/game/ports/match_client_port.gd"

const VISIBLE_EVENT_JSON: String = "{\"action_index\":0,\"actor_side_public\":\"red\",\"event_type\":\"fixture.ready\",\"message_key\":\"fixture.ready\",\"piece_public\":{},\"position_public\":[],\"public_payload\":{},\"schema_version\":\"veilfront-visible-event-v1\",\"timing_bucket\":\"immediate\",\"visible_sequence\":1}"
const VISIBLE_ERROR_JSON: String = "{\"action_index\":0,\"consumed\":false,\"intent_id\":\"fixture-intent\",\"message_key\":\"action.invalid_request\",\"public_code\":\"invalid_request\",\"resolution\":\"rejected_without_consumption\",\"schema_version\":\"veilfront-visible-error-v1\",\"timing_bucket\":\"immediate\"}"
const ACTION_PREVIEW_JSON: String = "{\"action_type\":\"move\",\"classification\":\"KNOWN_LEGAL\",\"confirmation_required\":true,\"message_key\":\"action.move\",\"piece_id\":\"fixture-piece\",\"preview_id\":\"fixture-preview\",\"public_cost\":{},\"schema_version\":\"veilfront-action-preview-v1\",\"skill_type\":\"\",\"target_cell\":[1,1]}"

var _player_view_path: String


func _init(player_view_path: String) -> void:
	_player_view_path = player_view_path


func publish_fixture() -> Dictionary:
	return _publish_fixture_path(_player_view_path)


func attempt_rebind(fixture_path: String) -> Dictionary:
	return _publish_fixture_path(fixture_path)


func _publish_fixture_path(fixture_path: String) -> Dictionary:
	var player_view_json: String = FileAccess.get_file_as_string(fixture_path)
	if FileAccess.get_open_error() != OK:
		return {"ok": false, "error_code": "fixture_unreadable"}
	return _decode_and_publish_batch(
		player_view_json.strip_edges(),
		[VISIBLE_EVENT_JSON],
		VISIBLE_ERROR_JSON,
		[ACTION_PREVIEW_JSON],
		""
	)


func request_action_previews(_piece_id: String, _action_type: String) -> void:
	pass


func prepare_action(_preview_id: String) -> void:
	pass


func confirm_prepared_action(_preview_id: String) -> void:
	pass


func cancel_prepared_action() -> void:
	pass


func request_skip() -> void:
	pass


func request_restart() -> void:
	pass
