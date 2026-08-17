extends RefCounted

const Canonical = preload("res://scripts/prototype/ai/ai_canonical.gd")
const PlayerView = preload("res://scripts/prototype/ai/ai_player_view.gd")
const PublicRules = preload("res://scripts/prototype/ai/ai_public_rules.gd")
const Memory = preload("res://scripts/prototype/ai/ai_memory.gd")
const DifficultyConfig = preload("res://scripts/prototype/ai/ai_difficulty_config.gd")
const VisibleStateEvaluator = preload("res://scripts/prototype/ai/ai_visible_state_evaluator.gd")
const TwoPlySearch = preload("res://scripts/prototype/ai/ai_two_ply_search.gd")
const BeliefModel = preload("res://scripts/prototype/ai/ai_belief_model.gd")


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
	var player_data: Dictionary = player_view.to_canonical_data()
	var selection_metadata: Dictionary = {}
	var selected_actions: Array[Dictionary] = _select_candidates(
		actions,
		mini(config.candidate_limit, actions.size()),
		player_data,
		public_rules,
		memory,
		config,
		selection_metadata
	)
	var candidate_audit: Array[Dictionary] = []
	var best_action: Dictionary = {}
	var best_score: int = -2147483648
	var state_baseline: Dictionary = VisibleStateEvaluator.build_baseline(
		player_data, public_rules, config
	)
	var evaluated_entries: Array[Dictionary] = []
	for action: Dictionary in selected_actions:
		var base_score: int = _final_action_adjustment(action, public_rules, memory, config)
		var strategic_result: Dictionary = VisibleStateEvaluator.evaluate(
			action, player_data, public_rules, config, state_baseline
		)
		var strategic_adjustment: int = int(strategic_result.get("adjustment", 0))
		evaluated_entries.append({
			"action": action,
			"base_score": base_score,
			"strategic_adjustment": strategic_adjustment,
			"strategic_result": strategic_result,
			"one_ply_score": base_score + strategic_adjustment,
		})
	var search_ranked: Array = evaluated_entries.duplicate()
	search_ranked.sort_custom(_evaluated_entry_before)
	var search_action_ids: Dictionary = {}
	var search_limit: int = mini(int(config.search_candidate_limit), search_ranked.size())
	for index: int in search_limit:
		search_action_ids[str(search_ranked[index].action.id)] = true
	for action_id: String in selection_metadata.get("critical_reasons_by_action", {}).keys():
		search_action_ids[action_id] = true
	var belief_samples: Array = BeliefModel.build_samples(
		player_data, memory, public_rules, ai_seed, int(config.belief_sample_count)
	) if not search_action_ids.is_empty() else []
	for entry: Dictionary in evaluated_entries:
		var action: Dictionary = entry.action
		var searched: bool = search_action_ids.has(str(action.id))
		var search_result: Dictionary = TwoPlySearch.evaluate(
			action, player_data, memory, public_rules, config, ai_seed, belief_samples
		) if searched else {"adjustment": 0, "breakdown": {"mode": "not_searched"}}
		var search_adjustment: int = int(search_result.get("adjustment", 0))
		var random_adjustment: int = rng.randi_range(-config.random_score_span, config.random_score_span)
		var final_score: int = int(entry.one_ply_score) + search_adjustment + random_adjustment
		candidate_audit.append({
			"action_id": action.id,
			"pre_score": int(selection_metadata.get("pre_scores_by_action", {}).get(str(action.id), 0)),
			"base_score": int(entry.base_score),
			"strategic_adjustment": int(entry.strategic_adjustment),
			"strategic_breakdown": entry.strategic_result.get("breakdown", {}).duplicate(true),
			"one_ply_score": int(entry.one_ply_score),
			"searched": searched,
			"search_adjustment": search_adjustment,
			"search_breakdown": search_result.get("breakdown", {}).duplicate(true),
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
			"evaluated_candidates": selected_actions.size(),
			"searched_candidates": search_action_ids.size(),
			"search_candidate_limit_hypothesis": config.search_candidate_limit,
			"opponent_response_limit_hypothesis": config.opponent_response_limit,
			"belief_sample_count_hypothesis": config.belief_sample_count,
			"strategy_mode_hypothesis": str(config.strategy_mode),
		},
		"candidate_sampling": {
			"strategy": "strategic-top-k-v1",
			"randomized_before_scoring": false,
			"pre_scored_candidates": actions.size(),
			"critical_reasons_by_action": selection_metadata.get("critical_reasons_by_action", {}).duplicate(true),
			"draws": selection_metadata.get("draws", []).duplicate(true),
		},
		"candidates": candidate_audit,
		"random_sampling": {
			"score_span_hypothesis": config.random_score_span,
			"candidate_score_draw_count": candidate_audit.size(),
		},
		"final_action": {"action_id": best_action.id, "final_score": best_score},
		"profile": config.audit_snapshot(),
	}
	return {"ok": true, "action": best_action.duplicate(true), "audit": audit}


