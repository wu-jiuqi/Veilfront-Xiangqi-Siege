class_name FormalLocalSession
extends RefCounted

const FormalMatchApplication = preload("res://scripts/game/application/formal_match_application.gd")
const FormalMatchClientPort = preload("res://scripts/game/ports/formal_match_client_port.gd")
const NormalizedIntentCodec = preload("res://scripts/game/domain/normalized_intent_codec.gd")

var _seed_value: int = 0
var _configuration: Dictionary = {}
var _application: RefCounted
var _scenario: TutorialScenarioDefinition


static func create(seed_value: int, configuration: Dictionary = {}) -> RefCounted:
	var session: FormalLocalSession = new()
	session._seed_value = seed_value
	session._configuration = configuration.duplicate(true)
	session._recreate_application()
	return session


static func create_tutorial(
	scenario: TutorialScenarioDefinition,
	configuration: Dictionary = {}
) -> RefCounted:
	if scenario == null or not scenario.is_valid_definition():
		return null
	var session: FormalLocalSession = new()
	session._seed_value = scenario.seed_value
	session._configuration = configuration.duplicate(true)
	session._scenario = scenario
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


func submit_preview(preview: Dictionary) -> Dictionary:
	var view: Dictionary = current_payload().get("player_view", {})
	var preview_id := str(preview.get("preview_id", ""))
	var intent: Dictionary = {
		"schema_version": NormalizedIntentCodec.SCHEMA_VERSION,
		"intent_id": "local:%d:%s" % [int(view.get("action_index", 0)), preview_id],
		"expected_action_index": int(view.get("action_index", 0)),
		"piece_id": str(preview.get("piece_id", "")),
		"action_type": str(preview.get("action_type", "")),
		"target_cell": preview.get("target_cell", []).duplicate(),
		"skill_type": str(preview.get("skill_type", "")),
		"confirmation_token": "",
	}
	return submit_intent(intent)


func should_auto_advance_opponent() -> bool:
	return _scenario != null or bool(_configuration.get("scripted_opponent_pass", false))


func advance_scripted_opponent() -> Dictionary:
	return _application.advance_trusted_scripted_pass()


func restart() -> Dictionary:
	_recreate_application()
	return current_payload()


func _recreate_application() -> void:
	if _scenario != null:
		_application = FormalMatchApplication.create_trusted_scenario(
			_scenario,
			_configuration
		)
	else:
		_application = FormalMatchApplication.create_trusted(
			_seed_value,
			"red",
			_configuration
		)
