extends Node

const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const PlayerViewProjector = preload("res://scripts/prototype/view/player_view_projector.gd")
const LanProtocol = preload("res://scripts/prototype/network/lan_protocol.gd")
const LanHostSession = preload("res://scripts/prototype/network/lan_host_session.gd")

signal connection_state_changed(snapshot: Dictionary)
signal seat_assigned(seat: String)
signal player_view_received(player_view: Dictionary)
signal action_feedback(feedback: Dictionary)

@export_range(1024, 65535, 1) var default_port: int = 27771
@export_range(1, 1, 1) var maximum_remote_clients: int = 1

var _enet_peer: ENetMultiplayerPeer
var _host_session: RefCounted
var _seat: String = ""
var _current_player_view: Dictionary = {}
var _connection_state: String = "disconnected"
var _request_counter: int = 0


func host_game(
	seed_value: int,
	port: int = -1,
	round_limit: int = MatchState.DEFAULT_FULL_ROUND_LIMIT_HYPOTHESIS
) -> Dictionary:
	disconnect_from_game()
	var effective_port: int = default_port if port <= 0 else port
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(effective_port, maximum_remote_clients)
	if error != OK:
		return _connection_error("create_server_failed", error)
	_enet_peer = peer
	_connect_multiplayer_signals()
	multiplayer.multiplayer_peer = _enet_peer
	_host_session = LanHostSession.new()
	var initialized: Dictionary = _host_session.initialize(seed_value, round_limit)
	if not bool(initialized.get("ok", false)):
		disconnect_from_game()
		return initialized
	_seat = MatchState.RED
	_set_connection_state("hosting", {"port": effective_port})
	seat_assigned.emit(_seat)
	_deliver_to_peer(LanHostSession.HOST_PEER_ID)
	return {"ok": true, "role": "host", "seat": _seat, "port": effective_port}


func join_game(address: String, port: int = -1) -> Dictionary:
	disconnect_from_game()
	var normalized_address: String = address.strip_edges()
	if normalized_address.is_empty():
		return {"ok": false, "error": "address_empty"}
	var effective_port: int = default_port if port <= 0 else port
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(normalized_address, effective_port)
	if error != OK:
		return _connection_error("create_client_failed", error)
	_enet_peer = peer
	_connect_multiplayer_signals()
	multiplayer.multiplayer_peer = _enet_peer
	_set_connection_state("connecting", {"address": normalized_address, "port": effective_port})
	return {"ok": true, "role": "client", "address": normalized_address, "port": effective_port}


func disconnect_from_game() -> void:
	if _enet_peer != null:
		_enet_peer.close()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_enet_peer = null
	_host_session = null
	_seat = ""
	_current_player_view = {}
	_request_counter = 0
	if _connection_state != "disconnected":
		_set_connection_state("disconnected")


func submit_intent(intent: Dictionary) -> Dictionary:
	if _seat.is_empty() or _current_player_view.is_empty():
		return {"ok": false, "error": "not_ready"}
	_request_counter += 1
	var request_id: String = "%d-%d" % [multiplayer.get_unique_id(), _request_counter]
	var request: Dictionary = LanProtocol.build_action_request(
		request_id,
		int(_current_player_view.get("action_index", -1)),
		intent
	)
	if multiplayer.is_server():
		_process_action_request(LanHostSession.HOST_PEER_ID, request)
	else:
		_request_action.rpc_id(LanHostSession.HOST_PEER_ID, request)
	return {"ok": true, "request_id": request_id}


func get_connection_snapshot() -> Dictionary:
	return {
		"schema_version": "lan-connection-snapshot-v1",
		"state": _connection_state,
		"seat": _seat,
		"peer_id": multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0,
	}


func get_player_view_snapshot() -> Dictionary:
	return _current_player_view.duplicate(true)


func get_action_previews() -> Array:
	if _current_player_view.is_empty():
		return []
	return PlayerViewProjector.generate_action_intents(_current_player_view).duplicate(true)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_join(protocol_version: int) -> void:
	if not multiplayer.is_server() or _host_session == null:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if protocol_version != LanProtocol.PROTOCOL_VERSION:
		_receive_join_rejection.rpc_id(sender_id, "protocol_version_mismatch")
		return
	var result: Dictionary = _host_session.register_remote_peer(sender_id)
	if not bool(result.get("ok", false)):
		_receive_join_rejection.rpc_id(sender_id, str(result.get("error", "join_rejected")))
		return
	_receive_seat.rpc_id(sender_id, str(result["seat"]))
	_deliver_to_peer(sender_id)
	_set_connection_state("hosting_connected", {"remote_peer_id": sender_id})


