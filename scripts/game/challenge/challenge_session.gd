class_name ChallengeSession
extends RefCounted

const FormalMatchApplication = preload("res://scripts/game/application/formal_match_application.gd")
const FormalMatchClientPort = preload("res://scripts/game/ports/formal_match_client_port.gd")
const NormalizedIntentCodec = preload("res://scripts/game/domain/normalized_intent_codec.gd")
const ChallengeOpponentPolicy = preload("res://scripts/game/challenge/challenge_opponent_policy.gd")

var _definition: ChallengeDefinition
var _configuration: Dictionary = {}
var _application: RefCounted
var _opponent_policy: RefCounted


static func create(
	definition: ChallengeDefinition,
	configuration: Dictionary = {}
) -> RefCounted:
	if definition == null or not definition.is_valid_definition():
		return null
	var session := ChallengeSession.new()
	session._definition = definition
	session._configuration = configuration.duplicate(true)
	session._configuration["full_round_limit_hypothesis"] = definition.round_limit + 1
	session._opponent_policy = ChallengeOpponentPolicy.create(
		definition.opponent_policy_seed,
		definition.playable_max_y,
	)
	session._recreate_application()
	return session if session._application != null and session._opponent_policy != null else null


func create_client_port(bound_side: String = "red") -> RefCounted:
	if bound_side != "red":
		return null
	return FormalMatchClientPort.new(self, bound_side)


func current_payload() -> Dictionary:
	return _filter_payload(_application.current_payload())


func submit_preview(preview: Dictionary) -> Dictionary:
	var official := _official_preview(str(preview.get("preview_id", "")))
	if official.is_empty():
		return _public_failure("unavailable_preview")
	var result: Dictionary = _application.submit_intent(
		_intent_for_preview(official, "challenge-red")
	)
	return _filter_payload(result)


func submit_timeout(_expected_action_index: int) -> Dictionary:
	return _public_failure("challenge_timeout_disabled")


func should_auto_advance_opponent() -> bool:
	var view: Dictionary = current_payload().get("player_view", {})
	return not bool(view.get("terminal", false)) and str(view.get("active_side", "")) == "black"


func advance_scripted_opponent() -> Dictionary:
	var black_payload: Dictionary = _filter_payload(
		_application.current_payload_for_side("black")
	)
	var decision: Dictionary = _opponent_policy.choose_action(
		black_payload.get("player_view", {}),
		black_payload.get("action_previews", []),
	)
	if not bool(decision.get("ok", false)):
		return _public_failure(str(decision.get("error_code", "opponent_decision_failed")))
	var preview: Dictionary = decision.get("preview", {})
	var result: Dictionary = _application.submit_intent_for_side(
		"black",
		_intent_for_preview(preview, "challenge-black"),
	)
	var public_result: Dictionary = _filter_payload(_application.current_payload())
	public_result["ok"] = bool(result.get("ok", false))
	public_result["consumed"] = bool(result.get("consumed", false))
	return public_result


func restart() -> Dictionary:
	_recreate_application()
	return current_payload()


func _recreate_application() -> void:
	_application = FormalMatchApplication.create_authoritative_scenario(
		_definition,
		_definition.objective_configuration(),
		_configuration,
	)


func _official_preview(preview_id: String) -> Dictionary:
	for preview: Dictionary in current_payload().get("action_previews", []):
		if str(preview.get("preview_id", "")) == preview_id:
			return preview.duplicate(true)
	return {}


func _intent_for_preview(preview: Dictionary, prefix: String) -> Dictionary:
	var action_index: int = int(_application.current_action_index())
	return {
		"schema_version": NormalizedIntentCodec.SCHEMA_VERSION,
		"intent_id": "%s:%d:%s" % [prefix, action_index, str(preview.get("preview_id", ""))],
		"expected_action_index": action_index,
		"piece_id": str(preview.get("piece_id", "")),
		"action_type": str(preview.get("action_type", "")),
		"target_cell": preview.get("target_cell", []).duplicate(),
		"skill_type": str(preview.get("skill_type", "")),
		"confirmation_token": "",
	}


func _filter_payload(payload: Dictionary) -> Dictionary:
	var filtered := payload.duplicate(true)
	var action_previews: Array = []
	for preview_value: Variant in payload.get("action_previews", []):
		if not preview_value is Dictionary:
			continue
		var preview: Dictionary = preview_value
		var target: Array = preview.get("target_cell", [])
		if target.size() == 2 and int(target[1]) > _definition.playable_max_y:
			continue
		action_previews.append(preview.duplicate(true))
	filtered["action_previews"] = action_previews
	return filtered


func _public_failure(error_code: String) -> Dictionary:
	var result := current_payload()
	result["ok"] = false
	result["consumed"] = false
	result["error_code"] = error_code
	return result
