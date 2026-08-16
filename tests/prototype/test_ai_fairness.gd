extends SceneTree

const CoreCanonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
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
	var paired_evidence: Dictionary = _test_real_hidden_equivalent_multi_decision_pair(failures)
	var full_match_evidence: Dictionary = _test_real_ai_completes_round_cap_match(failures)
	_test_real_projection_unknown_field_is_rejected(failures)
	_test_real_projection_collection_order_is_canonical(failures)
	_test_seed_derivation_is_independent_from_rule_rng(failures)
	_test_hypothesis_resources_load(failures)
	if force_failure:
		failures.append("deliberate negative-path sentinel")
	return {
		"ok": failures.is_empty(),
		"evidence": {
			"schema_version": "ai-revision-3-audit-evidence-v1",
			"hidden_equivalent_multi_decision": paired_evidence,
			"real_ai_round_cap_match": full_match_evidence,
		},
		"failures": failures,
	}


static func _test_real_hidden_equivalent_multi_decision_pair(failures: Array[String]) -> Dictionary:
	var pair: Array[Dictionary] = _real_hidden_equivalent_pair()
	var full_state_a: Dictionary = pair[0]
	var full_state_b: Dictionary = pair[1]
	_check(
		CoreCanonical.digest(full_state_a) != CoreCanonical.digest(full_state_b),
		"black-box pair must contain genuinely different FullState values",
		failures
	)

	var public_rules: RefCounted = PublicRules.new(_public_rules(true))
	var config: Resource = DifficultyConfig.new()
	config.profile_id = "prototype-paired-audit-hypothesis"
	config.candidate_limit = 1024
	var memory_data: Dictionary = _empty_memory()
	var decisions: Array = []
	for decision_index: int in 3:
		_check(full_state_a.active_side == MatchState.RED, "paired trace A is not at a red decision", failures)
		_check(full_state_b.active_side == MatchState.RED, "paired trace B is not at a red decision", failures)
		_check(
			full_state_a.rng.state != full_state_b.rng.state,
			"rule RNG difference disappeared before decision %d" % decision_index,
			failures
		)
		var player_view_a: Dictionary = Projector.project(full_state_a, MatchState.RED)
		var player_view_b: Dictionary = Projector.project(full_state_b, MatchState.RED)
		if not _check(
			CoreCanonical.digest(player_view_a) == CoreCanonical.digest(player_view_b),
			"hidden FullState differences changed PlayerView at decision %d" % decision_index,
			failures
		):
			break
		_check(
			not player_view_a.has("rng") and not player_view_a.has("board"),
			"real PlayerView exposed RNG or complete board",
			failures
		)
		var previews_a: Array = Projector.generate_action_intents(player_view_a)
		var previews_b: Array = Projector.generate_action_intents(player_view_b)
		_check(
			previews_a == previews_b,
			"final public candidate generator broke equivalence at decision %d" % decision_index,
			failures
		)
		if decision_index == 0:
			_check(
				previews_a.any(func(preview: Dictionary) -> bool: return preview.classification == Projector.TENTATIVE),
				"final generator did not expose a hidden-obstacle TENTATIVE candidate",
				failures
			)
		var projection_a: Dictionary = Projector.export_ai_projection_from_view(player_view_a)
		var projection_b: Dictionary = Projector.export_ai_projection_from_view(player_view_b)
		_check(
			CoreCanonical.digest(projection_a) == CoreCanonical.digest(projection_b),
			"real AI export broke equivalence at decision %d" % decision_index,
			failures
		)
		var ai_view_a: RefCounted = AiPlayerView.new(projection_a)
		var ai_view_b: RefCounted = AiPlayerView.new(projection_b)
		if not _check(
			ai_view_a.is_valid() and ai_view_b.is_valid(),
			"final projector export did not satisfy the AI whitelist",
			failures
		):
			break
		var memory_a: RefCounted = Memory.new(memory_data)
		var memory_b: RefCounted = Memory.new(memory_data)
		var decision_id: String = str(projection_a.get("decision_id", ""))
		var ai_seed: int = AiSeedDeriver.derive(MATCH_AI_SEED, decision_id)
		var result_a: Dictionary = DecisionEngine.new().decide(
			ai_view_a, public_rules, memory_a, ai_seed, config
		)
		var result_b: Dictionary = DecisionEngine.new().decide(
			ai_view_b, public_rules, memory_b, ai_seed, config
		)
		if not _check(
			bool(result_a.get("ok", false)) and bool(result_b.get("ok", false)),
			"paired AI decision returned an error at decision %d" % decision_index,
			failures
		):
			break
		_check(result_a.action == result_b.action, "hidden differences changed the AI action", failures)
		_check(
			result_a.audit.input_projection_summary == result_b.audit.input_projection_summary,
			"hidden differences changed the AI input summary",
			failures
		)
		_check(result_a.audit == result_b.audit, "hidden differences changed public AI audit", failures)
		if not _check(
			result_a.action.get("kind", "") == "pass",
			"paired audit policy must choose public pass to preserve pre-contact equivalence",
			failures
		):
			break
		decisions.append({
			"decision_index": decision_index,
			"action_index": player_view_a.action_index,
			"player_view_digest": CoreCanonical.digest(player_view_a),
			"generated_candidate_digest": CoreCanonical.digest(previews_a),
			"generated_candidate_count": previews_a.size(),
			"ai_projection_digest": CoreCanonical.digest(projection_a),
			"ai_seed_derivation": AiSeedDeriver.audit_record(MATCH_AI_SEED, decision_id),
			"selected_action": result_a.action,
			"decision_audit": result_a.audit,
			"paired_public_audit_equal": true,
		})
		var action_id: String = str(result_a.action.id)
		memory_data.recent_action_ids.append(action_id)
		memory_data.action_visit_counts[action_id] = int(memory_data.action_visit_counts.get(action_id, 0)) + 1
		var red_a: Dictionary = RuleEngine.submit_action(full_state_a, _pass_intent())
		var red_b: Dictionary = RuleEngine.submit_action(full_state_b, _pass_intent())
		var black_a: Dictionary = RuleEngine.submit_action(full_state_a, _pass_intent())
		var black_b: Dictionary = RuleEngine.submit_action(full_state_b, _pass_intent())
		_check(_consumed(red_a) and _consumed(red_b), "red pass failed during paired trace", failures)
		_check(_consumed(black_a) and _consumed(black_b), "black pass failed during paired trace", failures)

	return {
		"schema_version": "ai-real-player-view-multi-decision-audit-v1",
		"fixture": {
			"full_state_seed": FULL_STATE_SEED,
			"viewer_side": MatchState.RED,
			"hidden_difference": [
				"black-pawn-1 position and hidden flag",
				"rule RNG internal state and unpublished records",
			],
			"full_state_digests_differ": true,
			"decision_count": decisions.size(),
		},
		"decisions": decisions,
		"final_action_index": full_state_a.action_index,
		"rule_rng_states_still_differ": full_state_a.rng.state != full_state_b.rng.state,
		"paired_equality": {
			"all_decision_actions": decisions.size() == 3,
			"all_input_projection_summaries": decisions.size() == 3,
			"all_public_audit_fields": decisions.size() == 3,
		},
	}


