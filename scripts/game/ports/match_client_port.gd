@abstract
class_name MatchClientPort
extends RefCounted

signal session_state_changed(public_state: Dictionary)
signal player_view_updated(view: Dictionary)
signal visible_events_received(events: Array)
signal visible_error_received(error: Dictionary)
signal action_previews_updated(previews: Array)
signal prepared_action_changed(preview_id: String)

const PlayerViewCodec = preload("res://scripts/game/contracts/player_view_codec.gd")
const VisibleEventCodec = preload("res://scripts/game/contracts/visible_event_codec.gd")
const VisibleErrorCodec = preload("res://scripts/game/contracts/visible_error_codec.gd")
const ActionPreviewCodec = preload("res://scripts/game/contracts/action_preview_codec.gd")

var _bound_side: String = ""


@abstract func request_action_previews(piece_id: String, action_type: String) -> void
@abstract func prepare_action(preview_id: String) -> void
@abstract func confirm_prepared_action(preview_id: String) -> void
@abstract func cancel_prepared_action() -> void
@abstract func request_skip() -> void
@abstract func request_restart() -> void


func _decode_and_publish_batch(
	player_view_json: String,
	visible_event_jsons: Array,
	visible_error_json: String,
	action_preview_jsons: Array,
	prepared_preview_id: String
) -> Dictionary:
	var view_result: Dictionary = PlayerViewCodec.decode(player_view_json)
	if not bool(view_result.get("ok", false)):
		return _port_failure()
	var events_result: Dictionary = _decode_many(VisibleEventCodec, visible_event_jsons)
	if not bool(events_result.get("ok", false)):
		return _port_failure()
	var previews_result: Dictionary = _decode_many(ActionPreviewCodec, action_preview_jsons)
	if not bool(previews_result.get("ok", false)):
		return _port_failure()
	var visible_error: Dictionary = {}
	if not visible_error_json.is_empty():
		var error_result: Dictionary = VisibleErrorCodec.decode(visible_error_json)
		if not bool(error_result.get("ok", false)):
			return _port_failure()
		visible_error = error_result.get("value", {}).duplicate(true)
	var player_view: Dictionary = view_result.get("value", {}).duplicate(true)
	var incoming_side: String = str(player_view.get("viewer_side", ""))
	if (not _bound_side.is_empty() and incoming_side != _bound_side) \
	or not _is_batch_coherent(
		player_view,
		events_result.get("values", []),
		visible_error
	):
		return _port_failure()
	if _bound_side.is_empty():
		_bound_side = incoming_side

	player_view_updated.emit(player_view)
	visible_events_received.emit(events_result.get("values", []).duplicate(true))
	if not visible_error.is_empty():
		visible_error_received.emit(visible_error)
	action_previews_updated.emit(previews_result.get("values", []).duplicate(true))
	prepared_action_changed.emit(prepared_preview_id)
	return {"ok": true, "error_code": ""}


func _decode_many(codec: Variant, encoded_values: Array) -> Dictionary:
	var values: Array = []
	for encoded_value: Variant in encoded_values:
		if not encoded_value is String:
			return _port_failure()
		var result: Dictionary = codec.decode(encoded_value)
		if not bool(result.get("ok", false)):
			return _port_failure()
		values.append(result.get("value", {}).duplicate(true))
	return {"ok": true, "values": values, "error_code": ""}


func _port_failure() -> Dictionary:
	return {"ok": false, "error_code": "invalid_observer_payload"}


func _is_batch_coherent(
	player_view: Dictionary,
	visible_events: Array,
	visible_error: Dictionary
) -> bool:
	var action_index: int = int(player_view.get("action_index", -1))
	var cursor: int = int(player_view.get("visible_event_cursor", -1))
	if action_index < 0 or cursor < 0:
		return false
	if not visible_events.is_empty():
		var first_sequence: int = cursor - visible_events.size() + 1
		if first_sequence < 1:
			return false
		for event_index: int in visible_events.size():
			var visible_event: Dictionary = visible_events[event_index]
			if int(visible_event.get("visible_sequence", -1)) != first_sequence + event_index \
			or int(visible_event.get("action_index", -1)) > action_index:
				return false
	if not visible_error.is_empty() \
	and int(visible_error.get("action_index", -1)) != action_index:
		return false
	return true