func _select_candidates(
	actions: Array[Dictionary],
	count: int,
	player_data: Dictionary,
	public_rules: PublicRules,
	memory: Memory,
	config: DifficultyConfig,
	metadata: Dictionary
) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	var critical_reasons_by_action: Dictionary = {}
	var current_general_attackers: int = VisibleStateEvaluator.general_visible_attacker_count(player_data)
	for action: Dictionary in actions:
		var action_id: String = str(action.id)
		var reasons: Array[String] = VisibleStateEvaluator.critical_reasons(
			action, player_data, public_rules, config, current_general_attackers
		)
		if not reasons.is_empty():
			critical_reasons_by_action[action_id] = reasons.duplicate()
		ranked.append({
			"action": action.duplicate(true),
			"action_id": action_id,
			"bucket": "%s|%s" % [str(action.kind), str(action.actor_id)],
			"pre_score": _pre_score(action, public_rules, memory, config),
			"critical": not reasons.is_empty(),
		})
	ranked.sort_custom(_ranked_candidate_before)
	var result: Array[Dictionary] = []
	var selected_action_ids: Dictionary = {}
	var draws: Array[Dictionary] = []
	var pre_scores_by_action: Dictionary = {}
	for entry: Dictionary in ranked:
		pre_scores_by_action[str(entry.action_id)] = int(entry.pre_score)
		if bool(entry.critical):
			_append_selected(entry, "critical", result, selected_action_ids, draws)
	var effective_limit: int = maxi(count, result.size())
	var bucket_best: Dictionary = {}
	for entry: Dictionary in ranked:
		if selected_action_ids.has(str(entry.action_id)) or bucket_best.has(str(entry.bucket)):
			continue
		bucket_best[str(entry.bucket)] = entry
	var bucket_representatives: Array = bucket_best.values()
	bucket_representatives.sort_custom(_ranked_candidate_before)
	for entry: Dictionary in bucket_representatives:
		if result.size() >= effective_limit:
			break
		_append_selected(entry, "actor_kind_best", result, selected_action_ids, draws)
	for entry: Dictionary in ranked:
		if result.size() >= effective_limit:
			break
		if selected_action_ids.has(str(entry.action_id)):
			continue
		_append_selected(entry, "global_top_k", result, selected_action_ids, draws)
	metadata["critical_reasons_by_action"] = critical_reasons_by_action
	metadata["pre_scores_by_action"] = pre_scores_by_action
	metadata["draws"] = draws
	return result


func _append_selected(
	entry: Dictionary,
	phase: String,
	result: Array[Dictionary],
	selected_action_ids: Dictionary,
	draws: Array[Dictionary]
) -> void:
	var action_id: String = str(entry.action_id)
	if selected_action_ids.has(action_id):
		return
	draws.append({
		"draw_index": result.size(),
		"phase": phase,
		"action_id": action_id,
		"bucket": str(entry.bucket),
		"pre_score": int(entry.pre_score),
	})
	result.append(entry.action.duplicate(true))
	selected_action_ids[action_id] = true


func _ranked_candidate_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.pre_score) != int(b.pre_score):
		return int(a.pre_score) > int(b.pre_score)
	return str(a.action_id) < str(b.action_id)


func _evaluated_entry_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.one_ply_score) != int(b.one_ply_score):
		return int(a.one_ply_score) > int(b.one_ply_score)
	return str(a.action.id) < str(b.action.id)


func _pre_score(
	action: Dictionary,
	public_rules: PublicRules,
	memory: Memory,
	config: DifficultyConfig
) -> int:
	var score: int = public_rules.action_bias(action.kind)
	for capture: Dictionary in action.visible_captures:
		score += public_rules.piece_value(capture.piece_type)
	score += mini(int(action.reveal_cell_count), int(config.vision_cell_cap)) \
		* int(config.reveal_weight)
	score += int(action.get("flag_vicinity_reveal_count", 0)) * int(config.flag_vision_weight)
	if action.occupies_flag:
		score += config.flag_capture_priority
	if action.attacks_wall:
		score += config.wall_pressure_weight
	score -= memory.action_visit_count(action.id) * config.revisit_penalty
	score -= memory.actor_visit_count(action.actor_id) * config.actor_revisit_penalty
	if str(action.kind) == "move" and not str(action.actor_id).is_empty() \
	and memory.actor_visit_count(action.actor_id) == 0:
		score += int(config.uncommitted_actor_bonus)
	return score


func _final_action_adjustment(
	action: Dictionary,
	public_rules: PublicRules,
	memory: Memory,
	config: DifficultyConfig
) -> int:
	var score: int = public_rules.action_bias(action.kind) \
		- memory.action_visit_count(action.id) * config.revisit_penalty \
		- memory.actor_visit_count(action.actor_id) * config.actor_revisit_penalty
	if str(action.kind) == "move" and not str(action.actor_id).is_empty() \
	and memory.actor_visit_count(action.actor_id) == 0:
		score += int(config.uncommitted_actor_bonus)
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
			"candidate_sampling": {
				"strategy": "strategic-top-k-v1",
				"randomized_before_scoring": false,
				"pre_scored_candidates": 0,
				"critical_reasons_by_action": {},
				"draws": [],
			},
			"candidates": [],
			"random_sampling": {"score_span_hypothesis": config.random_score_span, "candidate_score_draw_count": 0},
			"final_action": {"action_id": "", "reason": "no_public_legal_action"},
			"profile": config.audit_snapshot(),
		},
	}
