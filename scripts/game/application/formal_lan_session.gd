class_name FormalLanSession
extends Node

const FormalMatchApplication = preload(
	"res://scripts/game/application/formal_match_application.gd"
)
const FormalLanProtocol = preload("res://scripts/game/contracts/formal_lan_protocol.gd")
const ActionPreviewCodec = preload("res://scripts/game/contracts/action_preview_codec.gd")
const FormalLanClientPort = preload("res://scripts/game/ports/formal_lan_client_port.gd")

signal public_state_changed(public_state: Dictionary)
signal seat_assigned(seat: String)
signal observer_batch_received(encoded_batch: String)
signal action_feedback_received(feedback: Dictionary)
signal match_started(public_state: Dictionary)

const HOST_PEER_ID: int = 1
const RED: String = "red"
const BLACK: String = "black"

@export_range(1024, 65535, 1) var default_port: int = 27772
@export_range(1, 1, 1) var maximum_remote_clients: int = 1

var _enet_peer: ENetMultiplayerPeer
var _application: RefCounted
var _client_port: RefCounted
var _role: String = ""
var _local_seat: String = ""
var _connection_state: String = "disconnected"
var _endpoint: String = ""
var _error_code: String = ""
var _seed_value: int = 0
var _configuration: Dictionary = {}
var _match_started: bool = false
var _remote_seat_claimed: bool = false
var _request_counter: int = 0
var _peer_to_side: Dictionary = {}
var _side_to_peer: Dictionary = {}
var _ready_by_side: Dictionary = {RED: false, BLACK: false}
var _processed_action_requests: Dictionary = {}
var _frame_sequence_by_peer: Dictionary = {}
var _last_event_cursor_by_peer: Dictionary = {}
var _observer_batch_by_peer: Dictionary = {}
var _current_public_state: Dictionary = {}


func _ready() -> void:
	_current_public_state = _make_local_public_state()


func _exit_tree() -> void:
	_close_peer_only()


func host_new_game(
	port: int = -1,
	configuration: Dictionary = {}
) -> Dictionary:
	# Seed creation stays inside the authority boundary. Neither the public state,
	# client port nor any observer batch carries this value.
	var random_bytes: PackedByteArray = Crypto.new().generate_random_bytes(4)
	var generated_seed: int = 0
	for byte_value: int in random_bytes:
		generated_seed = (generated_seed << 8) | byte_value
	generated_seed &= 0x7fffffff
	if generated_seed == 0:
		generated_seed = 1
	return host_game(generated_seed, port, configuration)


func host_game(
	seed_value: int,
	port: int = -1,
	configuration: Dictionary = {}
) -> Dictionary:
	_reset_runtime()
	var effective_port: int = default_port if port <= 0 else port
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var create_error: Error = peer.create_server(effective_port, maximum_remote_clients)
	if create_error != OK:
		_connection_state = "connection_error"
		_error_code = "create_server_failed"
		_publish_local_state()
		return {
			"ok": false,
			"error_code": _error_code,
			"engine_error": int(create_error),
		}
	_enet_peer = peer
	_role = "host"
	_local_seat = RED
	_connection_state = "hosting"
	_endpoint = "0.0.0.0:%d" % effective_port
	_seed_value = seed_value
	_configuration = configuration.duplicate(true)
	_assign_peer(HOST_PEER_ID, RED)
	_connect_multiplayer_signals()
	multiplayer.multiplayer_peer = _enet_peer
	seat_assigned.emit(RED)
	_publish_local_state()
	return {
		"ok": true,
		"role": _role,
		"local_seat": _local_seat,
		"endpoint": _endpoint,
		"port": effective_port,
	}


func join_game(address: String, port: int = -1) -> Dictionary:
	_reset_runtime()
	var normalized_address: String = address.strip_edges()
	if normalized_address.is_empty():
		_connection_state = "connection_error"
		_error_code = "address_empty"
		_publish_local_state()
		return {"ok": false, "error_code": _error_code}
	var effective_port: int = default_port if port <= 0 else port
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var create_error: Error = peer.create_client(normalized_address, effective_port)
	if create_error != OK:
		_connection_state = "connection_error"
		_error_code = "create_client_failed"
		_publish_local_state()
		return {
			"ok": false,
			"error_code": _error_code,
			"engine_error": int(create_error),
		}
	_enet_peer = peer
	_role = "client"
	_connection_state = "connecting"
	_endpoint = "%s:%d" % [normalized_address, effective_port]
	_connect_multiplayer_signals()
	multiplayer.multiplayer_peer = _enet_peer
	_publish_local_state()
	return {
		"ok": true,
		"role": _role,
		"endpoint": _endpoint,
		"address": normalized_address,
		"port": effective_port,
	}


