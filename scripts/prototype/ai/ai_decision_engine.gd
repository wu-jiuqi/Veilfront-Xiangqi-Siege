extends RefCounted

const Canonical = preload("res://scripts/prototype/ai/ai_canonical.gd")
const PlayerView = preload("res://scripts/prototype/ai/ai_player_view.gd")
const PublicRules = preload("res://scripts/prototype/ai/ai_public_rules.gd")
const Memory = preload("res://scripts/prototype/ai/ai_memory.gd")
const DifficultyConfig = preload("res://scripts/prototype/ai/ai_difficulty_config.gd")
const VisibleTacticalEvaluator = preload("res://scripts/prototype/ai/ai_visible_tactical_evaluator.gd")


func decide(
	player_view: PlayerView,
	public_rules: PublicRules,
	memory: Memory,
	ai_seed: int,
	config: DifficultyConfig
) -> Dictionary:
	var errors: Array[String] = []
	if not player_view.is_valid():
		errors.append_array(player_view.get_validation_errors())
	if not public_rules.is_valid():
		errors.append_array(public_rules.get_validation_errors())
	if not memory.is_valid():
		errors.append_array(memory.get_validation_errors())
	if config.conclusion_status != "hypothesis":
		errors.append("prototype AI config must remain marked hypothesis")
	if not errors.is_empty():
		return {"ok": false, "error_code": "invalid_ai_input", "errors": errors}

	var actions: Array[Dictionary] = player_view.get_legal_actions()
	for action: Dictionary in actions:
		if not public_rules.board_contains(action.origin) or not public_rules.board_contains(action.target):
			return {
				"ok": false,
				"error_code": "invalid_public_action_coordinate",
				"errors": ["legal action coordinates exceed the public board bounds"],
			}
	if actions.is_empty():
		return _no_action_result(player_view, public_rules, memory, ai_seed, config)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = ai_seed
	var sampling_audit: Array[Dictionary] = []
	var sampled_actions: Array[Dictionary] = _sample_candidates(
		actions, mini(config.candidate_limit, actions.size()), rng, sampling_audit
	)
	var candidate_audit: Array[Dictionary] = []
	var best_action: Dictionary = {}
	var best_score: int = -2147483648
	var player_data: Dictionary = player_view.to_canonical_data()
	for action: Dictionary in sampled_actions:
		var base_score: int = _score(action, public_rules, memory, config)
		var strategic_result: Dictionary = VisibleTacticalEvaluator.evaluate(
			action, player_data, public_rules, config
		)
		var strategic_adjustment: int = int(strategic_result.get("adjustment", 0))
		var random_adjustment: int = rng.randi_range(-config.random_score_span, config.random_score_span)
		var final_score: int = base_score + strategic_adjustment + random_adjustment
		candidate_audit.append({
			"action_id": action.id,
			"base_score": base_score,
			"strategic_adjustment": strategic_adjustment,
			"strategic_breakdown": strategic_result.get("breakdown", {}).duplicate(true),
			"random_adjustment": random_adjustment,
			"final_score": final_score,
		})
		if best_action.is_empty() or final_score > best_score \
			or (final_score == best_score and action.id < best_action.id):
			best_action = action
			best_score = final_score

	var input_summary: Dictionary = player_view.input_summary()
	var audit: Dictionary = {
		"audit_schema_version": "ai-decision-audit-v1",
		"input_projection_summary": input_summary,
		"public_rules_digest": public_rules.digest(),
		"memory_summary": {"digest": memory.digest(), "entry_count": memory.entry_count()},
		"decision_input_digest": Canonical.digest({
			"player_view": input_summary.projection_digest,
			"public_rules": public_rules.digest(),
			"memory": memory.digest(),
			"ai_seed": ai_seed,
			"config": config.audit_snapshot(),
		}),
		"budget": {
			"candidate_limit_hypothesis": config.candidate_limit,
			"time_budget_ms_hint_hypothesis": config.time_budget_ms_hint,
			"time_budget_enforcement": "not_wall_clock_in_deterministic_prototype",
			"available_candidates": actions.size(),
			"evaluated_candidates": sampled_actions.size(),
			"strategy_mode_hypothesis": str(config.strategy_mode),
		},
		"candidate_sampling": {"ai_seed": ai_seed, "draws": sampling_audit},
		"candidates": candidate_audit,
		"random_sampling": {
			"score_span_hypothesis": config.random_score_span,
			"candidate_score_draw_count": candidate_audit.size(),
		},
		"final_action": {"action_id": best_action.id, "final_score": best_score},
		"profile": config.audit_snapshot(),
	}
	return {"ok": true, "action": best_action.duplicate(true), "audit": audit}


func _sample_candidates(
	actions: Array[Dictionary],
	count: int,
	rng: RandomNumberGenerator,
	audit: Array[Dictionary]
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = actions.duplicate(true)
	var result: Array[Dictionary] = []
	for index: int in count:
		var selected_index: int = rng.randi_range(index, pool.size() - 1)
		audit.append({
			"draw_index": index,
			"range_start": index,
			"range_end": pool.size() - 1,
			"selected_index": selected_index,
		})
		var temporary: Dictionary = pool[index]
		pool[index] = pool[selected_index]
		pool[selected_index] = temporary
		result.append(pool[index])
	return result


func _score(
	action: Dictionary,
	public_rules: PublicRules,
	memory: Memory,
	config: DifficultyConfig
) -> int:
	var score: int = public_rules.action_bias(action.kind)
	for capture: Dictionary in action.visible_captures:
		score += public_rules.piece_value(capture.piece_type)
	score += action.reveal_cell_count * config.reveal_weight
	if action.occupies_flag:
		score += config.flag_weight
	if action.attacks_wall:
		score += config.wall_pressure_weight
	score -= memory.action_visit_count(action.id) * config.revisit_penalty
	return score


func _no_action_result(
	player_view: PlayerView,
	public_rules: PublicRules,
	memory: Memory,
	ai_seed: int,
	config: DifficultyConfig
) -> Dictionary:
	var input_summary: Dictionary = player_view.input_summary()
	return {
		"ok": true,
		"action": {},
		"audit": {
			"audit_schema_version": "ai-decision-audit-v1",
			"input_projection_summary": input_summary,
			"public_rules_digest": public_rules.digest(),
			"memory_summary": {"digest": memory.digest(), "entry_count": memory.entry_count()},
			"decision_input_digest": Canonical.digest({
				"player_view": input_summary.projection_digest,
				"public_rules": public_rules.digest(),
				"memory": memory.digest(),
				"ai_seed": ai_seed,
				"config": config.audit_snapshot(),
			}),
			"budget": {
				"candidate_limit_hypothesis": config.candidate_limit,
				"time_budget_ms_hint_hypothesis": config.time_budget_ms_hint,
				"time_budget_enforcement": "not_wall_clock_in_deterministic_prototype",
				"available_candidates": 0,
				"evaluated_candidates": 0,
				"strategy_mode_hypothesis": str(config.strategy_mode),
			},
			"candidate_sampling": {"ai_seed": ai_seed, "draws": []},
			"candidates": [],
			"random_sampling": {"score_span_hypothesis": config.random_score_span, "candidate_score_draw_count": 0},
			"final_action": {"action_id": "", "reason": "no_public_legal_action"},
			"profile": config.audit_snapshot(),
		},
	}
