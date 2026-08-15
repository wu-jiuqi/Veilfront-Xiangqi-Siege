extends SceneTree

const CoreCanonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const Projector = preload("res://scripts/prototype/view/player_view_projector.gd")
const AiPlayerView = preload("res://scripts/prototype/ai/ai_player_view.gd")
const PublicRules = preload("res://scripts/prototype/ai/ai_public_rules.gd")
const Memory = preload("res://scripts/prototype/ai/ai_memory.gd")
const DecisionEngine = preload("res://scripts/prototype/ai/ai_decision_engine.gd")
const DifficultyConfig = preload("res://scripts/prototype/ai/ai_difficulty_config.gd")
const AiSeedDeriver = preload("res://scripts/prototype/ai/ai_seed_deriver.gd")

const FULL_STATE_SEED: int = 80123
const MATCH_AI_SEED: int = 909001


func _initialize() -> void:
	var force_failure: bool = OS.get_cmdline_user_args().has("--force-failure")
	var result: Dictionary = run_suite(force_failure)
	if result.ok:
		print("AI_REAL_AUDIT_JSON=", CoreCanonical.json(result.evidence))
		print("AI fairness prototype tests passed")
		quit(0)
		return
	for failure: String in result.failures:
		push_error("AI FAIRNESS FAIL: %s" % failure)
	print("AI fairness prototype tests failed count=%d" % result.failures.size())
	quit(1)


static func run_suite(force_failure: bool = false) -> Dictionary:
	var failures: Array[String] = []
	var evidence: Dictionary = _test_real_hidden_equivalent_pair(failures)
	_test_real_projection_unknown_field_is_rejected(failures)
	_test_real_projection_collection_order_is_canonical(failures)
	_test_seed_derivation_is_independent_from_rule_rng(failures)
	_test_hypothesis_resources_load(failures)
	if force_failure:
		failures.append("deliberate negative-path sentinel")
	return {
		"ok": failures.is_empty(),
		"evidence": evidence,
		"failures": failures,
	}


static func _test_real_hidden_equivalent_pair(failures: Array[String]) -> Dictionary:
	var pair: Array[Dictionary] = _real_hidden_equivalent_pair()
	var full_state_a: Dictionary = pair[0]
	var full_state_b: Dictionary = pair[1]
	_check(
		CoreCanonical.digest(full_state_a) != CoreCanonical.digest(full_state_b),
		"black-box pair must contain genuinely different FullState values",
		failures
	)

	var player_view_a: Dictionary = Projector.project(full_state_a, MatchState.RED)
	var player_view_b: Dictionary = Projector.project(full_state_b, MatchState.RED)
	_check(
		CoreCanonical.digest(player_view_a) == CoreCanonical.digest(player_view_b),
		"hidden FullState differences changed the real PlayerView",
		failures
	)
	_check(
		not player_view_a.has("rng") and not player_view_a.has("board"),
		"real PlayerView exposed RNG or complete board",
		failures
	)

	var intents: Array = _public_intents()
	var preview_a: Array = Projector.list_action_intents(player_view_a, intents)
	var preview_b: Array = Projector.list_action_intents(player_view_b, intents)
	_check(preview_a == preview_b, "public action previews broke hidden equivalence", failures)
	_check(
		preview_a.any(func(preview: Dictionary) -> bool: return preview.classification == Projector.TENTATIVE),
		"real pair did not exercise a TENTATIVE public intent",
		failures
	)

	var projection_a: Dictionary = Projector.export_ai_projection(player_view_a, intents)
	var projection_b: Dictionary = Projector.export_ai_projection(player_view_b, intents)
	_check(
		CoreCanonical.digest(projection_a) == CoreCanonical.digest(projection_b),
		"real AI projections broke hidden equivalence",
		failures
	)
	var ai_view_a: RefCounted = AiPlayerView.new(projection_a)
	var ai_view_b: RefCounted = AiPlayerView.new(projection_b)
	if not _check(
		ai_view_a.is_valid() and ai_view_b.is_valid(),
		"real projector export did not satisfy the AI whitelist",
		failures
	):
		return {}

	var public_rules: RefCounted = PublicRules.new(_public_rules())
	var memory: RefCounted = Memory.new(_empty_memory())
	var config: Resource = DifficultyConfig.new()
	var decision_id: String = str(projection_a.get("decision_id", ""))
	var ai_seed: int = AiSeedDeriver.derive(MATCH_AI_SEED, decision_id)
	var result_a: Dictionary = DecisionEngine.new().decide(
		ai_view_a, public_rules, memory, ai_seed, config
	)
	var result_b: Dictionary = DecisionEngine.new().decide(
		ai_view_b, public_rules, memory, ai_seed, config
	)
	if not _check(
		bool(result_a.get("ok", false)) and bool(result_b.get("ok", false)),
		"real paired AI decision returned an error",
		failures
	):
		return {}
	_check(result_a.action == result_b.action, "hidden differences changed the AI action", failures)
	_check(
		result_a.audit.input_projection_summary == result_b.audit.input_projection_summary,
		"hidden differences changed the AI input summary",
		failures
	)
	_check(
		result_a.audit == result_b.audit,
		"hidden differences changed public AI audit fields",
		failures
	)

	return {
		"schema_version": "ai-real-player-view-paired-audit-v1",
		"fixture": {
			"full_state_seed": FULL_STATE_SEED,
			"viewer_side": MatchState.RED,
			"hidden_difference": [
				"black-pawn-1 position and hidden flag",
				"rule RNG internal state and unpublished records",
			],
			"full_state_digests_differ": true,
		},
		"real_player_view": {
			"schema_version": player_view_a.schema_version,
			"projection_digest": CoreCanonical.digest(player_view_a),
			"action_preview_digest": CoreCanonical.digest(preview_a),
			"ai_projection_digest": CoreCanonical.digest(projection_a),
		},
		"ai_seed_derivation": AiSeedDeriver.audit_record(MATCH_AI_SEED, decision_id),
		"selected_action": result_a.action,
		"decision_audit": result_a.audit,
		"paired_equality": {
			"action": true,
			"input_projection_summary": true,
			"all_public_audit_fields": true,
		},
	}


