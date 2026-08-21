extends SceneTree

const SESSION_SCENE: PackedScene = preload("res://scenes/game/network/formal_lan_session.tscn")
const FormalMatchApplication = preload("res://scripts/game/application/formal_match_application.gd")
const FormalLanProtocol = preload("res://scripts/game/contracts/formal_lan_protocol.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var session: Node = SESSION_SCENE.instantiate()
	root.add_child(session)
	await process_frame
	var port: RefCounted = session.create_client_port()
	var application: RefCounted = FormalMatchApplication.create_authoritative(471221, {})
	var encoded: Dictionary = FormalLanProtocol.encode_observer_batch(
		"red", application.current_payload_for_side("red"), 1
	)
	_expect(bool(encoded.get("ok", false)), "security fixture observer batch encodes")
	var batch_bytes := str(encoded.get("bytes", ""))
	_expect(bool(port._publish_encoded_batch(batch_bytes).get("ok", false)), "first coherent observer frame is accepted")
	_expect(port._last_frame_sequence == 1 and port._bound_side == "red", "observer port binds seat and monotonic frame sequence")

	var replay_result: Dictionary = port._publish_encoded_batch(batch_bytes)
	_expect(not bool(replay_result.get("ok", false)), "replayed observer frame is rejected")
	_expect(str(session.get_public_state_snapshot().get("state", "")) == "protocol_error", "observer replay aborts the session")

	session.disconnect_from_game()
	_expect(session.create_client_port() == port, "session keeps a stable port object across lobby reset")
	_expect(port._bound_side.is_empty() and port._last_frame_sequence == 0 \
		and port._current_action_index == -1, "disconnect resets port seat and sequence state")

	port._bound_side = "red"
	port._last_frame_sequence = 1
	port._current_action_index = 2
	var rollback_batch: Dictionary = FormalLanProtocol.encode_observer_batch(
		"red", application.current_payload_for_side("red"), 2
	)
	var rollback_result: Dictionary = port._publish_encoded_batch(str(rollback_batch.get("bytes", "")))
	_expect(not bool(rollback_result.get("ok", false)), "action-index rollback is rejected")
	_expect(str(session.get_public_state_snapshot().get("error_code", "")) == "observer_action_index_rollback", "rollback publishes a safe protocol error")

	session.disconnect_from_game()
	var invalid_result: Dictionary = port._publish_encoded_batch("{not-json")
	_expect(not bool(invalid_result.get("ok", false)), "malformed observer bytes are rejected")
	_expect(str(session.get_public_state_snapshot().get("state", "")) == "protocol_error", "malformed observer bytes close the session")

	session.disconnect_from_game()
	var raw_batch: PackedByteArray = batch_bytes.to_utf8_buffer()
	var compressed_batch: PackedByteArray = raw_batch.compress(FileAccess.COMPRESSION_DEFLATE)
	_expect(compressed_batch.size() < raw_batch.size(), "observer transport compresses the canonical batch")
	session._receive_observer_batch(compressed_batch, raw_batch.size())
	_expect(port._last_frame_sequence == 1 and port._bound_side == "red", "compressed observer transport restores and validates the canonical frame")

	session.disconnect_from_game()
	session._receive_observer_batch(PackedByteArray([1]), 4 * 1024 * 1024 + 1)
	_expect(str(session.get_public_state_snapshot().get("error_code", "")) == "observer_transport_invalid", "observer transport rejects declared payloads above the allocation bound")

	session.disconnect_from_game()
	session._role = "host"
	session._local_seat = "red"
	session._assign_peer(1, "red")
	_expect(not bool(session.set_ready(true).get("ok", false)), "host cannot ready before the remote seat exists")
	session._assign_peer(2, "black")
	session._ready_by_side = {"red": true, "black": true}
	var host_state: Dictionary = session._base_public_state("lobby", "host", "red", 1, "")
	var client_state: Dictionary = session._base_public_state("lobby", "client", "black", 2, "")
	_expect(bool(host_state.get("can_start", false)), "both-ready host receives can_start")
	_expect(not bool(client_state.get("can_start", true)), "client never receives start authority")

	session.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FORMAL_LAN_SECURITY_RECOVERY_PASS replay=blocked rollback=blocked role_reset=true compression=bounded")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FORMAL_LAN_SECURITY_RECOVERY_FAIL failures=%d" % _failures.size())
	quit(1)
