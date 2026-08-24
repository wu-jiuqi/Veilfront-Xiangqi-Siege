class_name FormalLanClientPort
extends MatchClientPort

const FormalLanProtocol = preload("res://scripts/game/contracts/formal_lan_protocol.gd")

var _session: Node
var _prepared_preview_id: String = ""
var _available_previews: Array = []
var _current_action_index: int = -1
var _last_frame_sequence: int = 0


func _init(session: Node) -> void:
	_session = session
	if _session == null:
		return
	_session.public_state_changed.connect(_on_public_state_changed)
	_session.observer_batch_received.connect(_on_observer_batch_received)


func publish_current() -> Dictionary:
	if _session == null:
		return _port_failure()
	_on_public_state_changed(_session.get_public_state_snapshot())
	var encoded_batch: String = _session.get_current_observer_batch_bytes()
	if encoded_batch.is_empty():
		return {"ok": true, "error_code": ""}
	return _publish_encoded_batch(encoded_batch)


func reset_for_new_session() -> void:
	_bound_side = ""
	_prepared_preview_id = ""
	_available_previews.clear()
	_current_action_index = -1
	_last_frame_sequence = 0


func request_action_previews(piece_id: String, action_type: String) -> void:
	# The authoritative observer batch remains the only preview source. Selection
	# only narrows that already validated cache and never republishes PlayerView.
	action_previews_updated.emit(
		_filter_action_previews(_available_previews, piece_id, action_type)
	)


func prepare_action(preview_id: String) -> void:
	if _find_preview(preview_id).is_empty():
		return
	_prepared_preview_id = preview_id
	prepared_action_changed.emit(preview_id)


func confirm_prepared_action(preview_id: String) -> void:
	if preview_id != _prepared_preview_id:
		return
	var preview: Dictionary = _find_preview(preview_id)
	if preview.is_empty() or _session == null:
		return
	var submitted: Dictionary = _session.submit_preview(preview)
	if not bool(submitted.get("ok", false)):
		return
	_prepared_preview_id = ""
	prepared_action_changed.emit("")


func cancel_prepared_action() -> void:
	_prepared_preview_id = ""
	prepared_action_changed.emit("")


func request_skip() -> void:
	if _session != null:
		_session.submit_special_action("skip")


func request_turn_timeout(expected_action_index: int) -> void:
	if _session != null:
		_session.submit_timeout(expected_action_index)


func request_restart() -> void:
	# Reusing an old authority state after a LAN match or disconnect is forbidden.
	# The frontend must create/host a fresh room through FormalLanSession.
	if _session != null:
		_session.report_local_error("restart_not_supported")


func _on_public_state_changed(public_state: Dictionary) -> void:
	var encoded: Dictionary = FormalLanProtocol.encode_public_state(public_state)
	if not bool(encoded.get("ok", false)):
		_abort_invalid_observer_payload("public_state_encode_failed")
		return
	var decoded: Dictionary = FormalLanProtocol.decode_public_state(
		str(encoded.get("bytes", ""))
	)
	if not bool(decoded.get("ok", false)):
		_abort_invalid_observer_payload("public_state_decode_failed")
		return
	var safe_state: Dictionary = decoded.get("value", {}).duplicate(true)
	var incoming_side: String = str(safe_state.get("local_seat", ""))
	if not incoming_side.is_empty():
		if not _bound_side.is_empty() and _bound_side != incoming_side:
			_abort_invalid_observer_payload("public_state_seat_mismatch")
			return
		_bound_side = incoming_side
	session_state_changed.emit(safe_state)


func _on_observer_batch_received(encoded_batch: String) -> void:
	_publish_encoded_batch(encoded_batch)


func _publish_encoded_batch(encoded_batch: String) -> Dictionary:
	var decoded: Dictionary = FormalLanProtocol.decode_observer_batch(encoded_batch)
	if not bool(decoded.get("ok", false)):
		return _abort_invalid_observer_payload("observer_batch_invalid")
	var batch: Dictionary = decoded.get("value", {})
	var incoming_side: String = str(batch.get("seat", ""))
	if not _bound_side.is_empty() and incoming_side != _bound_side:
		return _abort_invalid_observer_payload("observer_seat_mismatch")
	var frame_sequence: int = int(batch.get("frame_sequence", 0))
	if frame_sequence <= _last_frame_sequence:
		return _abort_invalid_observer_payload("observer_frame_replay")
	var incoming_action_index: int = int(batch.get("action_index", -1))
	if _current_action_index >= 0 and incoming_action_index < _current_action_index:
		return _abort_invalid_observer_payload("observer_action_index_rollback")
	if _current_action_index >= 0 and incoming_action_index != _current_action_index:
		_prepared_preview_id = ""
	var next_previews: Array = []
	for encoded_preview: Variant in batch.get("action_preview_jsons", []):
		var preview_result: Dictionary = ActionPreviewCodec.decode(str(encoded_preview))
		if not bool(preview_result.get("ok", false)):
			return _abort_invalid_observer_payload("action_preview_invalid")
		next_previews.append(preview_result.get("value", {}).duplicate(true))
	var publish_result: Dictionary = _decode_and_publish_batch(
		str(batch.get("player_view_json", "")),
		batch.get("visible_event_jsons", []).duplicate(),
		str(batch.get("visible_error_json", "")),
		batch.get("action_preview_jsons", []).duplicate(),
		_prepared_preview_id
	)
	if not bool(publish_result.get("ok", false)):
		return _abort_invalid_observer_payload("observer_batch_incoherent")
	_current_action_index = incoming_action_index
	_last_frame_sequence = frame_sequence
	_available_previews = next_previews
	return publish_result


func _abort_invalid_observer_payload(error_code: String) -> Dictionary:
	_prepared_preview_id = ""
	_available_previews.clear()
	if _session != null and _session.has_method("abort_protocol_error"):
		_session.abort_protocol_error(error_code)
	return _port_failure()


func _find_preview(preview_id: String) -> Dictionary:
	for preview_value: Variant in _available_previews:
		if preview_value is Dictionary \
		and str(preview_value.get("preview_id", "")) == preview_id:
			return preview_value.duplicate(true)
	return {}
