class_name ApplicationHost
extends Node

signal session_state_changed(public_state: Dictionary)
signal player_view_updated(view: Dictionary)
signal visible_events_received(events: Array)
signal visible_error_received(error: Dictionary)
signal action_previews_updated(previews: Array)
signal prepared_action_changed(preview_id: String)
signal binding_changed(is_bound: bool)

@export var trusted_tutorial_scenario: TutorialScenarioDefinition

var _client_port: MatchClientPort


func _exit_tree() -> void:
	_unbind_client_port()


func bind_client_port(client_port: MatchClientPort) -> bool:
	if client_port == null:
		return false
	_unbind_client_port()
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
	if _client_port != null:
		_client_port.prepare_action(preview_id)


func confirm_prepared_action(preview_id: String) -> void:
	if _client_port != null:
		_client_port.confirm_prepared_action(preview_id)


func cancel_prepared_action() -> void:
	if _client_port != null:
		_client_port.cancel_prepared_action()


func request_skip() -> void:
	if _client_port != null:
		_client_port.request_skip()


func request_restart() -> void:
	if _client_port != null:
		_client_port.request_restart()


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


func _disconnect_if_connected(source_signal: Signal, callable: Callable) -> void:
	if source_signal.is_connected(callable):
		source_signal.disconnect(callable)


func _on_session_state_changed(public_state: Dictionary) -> void:
	session_state_changed.emit(public_state.duplicate(true))


func _on_player_view_updated(view: Dictionary) -> void:
	player_view_updated.emit(view.duplicate(true))


func _on_visible_events_received(events: Array) -> void:
	visible_events_received.emit(events.duplicate(true))


func _on_visible_error_received(error: Dictionary) -> void:
	visible_error_received.emit(error.duplicate(true))


func _on_action_previews_updated(previews: Array) -> void:
	action_previews_updated.emit(previews.duplicate(true))


func _on_prepared_action_changed(preview_id: String) -> void:
	prepared_action_changed.emit(preview_id)
