class_name FormalMatchClientPort
extends MatchClientPort

const NormalizedIntentCodec = preload("res://scripts/game/domain/normalized_intent_codec.gd")

var _session: RefCounted
var _prepared_preview_id: String = ""


func _init(session: RefCounted, bound_side: String = "red") -> void:
	_session = session
	_bound_side = bound_side


func publish_current() -> Dictionary:
	return _publish_payload(_session.current_payload())


func request_action_previews(_piece_id: String, _action_type: String) -> void:
	publish_current()


func prepare_action(preview_id: String) -> void:
	if _find_preview(preview_id).is_empty():
		return
	_prepared_preview_id = preview_id
	prepared_action_changed.emit(preview_id)


func confirm_prepared_action(preview_id: String) -> void:
	var preview: Dictionary = _find_preview(preview_id)
	if preview.is_empty():
		return
	var view: Dictionary = _session.current_payload().get("player_view", {})
	var intent: Dictionary = {
		"schema_version": NormalizedIntentCodec.SCHEMA_VERSION,
		"intent_id": "local:%d:%s" % [int(view.get("action_index", 0)), preview_id],
		"expected_action_index": int(view.get("action_index", 0)),
		"piece_id": str(preview.get("piece_id", "")),
		"action_type": str(preview.get("action_type", "")),
		"target_cell": preview.get("target_cell", []).duplicate(),
		"skill_type": str(preview.get("skill_type", "")),
		"confirmation_token": "",
	}
	_prepared_preview_id = ""
	_publish_payload(_session.submit_intent(intent))


func cancel_prepared_action() -> void:
	_prepared_preview_id = ""
	prepared_action_changed.emit("")


func request_skip() -> void:
	var previews: Array = _session.current_payload().get("action_previews", [])
	for preview_value: Variant in previews:
		if preview_value is Dictionary and str(preview_value.get("action_type", "")) == "skip":
			confirm_prepared_action(str(preview_value.get("preview_id", "")))
			return


func request_restart() -> void:
	_prepared_preview_id = ""
	_publish_payload(_session.restart())


func _find_preview(preview_id: String) -> Dictionary:
	var previews: Array = _session.current_payload().get("action_previews", [])
	for preview_value: Variant in previews:
		if preview_value is Dictionary and str(preview_value.get("preview_id", "")) == preview_id:
			return preview_value.duplicate(true)
	return {}


func _publish_payload(payload: Dictionary) -> Dictionary:
	var player_view: Dictionary = payload.get("player_view", {})
	var view_result: Dictionary = PlayerViewCodec.encode(player_view)
	if not bool(view_result.get("ok", false)):
		return _port_failure()
	var event_jsons: Array = []
	for event_value: Variant in payload.get("visible_events", []):
		var event_result: Dictionary = VisibleEventCodec.encode(event_value)
		if not bool(event_result.get("ok", false)):
			return _port_failure()
		event_jsons.append(str(event_result.get("bytes", "")))
	var preview_jsons: Array = []
	for preview_value: Variant in payload.get("action_previews", []):
		var preview_result: Dictionary = ActionPreviewCodec.encode(preview_value)
		if not bool(preview_result.get("ok", false)):
			return _port_failure()
		preview_jsons.append(str(preview_result.get("bytes", "")))
	var error_json := ""
	var visible_error: Dictionary = payload.get("visible_error", {})
	if not visible_error.is_empty():
		var error_result: Dictionary = VisibleErrorCodec.encode(visible_error)
		if not bool(error_result.get("ok", false)):
			return _port_failure()
		error_json = str(error_result.get("bytes", ""))
	var publish_result: Dictionary = _decode_and_publish_batch(
		str(view_result.get("bytes", "")),
		event_jsons,
		error_json,
		preview_jsons,
		_prepared_preview_id
	)
	if bool(publish_result.get("ok", false)):
		session_state_changed.emit({
			"state": "ready",
			"match_id": str(player_view.get("match_id", "")),
			"viewer_side": _bound_side,
		})
	return publish_result


func _port_failure() -> Dictionary:
	return {"ok": false, "error_code": "invalid_observer_payload"}