static func _test_real_ai_completes_round_cap_match(failures: Array[String]) -> Dictionary:
	var rule_seed: int = 77231
	var match_ai_seed: int = 880021
	var round_cap_hypothesis: int = 3
	var state: Dictionary = RuleEngine.create_match(rule_seed, {
		"full_round_limit_hypothesis": round_cap_hypothesis,
	})
	var public_rules: RefCounted = PublicRules.new(_public_rules())
	var config_loaded: Resource = ResourceLoader.load(
		"res://resources/prototype/ai/prototype_default_hypothesis.tres"
	)
	if not _check(config_loaded != null, "default hypothesis config failed to load for real match", failures):
		return {}
	var config: Resource = config_loaded.duplicate(true)
	var memory_by_side: Dictionary = {
		MatchState.RED: _empty_memory(),
		MatchState.BLACK: _empty_memory(),
	}
	var decision_summaries: Array = []
	var guard_limit: int = round_cap_hypothesis * 2 + 2
	while not state.terminal and int(state.action_index) < guard_limit:
		var prepared: Dictionary = RuleEngine.prepare_action(state)
		if not _check(bool(prepared.get("ok", false)), "real AI match action preparation failed", failures):
			break
		var side: String = str(state.active_side)
		var player_view: Dictionary = Projector.project(state, side)
		var previews: Array = Projector.generate_action_intents(player_view)
		var projection: Dictionary = Projector.export_ai_projection_from_view(player_view)
		var ai_view: RefCounted = AiPlayerView.new(projection)
		if not _check(ai_view.is_valid(), "real AI match projection failed AI whitelist", failures):
			break
		var memory: RefCounted = Memory.new(memory_by_side[side])
		if not _check(memory.is_valid(), "real AI match memory became invalid", failures):
			break
		var decision_id: String = str(projection.decision_id)
		var ai_seed: int = AiSeedDeriver.derive(match_ai_seed, decision_id)
		var decision: Dictionary = DecisionEngine.new().decide(
			ai_view, public_rules, memory, ai_seed, config
		)
		if not _check(bool(decision.get("ok", false)), "real AI decision failed", failures):
			break
		var selected_id: String = str(decision.action.get("id", ""))
		var intent: Dictionary = _intent_for_public_action(previews, selected_id)
		if not _check(not intent.is_empty(), "selected AI action has no public intent", failures):
			break
		var submit: Dictionary = RuleEngine.submit_action(state, intent, {
			"preparation_token": prepared.preparation.token,
		})
		if not _check(_consumed(submit), "real AI selected intent was not consumed", failures):
			break
		var audit: Dictionary = decision.audit
		decision_summaries.append({
			"action_index": int(player_view.action_index),
			"side": side,
			"player_view_digest": CoreCanonical.digest(player_view),
			"generated_candidate_count": previews.size(),
			"generated_candidate_digest": CoreCanonical.digest(previews),
			"ai_projection_digest": CoreCanonical.digest(projection),
			"ai_seed_derivation": AiSeedDeriver.audit_record(match_ai_seed, decision_id),
			"input_projection_summary": audit.input_projection_summary,
			"memory_summary": audit.memory_summary,
			"budget": audit.budget,
			"candidate_records_digest": CoreCanonical.digest(audit.candidates),
			"candidate_sampling_digest": CoreCanonical.digest(audit.candidate_sampling),
			"random_sampling": audit.random_sampling,
			"final_action": audit.final_action,
			"complete_decision_audit_digest": CoreCanonical.digest(audit),
			"consumed_result_code": submit.event.outcome.result_code,
		})
		_update_memory_from_public_decision(
			memory_by_side[side], player_view, selected_id
		)
	_check(bool(state.terminal), "real AI match did not terminate", failures)
	_check(
		str(state.win_reason) in ["round_limit_flags", "round_limit_draw", "general_destroyed"],
		"real AI match ended with an unexpected reason",
		failures
	)
	_check(
		int(state.action_index) <= round_cap_hypothesis * 2,
		"real AI match exceeded configured round cap",
		failures
	)
	return {
		"schema_version": "ai-real-round-cap-match-audit-v1",
		"rule_seed": rule_seed,
		"match_ai_seed": match_ai_seed,
		"round_cap_status": "hypothesis_test_override",
		"full_round_limit_hypothesis": round_cap_hypothesis,
		"terminal": bool(state.terminal),
		"winner": str(state.winner),
		"win_reason": str(state.win_reason),
		"action_count": int(state.action_index),
		"full_round_count": int(state.full_round_index),
		"decision_count": decision_summaries.size(),
		"decision_audit_summaries": decision_summaries,
		"final_state_summary": MatchState.summary(state),
	}


