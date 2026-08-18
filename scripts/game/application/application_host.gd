class_name ApplicationHost
extends Node

signal session_state_changed(public_state: Dictionary)
signal player_view_updated(view: Dictionary)
signal visible_events_received(events: Array)
signal visible_error_received(error: Dictionary)
signal action_previews_updated(previews: Array)
signal prepared_action_changed(preview_id: String)
signal binding_changed(is_bound: bool)
signal tutorial_request_resolved(request_name: String, accepted: bool)

const TUTORIAL_REQUEST_RESTART: String = "restart"
const TUTORIAL_REQUEST_SKIP: String = "skip"

@export var trusted_tutorial_scenario: TutorialScenarioDefinition

var _client_port: MatchClientPort
var _tutorial_seat_verified: bool = false


func _exit_tree() -> void:
	_unbind_client_port()


func bind_client_port(client_port: MatchClientPort) -> bool:
	if client_port == null \
	or (trusted_tutorial_scenario != null and not trusted_tutorial_scenario.is_valid_definition()):
		return false
	_unbind_client_port()
	_tutorial_seat_verified = false
	_client_port = client_port
	_client_port.session_state_changed.connect(_on_session_state_changed)
	_client_port.player_view_updated.connect(_on_player_view_updated)
	_client_port.visible_events_received.connect(_on_visible_events_received)
	_client_port.visible_error_received.connect(_on_visible_error_received)
	_client_port.action_previews_updated.connect(_on_action_previews_updated)
	_client_port.prepared_action_changed.connect(_on_prepared_action_changed)
	binding_changed.emit(true)
	return true


func unbind_client_port() -> void:
	_unbind_client_port()
	binding_changed.emit(false)


func is_client_port_bound() -> bool:
	return _client_port != null


func has_trusted_tutorial_scenario() -> bool:
	return trusted_tutorial_scenario != null and trusted_tutorial_scenario.is_valid_definition()


func request_action_previews(piece_id: String, action_type: String) -> void:
	if _client_port != null:
		_client_port.request_action_previews(piece_id, action_type)


func prepare_action(preview_id: String) -> void:
	if _client_port != null and _is_preview_authorized(preview_id):
		_client_port.prepare_action(preview_id)


func confirm_prepared_action(preview_id: String) -> void:
	if _client_port != null and _is_preview_authorized(preview_id):
		_client_port.confirm_prepared_action(preview_id)


func cancel_prepared_action() -> void:
	if _client_port != null:
		_client_port.cancel_prepared_action()


func request_skip() -> void:
	var accepted: bool = _client_port != null and _is_skip_authorized()
	if accepted:
		_client_port.request_skip()
	tutorial_request_resolved.emit(TUTORIAL_REQUEST_SKIP, accepted)


func request_restart() -> void:
	var accepted: bool = _client_port != null and _is_restart_authorized()
	if accepted:
		_client_port.request_restart()
	tutorial_request_resolved.emit(TUTORIAL_REQUEST_RESTART, accepted)


func _unbind_client_port() -> void:
	if _client_port == null:
		return
	_disconnect_if_connected(_client_port.session_state_changed, _on_session_state_changed)
	_disconnect_if_connected(_client_port.player_view_updated, _on_player_view_updated)
	_disconnect_if_connected(_client_port.visible_events_received, _on_visible_events_received)
	_disconnect_if_connected(_client_port.visible_error_received, _on_visible_error_received)
	_disconnect_if_connected(_client_port.action_previews_updated, _on_action_previews_updated)
	_disconnect_if_connected(_client_port.prepared_action_changed, _on_prepared_action_changed)
	_client_port = null
	_tutorial_seat_verified = false


func _is_tutorial_session_authorized() -> bool:
	return trusted_tutorial_scenario == null \
		or (trusted_tutorial_scenario.is_valid_definition() and _tutorial_seat_verified)


func _is_preview_authorized(preview_id: String) -> bool:
	return trusted_tutorial_scenario == null \
		or (_is_tutorial_session_authorized() \
			and trusted_tutorial_scenario.allows_preview(preview_id))


func _is_skip_authorized() -> bool:
	return trusted_tutorial_scenario == null \
		or (_is_tutorial_session_authorized() and trusted_tutorial_scenario.allows_skip())


func _is_restart_authorized() -> bool:
	return trusted_tutorial_scenario == null \
		or (_is_tutorial_session_authorized() and trusted_tutorial_scenario.allows_restart())


func _disconnect_if_connected(source_signal: Signal, callable: Callable) -> void:
	if source_signal.is_connected(callable):
		source_signal.disconnect(callable)


func _on_session_state_changed(public_state: Dictionary) -> void:
	if not _is_tutorial_session_authorized():
		return
	session_state_changed.emit(public_state.duplicate(true))


func _on_player_view_updated(view: Dictionary) -> void:
	if trusted_tutorial_scenario != null:
		_tutorial_seat_verified = trusted_tutorial_scenario.is_valid_definition() \
			and str(view.get("viewer_side", "")) == trusted_tutorial_scenario.bound_seat
		if not _tutorial_seat_verified:
			return
	player_view_updated.emit(view.duplicate(true))


func _on_visible_events_received(events: Array) -> void:
	if not _is_tutorial_session_authorized():
		return
	visible_events_received.emit(events.duplicate(true))


func _on_visible_error_received(error: Dictionary) -> void:
	if not _is_tutorial_session_authorized():
		return
	visible_error_received.emit(error.duplicate(true))


func _on_action_previews_updated(previews: Array) -> void:
	if not _is_tutorial_session_authorized():
		return
	action_previews_updated.emit(previews.duplicate(true))


func _on_prepared_action_changed(preview_id: String) -> void:
	if not _is_tutorial_session_authorized():
		return
	prepared_action_changed.emit(preview_id)
