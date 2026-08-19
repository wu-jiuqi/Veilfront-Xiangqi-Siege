class_name FormalLocalSession
extends RefCounted

const FormalMatchApplication = preload("res://scripts/game/application/formal_match_application.gd")
const FormalMatchClientPort = preload("res://scripts/game/ports/formal_match_client_port.gd")

var _seed_value: int = 0
var _configuration: Dictionary = {}
var _application: RefCounted


static func create(seed_value: int, configuration: Dictionary = {}) -> RefCounted:
	var session: FormalLocalSession = new()
	session._seed_value = seed_value
	session._configuration = configuration.duplicate(true)
	session._recreate_application()
	return session


func create_client_port(bound_side: String = "red") -> RefCounted:
	return FormalMatchClientPort.new(self, bound_side)


func current_payload() -> Dictionary:
	return {
		"player_view": _application.current_player_view(),
		"visible_events": _application.current_visible_events(),
		"visible_error": {},
		"action_previews": _application.current_action_previews(),
	}


func submit_intent(intent: Dictionary) -> Dictionary:
	return _application.submit_intent(intent)


func restart() -> Dictionary:
	_recreate_application()
	return current_payload()


func _recreate_application() -> void:
	_application = FormalMatchApplication.create_trusted(
		_seed_value,
		"red",
		_configuration
	)