func disconnect_from_game() -> void:
	var previous_endpoint: String = _endpoint
	_reset_runtime()
	_endpoint = previous_endpoint
	_publish_local_state()


func create_client_port() -> RefCounted:
	if _client_port == null:
		_client_port = FormalLanClientPort.new(self)
	return _client_port


func get_public_state_snapshot() -> Dictionary:
	if _current_public_state.is_empty():
		_current_public_state = _make_local_public_state()
	return _current_public_state.duplicate(true)


func get_current_observer_batch_bytes() -> String:
	var local_peer_id: int = _local_peer_id()
	return str(_observer_batch_by_peer.get(local_peer_id, ""))


func get_local_seat() -> String:
	return _local_seat


func get_session_role() -> String:
	return _role


func is_match_started() -> bool:
	return _match_started


func has_authoritative_application() -> bool:
	return _role == "host" and _application != null


func set_ready(ready: bool = true) -> Dictionary:
	if _local_seat.is_empty() or _match_started:
		return {"ok": false, "error_code": "not_in_lobby"}
	var encoded: Dictionary = FormalLanProtocol.encode_control_request(
		_next_request_id("ready"), "ready", ready
	)
	if not bool(encoded.get("ok", false)):
		return {"ok": false, "error_code": "invalid_request"}
	if _role == "host":
		_process_control_request(HOST_PEER_ID, str(encoded.get("bytes", "")))
	else:
		_request_control.rpc_id(HOST_PEER_ID, str(encoded.get("bytes", "")))
	return {"ok": true, "ready": ready}


func start_match() -> Dictionary:
	if _role != "host":
		return {"ok": false, "error_code": "host_only"}
	var encoded: Dictionary = FormalLanProtocol.encode_control_request(
		_next_request_id("start"), "start", false
	)
	if not bool(encoded.get("ok", false)):
		return {"ok": false, "error_code": "invalid_request"}
	return _process_control_request(HOST_PEER_ID, str(encoded.get("bytes", "")))


func submit_preview(preview: Dictionary) -> Dictionary:
	var preview_check: Dictionary = ActionPreviewCodec.encode(preview)
	if not bool(preview_check.get("ok", false)):
		return {"ok": false, "error_code": "invalid_preview"}
	return _submit_action_intent(preview)


func submit_special_action(action_type: String) -> Dictionary:
	if action_type not in ["pass", "skip"]:
		return {"ok": false, "error_code": "invalid_action_type"}
	return _submit_action_intent({
		"piece_id": "",
		"action_type": action_type,
		"target_cell": [],
		"skill_type": "",
	})


func submit_timeout(expected_action_index: int) -> Dictionary:
	return _submit_action_intent({
		"piece_id": "",
		"action_type": "timeout",
		"target_cell": [],
		"skill_type": "",
	}, expected_action_index)


func report_local_error(error_code: String) -> void:
	_error_code = error_code
	_publish_local_state()


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_control(encoded_request: String) -> void:
	if not multiplayer.is_server():
		return
	_process_control_request(multiplayer.get_remote_sender_id(), encoded_request)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_action(encoded_request: String) -> void:
	if not multiplayer.is_server():
		return
	_process_action_request(multiplayer.get_remote_sender_id(), encoded_request)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_public_state(encoded_state: String) -> void:
	_apply_public_state_bytes(encoded_state)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_observer_batch(encoded_batch: String) -> void:
	_apply_observer_batch_bytes(encoded_batch)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_feedback(encoded_feedback: String) -> void:
	_apply_feedback_bytes(encoded_feedback)


func _process_control_request(peer_id: int, encoded_request: String) -> Dictionary:
	var decoded: Dictionary = FormalLanProtocol.decode_control_request(encoded_request)
	if not bool(decoded.get("ok", false)):
		if peer_id != HOST_PEER_ID:
			_send_public_state_to_peer(peer_id, "join_rejected", "protocol_version_mismatch")
		return {"ok": false, "error_code": "invalid_control_request"}
	var request: Dictionary = decoded.get("value", {})
	match str(request.get("command", "")):
		"join":
			return _register_remote_peer(peer_id)
		"ready":
			if not _peer_to_side.has(peer_id) or _match_started:
				return {"ok": false, "error_code": "not_in_lobby"}
			_ready_by_side[str(_peer_to_side[peer_id])] = bool(request.get("ready"))
			_error_code = ""
			_broadcast_public_state()
			return {"ok": true, "ready": bool(request.get("ready"))}
		"start":
			if peer_id != HOST_PEER_ID:
				return {"ok": false, "error_code": "host_only"}
			if not _can_start_match():
				_error_code = "players_not_ready"
				_broadcast_public_state()
				return {"ok": false, "error_code": _error_code}
			_start_authoritative_match()
			return {"ok": true}
	return {"ok": false, "error_code": "unsupported_control"}


