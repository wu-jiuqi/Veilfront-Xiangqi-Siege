extends Control

const FormalLocalSession = preload("res://scripts/game/application/formal_local_session.gd")

@export var session_seed: int = 471001
@export var bootstrap_local_session: bool = true

var _local_session: RefCounted
var _local_port: RefCounted


func _ready() -> void:
	if bootstrap_local_session:
		_bootstrap_local_session()


func _bootstrap_local_session() -> void:
	_local_session = FormalLocalSession.create(
		session_seed,
		{"full_round_limit_hypothesis": 50}
	)
	_local_port = _local_session.create_client_port("red")
	var host: ApplicationHost = $ApplicationHost
	if not host.bind_client_port(_local_port):
		push_error("TutorialLevel failed to bind FormalLocalSession")
		return
	var publish_result: Dictionary = _local_port.publish_current()
	if not bool(publish_result.get("ok", false)):
		push_error("TutorialLevel failed to publish initial PlayerView: %s" % str(publish_result))
