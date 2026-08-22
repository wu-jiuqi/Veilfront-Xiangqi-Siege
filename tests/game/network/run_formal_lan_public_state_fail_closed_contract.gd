extends SceneTree

class CodecFailureSession:
	extends FormalLanSession

	var publication_attempts: int = 0


	func _publish_local_state() -> void:
		publication_attempts += 1
		if publication_attempts == 1:
			abort_protocol_error("public_state_invalid")


var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var session: Node = CodecFailureSession.new()
	root.add_child(session)
	await process_frame
	var published_states: Array[Dictionary] = []
	session.public_state_changed.connect(
		func(public_state: Dictionary) -> void:
			published_states.append(public_state.duplicate(true))
	)

	session.abort_protocol_error("public_state_invalid")
	await process_frame

	var snapshot: Dictionary = session.get_public_state_snapshot()
	_expect(
		str(snapshot.get("state", "")) == "protocol_error",
		"invalid public state closes the session with protocol_error"
	)
	_expect(
		str(snapshot.get("error_code", "")) == "public_state_invalid",
		"invalid public state preserves its safe public error code"
	)
	_expect(
		published_states.size() == 1,
		"protocol failure publishes exactly one terminal state"
	)

	session.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FORMAL_LAN_PUBLIC_STATE_FAIL_CLOSED_PASS state=protocol_error emissions=1")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FORMAL_LAN_PUBLIC_STATE_FAIL_CLOSED_FAIL failures=%d" % _failures.size())
	quit(1)