@rpc("authority", "call_remote", "reliable", 0)
func _receive_seat(seat: String) -> void:
	if seat not in [MatchState.RED, MatchState.BLACK]:
		_set_connection_state("protocol_error", {"error": "seat_invalid"})
		return
	_seat = seat
	seat_assigned.emit(_seat)
	_set_connection_state("connected", {"seat": _seat})


@rpc("authority", "call_remote", "reliable", 0)
func _receive_join_rejection(code: String) -> void:
	_set_connection_state("join_rejected", {"error": code})


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_action(request: Dictionary) -> void:
	if not multiplayer.is_server() or _host_session == null:
		return
	_process_action_request(multiplayer.get_remote_sender_id(), request)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_player_delivery(delivery: Dictionary) -> void:
	_apply_player_delivery(delivery)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_action_feedback(feedback: Dictionary) -> void:
	action_feedback.emit(feedback.duplicate(true))


func _process_action_request(peer_id: int, request: Dictionary) -> void:
	if _host_session == null:
		return
	var result: Dictionary = _host_session.submit_request(peer_id, request)
	_send_feedback(peer_id, result)
	if not bool(result.get("consumed", false)):
		return
	for seated_peer_id: int in _host_session.peer_ids():
		_deliver_to_peer(seated_peer_id)


func _deliver_to_peer(peer_id: int) -> void:
	if _host_session == null:
		return
	var delivery: Dictionary = _host_session.player_delivery_for_peer(peer_id)
	if delivery.is_empty():
		return
	if peer_id == LanHostSession.HOST_PEER_ID:
		_apply_player_delivery(delivery)
	else:
		_receive_player_delivery.rpc_id(peer_id, delivery)


func _apply_player_delivery(delivery: Dictionary) -> void:
	var validation: Dictionary = LanProtocol.validate_player_delivery(delivery)
	if not bool(validation.get("ok", false)):
		_set_connection_state("protocol_error", {
			"error": str(validation.get("error", "delivery_invalid")),
			"forbidden_path": str(validation.get("forbidden_path", "")),
		})
		return
	var validated_delivery: Dictionary = validation["delivery"]
	_seat = str(validated_delivery["seat"])
	_current_player_view = validated_delivery["player_view"].duplicate(true)
	player_view_received.emit(_current_player_view.duplicate(true))


func _send_feedback(peer_id: int, feedback: Dictionary) -> void:
	if peer_id == LanHostSession.HOST_PEER_ID:
		action_feedback.emit(feedback.duplicate(true))
	else:
		_receive_action_feedback.rpc_id(peer_id, feedback)


func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_set_connection_state("hosting_peer_connected", {"remote_peer_id": peer_id})


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server() and _host_session != null:
		_host_session.unregister_peer(peer_id)
		_set_connection_state("hosting", {"disconnected_peer_id": peer_id})


func _on_connected_to_server() -> void:
	_set_connection_state("connected_transport")
	_request_join.rpc_id(LanHostSession.HOST_PEER_ID, LanProtocol.PROTOCOL_VERSION)


func _on_connection_failed() -> void:
	_set_connection_state("connection_failed")
	_reset_failed_peer()


func _on_server_disconnected() -> void:
	_set_connection_state("server_disconnected")
	_reset_failed_peer()


func _reset_failed_peer() -> void:
	if _enet_peer != null:
		_enet_peer.close()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_enet_peer = null
	_seat = ""
	_current_player_view = {}


func _set_connection_state(state: String, details: Dictionary = {}) -> void:
	_connection_state = state
	var snapshot: Dictionary = get_connection_snapshot()
	snapshot["details"] = details.duplicate(true)
	connection_state_changed.emit(snapshot)


func _connection_error(code: String, error: Error) -> Dictionary:
	_set_connection_state("connection_error", {"error": code, "engine_error": int(error)})
	return {"ok": false, "error": code, "engine_error": int(error)}
