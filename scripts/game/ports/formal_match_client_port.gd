class_name FormalMatchClientPort
extends MatchClientPort

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
	_prepared_preview_id = ""
	var submit_result: Dictionary = _session.submit_preview(preview)
	_publish_payload(submit_result)
	if bool(submit_result.get("consumed", false)) \
	and _session.has_method("should_auto_advance_opponent") \
	and bool(_session.should_auto_advance_opponent()):
		var scripted_result: Dictionary = _session.advance_scripted_opponent()
		if bool(scripted_result.get("consumed", false)):
			_publish_payload(scripted_result)


func cancel_prepared_action() -> void:
	_prepared_preview_id = ""
	prepared_action_changed.emit("")


func request_skip() -> void:
	var previews: Array = _session.current_payload().get("action_previews", [])
	for preview_value: Variant in previews:
		if preview_value is Dictionary and str(preview_value.get("action_type", "")) == "skip":
			confirm_prepared_action(str(preview_value.get("preview_id", "")))
			return


func request_turn_timeout(expected_action_index: int) -> void:
	var submit_result: Dictionary = _session.submit_timeout(expected_action_index)
	if bool(submit_result.get("consumed", false)):
		_prepared_preview_id = ""
	_publish_payload(submit_result)
	if bool(submit_result.get("consumed", false)) \
	and _session.has_method("should_auto_advance_opponent") \
	and bool(_session.should_auto_advance_opponent()):
		var scripted_result: Dictionary = _session.advance_scripted_opponent()
		if bool(scripted_result.get("consumed", false)):
			_publish_payload(scripted_result)


func request_restart() -> void:
	_prepared_preview_id = ""
	_publish_payload(_session.restart())


func apply_tutorial_transition(step_id: String) -> Dictionary:
	if not _session.has_method("apply_tutorial_transition"):
		return {"ok": false, "error_code": "tutorial_transition_unsupported"}
	return _publish_payload(_session.apply_tutorial_transition(step_id))


func apply_tutorial_effect(step_id: String) -> Dictionary:
	return apply_tutorial_transition(step_id)


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