func _register_remote_peer(peer_id: int) -> Dictionary:
	if peer_id <= HOST_PEER_ID:
		return {"ok": false, "error_code": "peer_id_invalid"}
	if _peer_to_side.has(peer_id):
		_send_public_state_to_peer(peer_id)
		return {"ok": true, "local_seat": str(_peer_to_side[peer_id]), "reused": true}
	if _side_to_peer.has(BLACK):
		_send_public_state_to_peer(peer_id, "join_rejected", "room_full")
		return {"ok": false, "error_code": "room_full"}
	if _remote_seat_claimed:
		_send_public_state_to_peer(peer_id, "join_rejected", "reconnect_not_supported")
		return {"ok": false, "error_code": "reconnect_not_supported"}
	_assign_peer(peer_id, BLACK)
	_remote_seat_claimed = true
	_connection_state = "lobby"
	_error_code = ""
	_broadcast_public_state()
	return {"ok": true, "local_seat": BLACK, "reused": false}


func _start_authoritative_match() -> void:
	_application = FormalMatchApplication.create_authoritative(
		_seed_value, _configuration
	)
	_match_started = _application != null
	_connection_state = "match" if _match_started else "protocol_error"
	_error_code = "" if _match_started else "authority_initialization_failed"
	_frame_sequence_by_peer.clear()
	_last_event_cursor_by_peer.clear()
	_observer_batch_by_peer.clear()
	_sync_public_match_fields()
	_broadcast_public_state()
	if not _match_started:
		return
	for peer_id: int in _seated_peer_ids():
		_deliver_payload_to_peer(
			peer_id,
			_application.current_payload_for_side(str(_peer_to_side[peer_id]))
		)
	match_started.emit(get_public_state_snapshot())


func _submit_action_intent(
	intent: Dictionary,
	expected_action_index: int = -1
) -> Dictionary:
	if not _match_started or _local_seat.is_empty():
		return {"ok": false, "error_code": "match_not_started"}
	var action_index: int = expected_action_index
	if action_index < 0:
		action_index = int(_current_public_state.get("action_index", -1))
	var request_id: String = _next_request_id("action")
	var encoded: Dictionary = FormalLanProtocol.encode_action_request(
		request_id, action_index, intent
	)
	if not bool(encoded.get("ok", false)):
		return {"ok": false, "error_code": "invalid_request"}
	var request_bytes: String = str(encoded.get("bytes", ""))
	if _role == "host":
		_process_action_request(HOST_PEER_ID, request_bytes)
	else:
		_request_action.rpc_id(HOST_PEER_ID, request_bytes)
	return {"ok": true, "request_id": request_id}