static func _test_real_projection_unknown_field_is_rejected(failures: Array[String]) -> void:
	var state: Dictionary = MatchState.create(FULL_STATE_SEED)
	var player_view: Dictionary = Projector.project(state, MatchState.RED)
	var projection: Dictionary = Projector.export_ai_projection_from_view(player_view)
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
	var projection_a: Dictionary = Projector.export_ai_projection_from_view(player_view)
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
		"res://resources/prototype/ai/prototype_expert_tactical_hypothesis.tres",
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
	MatchState.relocate_piece(full_state_b, "black-pawn-1", Vector2i(2, 12))
	full_state_a.pieces["black-pawn-1"].hidden = true
	full_state_b.pieces["black-pawn-1"].hidden = true
	full_state_a.walls[MatchState.BLACK].status = "BREACHED"
	full_state_b.walls[MatchState.BLACK].status = "BREACHED"
	full_state_b.rng.state = int(full_state_b.rng.state) + 17
	full_state_b.rng.records.append({
		"draw_index": 999,
		"reason": "unpublished-test-only",
		"result": 2,
	})
	return [full_state_a, full_state_b]


static func _public_rules(force_pass_for_pair: bool = false) -> Dictionary:
	var pass_bias: int = 100000 if force_pass_for_pair else -100
	return {
		"schema_version": "public-ai-rules-v1",
		"board_width": MatchState.BOARD_WIDTH,
		"board_height": MatchState.BOARD_HEIGHT,
		"piece_values": {"pawn": 10, "rook": 50, "general": 10000},
		"action_kind_bias": {"move": 0, "bombard": 4, "pass": pass_bias},
	}


static func _empty_memory() -> Dictionary:
	return {
		"schema_version": "ai-memory-v1",
		"recent_action_ids": [],
		"action_visit_counts": {},
		"last_visible_piece_turns": {},
	}


static func _pass_intent() -> Dictionary:
	return {"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""}


static func _consumed(result: Dictionary) -> bool:
	return bool(result.get("ok", false)) and bool(result.get("consumed", false))


static func _intent_for_public_action(previews: Array, selected_action_id: String) -> Dictionary:
	for preview: Dictionary in previews:
		if str(preview.id) != selected_action_id or preview.classification == Projector.KNOWN_ILLEGAL:
			continue
		return {
			"piece_id": str(preview.piece_id),
			"action_type": str(preview.action_type),
			"target_cell": preview.target_cell.duplicate(),
			"skill_type": str(preview.skill_type),
		}
	return {}


static func _update_memory_from_public_decision(
	memory_data: Dictionary,
	player_view: Dictionary,
	selected_action_id: String
) -> void:
	memory_data.recent_action_ids.append(selected_action_id)
	if memory_data.recent_action_ids.size() > 8:
		memory_data.recent_action_ids.pop_front()
	memory_data.action_visit_counts[selected_action_id] = int(
		memory_data.action_visit_counts.get(selected_action_id, 0)
	) + 1
	for piece: Dictionary in player_view.pieces:
		if piece.side != player_view.viewer_side:
			memory_data.last_visible_piece_turns[str(piece.id)] = int(player_view.action_index)