static func _test_real_projection_unknown_field_is_rejected(failures: Array[String]) -> void:
	var state: Dictionary = MatchState.create(FULL_STATE_SEED)
	var player_view: Dictionary = Projector.project(state, MatchState.RED)
	var projection: Dictionary = Projector.export_ai_projection(player_view, _public_intents())
	projection["hidden_enemy_pieces"] = []
	var ai_view: RefCounted = AiPlayerView.new(projection)
	_check(not ai_view.is_valid(), "AI whitelist accepted an injected hidden field", failures)
	var result: Dictionary = DecisionEngine.new().decide(
		ai_view,
		PublicRules.new(_public_rules()),
		Memory.new(_empty_memory()),
		AiSeedDeriver.derive(MATCH_AI_SEED, "invalid-input-check"),
		DifficultyConfig.new()
	)
	_check(
		not bool(result.get("ok", true)) and result.get("error_code", "") == "invalid_ai_input",
		"decision engine did not reject an invalid real projection",
		failures
	)


static func _test_real_projection_collection_order_is_canonical(failures: Array[String]) -> void:
	var state: Dictionary = MatchState.create(FULL_STATE_SEED)
	MatchState.relocate_piece(state, "red-rook-1", Vector2i(1, 9))
	var player_view: Dictionary = Projector.project(state, MatchState.RED)
	var projection_a: Dictionary = Projector.export_ai_projection(player_view, _public_intents())
	var projection_b: Dictionary = projection_a.duplicate(true)
	projection_b.legal_actions.reverse()
	projection_b.visible_pieces.reverse()
	var ai_view_a: RefCounted = AiPlayerView.new(projection_a)
	var ai_view_b: RefCounted = AiPlayerView.new(projection_b)
	if not _check(
		ai_view_a.is_valid() and ai_view_b.is_valid(),
		"canonical-order fixtures were invalid",
		failures
	):
		return
	_check(
		ai_view_a.input_summary().projection_digest == ai_view_b.input_summary().projection_digest,
		"real export collection order changed projection digest",
		failures
	)
	var public_rules: RefCounted = PublicRules.new(_public_rules())
	var memory: RefCounted = Memory.new(_empty_memory())
	var config: Resource = DifficultyConfig.new()
	var ai_seed: int = AiSeedDeriver.derive(MATCH_AI_SEED, projection_a.decision_id)
	var result_a: Dictionary = DecisionEngine.new().decide(
		ai_view_a, public_rules, memory, ai_seed, config
	)
	var result_b: Dictionary = DecisionEngine.new().decide(
		ai_view_b, public_rules, memory, ai_seed, config
	)
	_check(
		bool(result_a.get("ok", false)) and bool(result_b.get("ok", false)),
		"canonical-order decisions returned an error",
		failures
	)
	if result_a.get("ok", false) and result_b.get("ok", false):
		_check(
			result_a.action == result_b.action,
			"real export serialization order changed the decision",
			failures
		)


