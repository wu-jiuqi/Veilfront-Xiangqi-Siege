extends SceneTree

const ChallengeCatalog = preload("res://scripts/game/challenge/challenge_catalog.gd")
const ChallengeOpponentPolicy = preload("res://scripts/game/challenge/challenge_opponent_policy.gd")
const FormalMatchApplication = preload("res://scripts/game/application/formal_match_application.gd")
const NormalizedIntentCodec = preload("res://scripts/game/domain/normalized_intent_codec.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition: Resource = ChallengeCatalog.definition("C3")
	var application: RefCounted = FormalMatchApplication.create_authoritative_scenario(
		definition,
		definition.objective_configuration(),
		{"full_round_limit_hypothesis": definition.round_limit + 1},
	)
	_expect(application != null, "authoritative challenge fixture could not be created")
	if application == null:
		_finish()
		return
	var red_payload: Dictionary = application.current_payload_for_side("red")
	var pass_preview: Dictionary = _find_action(red_payload.get("action_previews", []), "pass")
	var submit_result: Dictionary = application.submit_intent_for_side(
		"red",
		_intent(pass_preview, 0, "fairness-red-pass"),
	)
	_expect(bool(submit_result.get("consumed", false)), "red setup pass was not consumed")
	var black_payload: Dictionary = application.current_payload_for_side("black")
	var player_view: Dictionary = black_payload.get("player_view", {})
	var previews: Array = black_payload.get("action_previews", [])
	var first_policy: RefCounted = ChallengeOpponentPolicy.create(
		definition.opponent_policy_seed,
		definition.playable_max_y,
	)
	var second_policy: RefCounted = ChallengeOpponentPolicy.create(
		definition.opponent_policy_seed,
		definition.playable_max_y,
	)
	var first: Dictionary = first_policy.choose_action(player_view, previews)
	var second: Dictionary = second_policy.choose_action(
		player_view.duplicate(true),
		previews.duplicate(true),
	)
	_expect(bool(first.get("ok", false)), "policy rejected a valid black PlayerView")
	_expect(first == second, "same public input and seed must produce the same decision")
	_expect(str(first.get("preview", {}).get("action_type", "")) == "move", "challenge opponent must move when a legal move exists")
	_expect(
		int(first.get("preview", {}).get("target_cell", [0, 99])[1]) <= definition.playable_max_y,
		"challenge opponent selected a move beyond row 16",
	)

	for forbidden_field: String in ["seed", "rng_state", "full_state_digest", "undiscovered_flag_position"]:
		var injected := player_view.duplicate(true)
		injected[forbidden_field] = "authority-only"
		var rejected: Dictionary = first_policy.choose_action(injected, previews)
		_expect(
			not bool(rejected.get("ok", true)) \
			and str(rejected.get("error_code", "")) == "invalid_public_input",
			"policy accepted forbidden authority field %s" % forbidden_field,
		)
	_finish()


func _find_action(previews: Array, action_type: String) -> Dictionary:
	for preview: Dictionary in previews:
		if str(preview.get("action_type", "")) == action_type:
			return preview
	return {}


func _intent(preview: Dictionary, action_index: int, intent_id: String) -> Dictionary:
	return {
		"schema_version": NormalizedIntentCodec.SCHEMA_VERSION,
		"intent_id": intent_id,
		"expected_action_index": action_index,
		"piece_id": str(preview.get("piece_id", "")),
		"action_type": str(preview.get("action_type", "")),
		"target_cell": preview.get("target_cell", []).duplicate(),
		"skill_type": str(preview.get("skill_type", "")),
		"confirmation_token": "",
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CHALLENGE_OPPONENT_POLICY_CONTRACT_PASS deterministic=true public-only=true")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("CHALLENGE_OPPONENT_POLICY_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)