func _process_action_request(peer_id: int, encoded_request: String) -> void:
	if _application == null or not _match_started or not _peer_to_side.has(peer_id):
		_send_feedback(peer_id, FormalLanProtocol.build_feedback(
			"invalid-request", false, false, "match_not_started", _public_action_index()
		))
		return
	var decoded: Dictionary = FormalLanProtocol.decode_action_request(encoded_request)
	if not bool(decoded.get("ok", false)):
		_send_feedback(peer_id, FormalLanProtocol.build_feedback(
			"invalid-request", false, false, "invalid_request", _public_action_index()
		))
		return
	var request: Dictionary = decoded.get("value", {})
	var request_id: String = str(request.get("request_id", ""))
	var side: String = str(_peer_to_side[peer_id])
	if _request_was_processed(peer_id, request_id):
		var duplicate_payload: Dictionary = _application.reject_request_for_side(
			side, request_id, "invalid_request"
		)
		_deliver_payload_to_peer(peer_id, duplicate_payload)
		_send_feedback(peer_id, FormalLanProtocol.build_feedback(
			request_id, false, false, "duplicate_request", _public_action_index()
		))
		return
	_mark_request_processed(peer_id, request_id, int(request.get("expected_action_index", -1)))
	var result: Dictionary
	if str(request.get("action_type", "")) == "timeout":
		result = _application.submit_trusted_timeout_for_side(
			side, int(request.get("expected_action_index", -1))
		)
	else:
		result = _application.submit_intent_for_side(
			side, FormalLanProtocol.to_normalized_intent(request)
		)
	var consumed: bool = bool(result.get("consumed", false))
	_sync_public_match_fields()
	_broadcast_public_state()
	if consumed:
		for seated_peer_id: int in _seated_peer_ids():
			var seated_side: String = str(_peer_to_side[seated_peer_id])
			var payload: Dictionary = result if seated_side == side \
				else _application.current_payload_for_side(seated_side)
			_deliver_payload_to_peer(seated_peer_id, payload)
	else:
		_deliver_payload_to_peer(peer_id, result)
	var public_error: Dictionary = result.get("visible_error", {})
	var feedback_error: String = str(public_error.get("public_code", ""))
	if feedback_error == "stale_intent":
		feedback_error = "stale_action_index"
	elif feedback_error.is_empty() and not bool(result.get("ok", false)):
		feedback_error = str(result.get("error_code", "known_illegal"))
	_send_feedback(peer_id, FormalLanProtocol.build_feedback(
		request_id,
		bool(result.get("ok", false)),
		consumed,
		feedback_error,
		_public_action_index()
	))


func _deliver_payload_to_peer(peer_id: int, payload: Dictionary) -> void:
	if payload.is_empty() or not _peer_to_side.has(peer_id):
		return
	var player_view: Dictionary = payload.get("player_view", {})
	var cursor: int = int(player_view.get("visible_event_cursor", 0))
	var previous_cursor: int = int(_last_event_cursor_by_peer.get(peer_id, 0))
	if previous_cursor > cursor:
		previous_cursor = 0
	var delta_events: Array = []
	for event_value: Variant in payload.get("visible_events", []):
		if event_value is Dictionary \
		and int(event_value.get("visible_sequence", 0)) > previous_cursor:
			delta_events.append(event_value.duplicate(true))
	var safe_payload: Dictionary = payload.duplicate(true)
	safe_payload["visible_events"] = delta_events
	var next_sequence: int = int(_frame_sequence_by_peer.get(peer_id, 0)) + 1
	var encoded: Dictionary = FormalLanProtocol.encode_observer_batch(
		str(_peer_to_side[peer_id]), safe_payload, next_sequence
	)
	if not bool(encoded.get("ok", false)):
		_error_code = "observer_codec_rejected"
		_connection_state = "protocol_error"
		_broadcast_public_state()
		return
	var encoded_bytes: String = str(encoded.get("bytes", ""))
	_frame_sequence_by_peer[peer_id] = next_sequence
	_last_event_cursor_by_peer[peer_id] = cursor
	_observer_batch_by_peer[peer_id] = encoded_bytes
	if peer_id == HOST_PEER_ID:
		observer_batch_received.emit(encoded_bytes)
	else:
		_receive_observer_batch.rpc_id(peer_id, encoded_bytes)


func _apply_observer_batch_bytes(encoded_batch: String) -> void:
	var decoded: Dictionary = FormalLanProtocol.decode_observer_batch(encoded_batch)
	if not bool(decoded.get("ok", false)):
		_connection_state = "protocol_error"
		_error_code = "observer_batch_invalid"
		_publish_local_state()
		return
	var batch: Dictionary = decoded.get("value", {})
	if not _local_seat.is_empty() and str(batch.get("seat", "")) != _local_seat:
		_connection_state = "protocol_error"
		_error_code = "observer_seat_mismatch"
		_publish_local_state()
		return
	var local_peer_id: int = _local_peer_id()
	_observer_batch_by_peer[local_peer_id] = encoded_batch
	observer_batch_received.emit(encoded_batch)


func _send_feedback(peer_id: int, feedback: Dictionary) -> void:
	var encoded: Dictionary = FormalLanProtocol.encode_feedback(feedback)
	if not bool(encoded.get("ok", false)):
		return
	var encoded_bytes: String = str(encoded.get("bytes", ""))
	if peer_id == HOST_PEER_ID:
		_apply_feedback_bytes(encoded_bytes)
	elif _peer_to_side.has(peer_id):
		_receive_feedback.rpc_id(peer_id, encoded_bytes)


func _apply_feedback_bytes(encoded_feedback: String) -> void:
	var decoded: Dictionary = FormalLanProtocol.decode_feedback(encoded_feedback)
	if bool(decoded.get("ok", false)):
		action_feedback_received.emit(decoded.get("value", {}).duplicate(true))