static func _test_seed_derivation_is_independent_from_rule_rng(failures: Array[String]) -> void:
	var pair: Array[Dictionary] = _real_hidden_equivalent_pair()
	_check(pair[0].rng.state != pair[1].rng.state, "negative fixture lacks a rule RNG difference", failures)
	var decision_id: String = "turn-0-red"
	var seed_a: int = AiSeedDeriver.derive(MATCH_AI_SEED, decision_id)
	var seed_b: int = AiSeedDeriver.derive(MATCH_AI_SEED, decision_id)
	_check(seed_a == seed_b, "AI seed derivation is not deterministic", failures)
	var method: Dictionary = AiSeedDeriver.audit_record(MATCH_AI_SEED, decision_id)
	_check(method.forbidden_inputs.has("rule_rng"), "AI seed audit omits the forbidden rule RNG", failures)
	_check(
		not method.inputs.has("rule_rng") and not method.inputs.has("rule_rng_state"),
		"AI seed derivation accepted rule RNG input",
		failures
	)


static func _test_hypothesis_resources_load(failures: Array[String]) -> void:
	for path: String in [
		"res://resources/prototype/ai/prototype_low_budget_hypothesis.tres",
		"res://resources/prototype/ai/prototype_default_hypothesis.tres",
		"res://resources/prototype/ai/prototype_high_budget_hypothesis.tres",
	]:
		var config: Resource = ResourceLoader.load(path)
		if not _check(config != null, "AI prototype config failed to load: %s" % path, failures):
			continue
		_check(
			config.conclusion_status == "hypothesis",
			"AI prototype config is no longer marked hypothesis: %s" % path,
			failures
		)


static func _check(condition: bool, description: String, failures: Array[String]) -> bool:
	if not condition:
		failures.append(description)
	return condition


static func _real_hidden_equivalent_pair() -> Array[Dictionary]:
	var full_state_a: Dictionary = MatchState.create(FULL_STATE_SEED)
	var full_state_b: Dictionary = MatchState.clone(full_state_a)
	MatchState.relocate_piece(full_state_a, "red-rook-1", Vector2i(1, 9))
	MatchState.relocate_piece(full_state_b, "red-rook-1", Vector2i(1, 9))
	MatchState.relocate_piece(full_state_a, "black-pawn-1", Vector2i(1, 11))
	full_state_a.pieces["black-pawn-1"].hidden = true
	full_state_b.rng.state = int(full_state_b.rng.state) + 17
	full_state_b.rng.records.append({
		"draw_index": 999,
		"reason": "unpublished-test-only",
		"result": 2,
	})
	return [full_state_a, full_state_b]


static func _public_intents() -> Array:
	return [
		{
			"piece_id": "red-rook-1",
			"action_type": "move",
			"target_cell": [1, 12],
			"skill_type": "",
		},
		{
			"piece_id": "red-rook-1",
			"action_type": "move",
			"target_cell": [2, 9],
			"skill_type": "",
		},
	]


static func _public_rules() -> Dictionary:
	return {
		"schema_version": "public-ai-rules-v1",
		"board_width": MatchState.BOARD_WIDTH,
		"board_height": MatchState.BOARD_HEIGHT,
		"piece_values": {"pawn": 10, "rook": 50, "general": 10000},
		"action_kind_bias": {"move": 0, "bombard": 4},
	}


static func _empty_memory() -> Dictionary:
	return {
		"schema_version": "ai-memory-v1",
		"recent_action_ids": [],
		"action_visit_counts": {},
		"last_visible_piece_turns": {},
	}
