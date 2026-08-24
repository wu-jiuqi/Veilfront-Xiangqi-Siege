class_name FormalMatchClientPort
extends MatchClientPort

var _session: RefCounted
var _prepared_preview_id: String = ""
var _available_previews: Array = []


func _init(session: RefCounted, bound_side: String = "red") -> void:
	_session = session
	_bound_side = bound_side


func publish_current() -> Dictionary:
	return _publish_payload(_session.current_payload())


func request_action_previews(piece_id: String, action_type: String) -> void:
	action_previews_updated.emit(
		_filter_action_previews(_available_previews, piece_id, action_type)
	)


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
	for preview_value: Variant in _available_previews:
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
	for preview_value: Variant in _available_previews:
		if preview_value is Dictionary and str(preview_value.get("preview_id", "")) == preview_id:
			return preview_value.duplicate(true)
	return {}


func _publish_payload(payload: Dictionary) -> Dictionary:
	var player_view_value: Variant = payload.get("player_view", {})
	var visible_events_value: Variant = payload.get("visible_events", [])
	var visible_error_value: Variant = payload.get("visible_error", {})
	var action_previews_value: Variant = payload.get("action_previews", [])
	if not player_view_value is Dictionary \
	or not visible_events_value is Array \
	or not visible_error_value is Dictionary \
	or not action_previews_value is Array:
		return _port_failure()
	var player_view: Dictionary = player_view_value
	var visible_events: Array = visible_events_value
	var visible_error: Dictionary = visible_error_value
	var action_previews: Array = action_previews_value
	var publish_result: Dictionary = _publish_trusted_batch(
		player_view,
		visible_events,
		visible_error,
		action_previews,
		_prepared_preview_id
	)
	if bool(publish_result.get("ok", false)):
		_available_previews = action_previews.duplicate(true)
		session_state_changed.emit({
			"state": "ready",
			"match_id": str(player_view.get("match_id", "")),
			"viewer_side": _bound_side,
		})
	return publish_result


func _port_failure() -> Dictionary:
	return {"ok": false, "error_code": "invalid_observer_payload"}