func _broadcast_public_state() -> void:
	for peer_id: int in _seated_peer_ids():
		_send_public_state_to_peer(peer_id)


func _send_public_state_to_peer(
	peer_id: int,
	state_override: String = "",
	error_override: String = ""
) -> void:
	var state: Dictionary = _public_state_for_peer(peer_id, state_override, error_override)
	var encoded: Dictionary = FormalLanProtocol.encode_public_state(state)
	if not bool(encoded.get("ok", false)):
		return
	var encoded_bytes: String = str(encoded.get("bytes", ""))
	if peer_id == HOST_PEER_ID:
		_apply_public_state_bytes(encoded_bytes)
	else:
		_receive_public_state.rpc_id(peer_id, encoded_bytes)


func _publish_local_state() -> void:
	var state: Dictionary = _make_local_public_state()
	var encoded: Dictionary = FormalLanProtocol.encode_public_state(state)
	if not bool(encoded.get("ok", false)):
		return
	_apply_public_state_bytes(str(encoded.get("bytes", "")))


func _apply_public_state_bytes(encoded_state: String) -> void:
	var decoded: Dictionary = FormalLanProtocol.decode_public_state(encoded_state)
	if not bool(decoded.get("ok", false)):
		return
	var public_state: Dictionary = decoded.get("value", {}).duplicate(true)
	if _role == "client" and not _endpoint.is_empty():
		public_state["endpoint"] = _endpoint
	var previous_seat: String = _local_seat
	var previous_started: bool = _match_started
	_role = str(public_state.get("role", _role))
	_local_seat = str(public_state.get("local_seat", ""))
	_connection_state = str(public_state.get("state", _connection_state))
	_error_code = str(public_state.get("error_code", ""))
	_match_started = bool(public_state.get("match_started", false))
	_current_public_state = public_state
	if not _local_seat.is_empty() and _local_seat != previous_seat:
		seat_assigned.emit(_local_seat)
	public_state_changed.emit(public_state.duplicate(true))
	if _match_started and not previous_started:
		match_started.emit(public_state.duplicate(true))


func _public_state_for_peer(
	peer_id: int,
	state_override: String = "",
	error_override: String = ""
) -> Dictionary:
	var role: String = "host" if peer_id == HOST_PEER_ID else "client"
	var state_value: String = state_override
	if state_value.is_empty():
		state_value = "match" if _match_started else (
			"lobby" if _peer_to_side.has(peer_id) and _side_to_peer.has(BLACK) \
			else _connection_state
		)
	return _base_public_state(
		state_value,
		role,
		str(_peer_to_side.get(peer_id, "")),
		peer_id,
		error_override if not error_override.is_empty() else _error_code
	)


func _make_local_public_state() -> Dictionary:
	return _base_public_state(
		_connection_state,
		_role,
		_local_seat,
		_local_peer_id(),
		_error_code
	)


func _base_public_state(
	state_value: String,
	role_value: String,
	seat_value: String,
	peer_id: int,
	error_value: String
) -> Dictionary:
	return {
		"schema_version": FormalLanProtocol.PUBLIC_STATE_SCHEMA,
		"protocol_version": FormalLanProtocol.PROTOCOL_VERSION,
		"state": state_value,
		"role": role_value,
		"local_seat": seat_value,
		"local_peer_id": maxi(0, peer_id),
		"host_peer_id": HOST_PEER_ID,
		"endpoint": _endpoint,
		"peer_connected": _side_to_peer.has(RED) and _side_to_peer.has(BLACK),
		"red_ready": bool(_ready_by_side.get(RED, false)),
		"black_ready": bool(_ready_by_side.get(BLACK, false)),
		"can_start": _can_start_match(),
		"match_started": _match_started,
		"action_index": _public_action_index(),
		"active_side": _public_active_side(),
		"terminal": _public_terminal(),
		"error_code": error_value,
	}


func _sync_public_match_fields() -> void:
	# Public match fields are derived only from red's observer-safe PlayerView.
	# They are common public facts and never expose the authority state object.
	if _application == null:
		return
	var view: Dictionary = _application.current_player_view_for_side(RED)
	_current_public_state["action_index"] = int(view.get("action_index", 0))
	_current_public_state["active_side"] = str(view.get("active_side", ""))
	_current_public_state["terminal"] = bool(view.get("terminal", false))


func _public_action_index() -> int:
	if _application == null:
		return int(_current_public_state.get("action_index", 0))
	return int(_application.current_player_view_for_side(RED).get("action_index", 0))


func _public_active_side() -> String:
	if _application == null:
		return str(_current_public_state.get("active_side", ""))
	return str(_application.current_player_view_for_side(RED).get("active_side", ""))


func _public_terminal() -> bool:
	if _application == null:
		return bool(_current_public_state.get("terminal", false))
	return bool(_application.current_player_view_for_side(RED).get("terminal", false))


func _can_start_match() -> bool:
	return not _match_started \
		and _side_to_peer.has(RED) and _side_to_peer.has(BLACK) \
		and bool(_ready_by_side.get(RED, false)) \
		and bool(_ready_by_side.get(BLACK, false))


func _assign_peer(peer_id: int, side: String) -> void:
	_peer_to_side[peer_id] = side
	_side_to_peer[side] = peer_id
	_processed_action_requests[peer_id] = {}
	_frame_sequence_by_peer[peer_id] = 0
	_last_event_cursor_by_peer[peer_id] = 0


func _seated_peer_ids() -> Array[int]:
	var result: Array[int] = []
	for peer_id_value: Variant in _peer_to_side.keys():
		result.append(int(peer_id_value))
	result.sort()
	return result


func _request_was_processed(peer_id: int, request_id: String) -> bool:
	return _processed_action_requests.get(peer_id, {}).has(request_id)


func _mark_request_processed(peer_id: int, request_id: String, action_index: int) -> void:
	var requests: Dictionary = _processed_action_requests.get(peer_id, {})
	requests[request_id] = action_index
	# A normal match stays far below this cap, so every in-match request remains
	# deduplicated. The cap only bounds hostile unique-ID spam.
	while requests.size() > 4096:
		requests.erase(requests.keys()[0])
	_processed_action_requests[peer_id] = requests


func _next_request_id(kind: String) -> String:
	_request_counter += 1
	return "%s:%d:%d:%s" % [
		kind,
		maxi(0, _local_peer_id()),
		_request_counter,
		_local_seat if not _local_seat.is_empty() else "pending",
	]


func _local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()


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


func _on_peer_connected(_peer_id: int) -> void:
	if multiplayer.is_server():
		_publish_local_state()


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server() or not _peer_to_side.has(peer_id):
		return
	var side: String = str(_peer_to_side[peer_id])
	if side == RED:
		return
	_peer_to_side.erase(peer_id)
	_side_to_peer.erase(side)
	_ready_by_side[side] = false
	_processed_action_requests.erase(peer_id)
	_frame_sequence_by_peer.erase(peer_id)
	_last_event_cursor_by_peer.erase(peer_id)
	_observer_batch_by_peer.erase(peer_id)
	_application = null
	_match_started = false
	_connection_state = "peer_disconnected"
	_error_code = "peer_disconnected"
	_publish_local_state()


func _on_connected_to_server() -> void:
	_connection_state = "connected_transport"
	_error_code = ""
	_publish_local_state()
	var encoded: Dictionary = FormalLanProtocol.encode_control_request(
		_next_request_id("join"), "join", false
	)
	if bool(encoded.get("ok", false)):
		_request_control.rpc_id(HOST_PEER_ID, str(encoded.get("bytes", "")))


func _on_connection_failed() -> void:
	_close_peer_only()
	_application = null
	_match_started = false
	_local_seat = ""
	_connection_state = "connection_failed"
	_error_code = "connection_failed"
	_publish_local_state()


func _on_server_disconnected() -> void:
	_close_peer_only()
	_application = null
	_match_started = false
	_local_seat = ""
	_connection_state = "server_disconnected"
	_error_code = "server_disconnected"
	_publish_local_state()


func _reset_runtime() -> void:
	_close_peer_only()
	_application = null
	_role = ""
	_local_seat = ""
	_connection_state = "disconnected"
	_endpoint = ""
	_error_code = ""
	_seed_value = 0
	_configuration.clear()
	_match_started = false
	_remote_seat_claimed = false
	_request_counter = 0
	_peer_to_side.clear()
	_side_to_peer.clear()
	_ready_by_side = {RED: false, BLACK: false}
	_processed_action_requests.clear()
	_frame_sequence_by_peer.clear()
	_last_event_cursor_by_peer.clear()
	_observer_batch_by_peer.clear()
	_current_public_state = _make_local_public_state()


func _close_peer_only() -> void:
	if _enet_peer != null:
		_enet_peer.close()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_enet_peer = null
