extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const AiPlayerView = preload("res://scripts/prototype/ai/ai_player_view.gd")
const PublicRules = preload("res://scripts/prototype/ai/ai_public_rules.gd")
const Memory = preload("res://scripts/prototype/ai/ai_memory.gd")
const DifficultyConfig = preload("res://scripts/prototype/ai/ai_difficulty_config.gd")
const DecisionEngine = preload("res://scripts/prototype/ai/ai_decision_engine.gd")
const VisibleStateEvaluator = preload("res://scripts/prototype/ai/ai_visible_state_evaluator.gd")
const TwoPlySearch = preload("res://scripts/prototype/ai/ai_two_ply_search.gd")
const BeliefModel = preload("res://scripts/prototype/ai/ai_belief_model.gd")


static func run_suite() -> bool:
	var failures: Array[String] = []
	_test_priority_contract(failures)
	_test_hidden_flag_progress_scoring(failures)
	_test_advisor_resurrection_scoring(failures)
	_test_two_ply_avoids_recapture(failures)
	_test_belief_determinism(failures)
	for failure: String in failures:
		push_error("AI_TWO_PLY_BELIEF_FAIL: %s" % failure)
	return failures.is_empty()


static func _test_priority_contract(failures: Array[String]) -> void:
	var config: Resource = load("res://resources/prototype/ai/prototype_default_hypothesis.tres")
	_expect(
		int(config.general_safety_penalty) > int(config.flag_capture_priority),
		"保帅优先级略高于完成夺旗",
		failures
	)
	_expect(
		int(config.enemy_general_attack_priority) == int(config.flag_capture_priority),
		"进攻敌帅与完成夺旗同级",
		failures
	)


static func _test_hidden_flag_progress_scoring(failures: Array[String]) -> void:
	var config: Resource = load("res://resources/prototype/ai/prototype_default_hypothesis.tres")
	var rules := PublicRules.new(_rules())
	var player_data: Dictionary = _projection([], [])
	player_data.visible_pieces = [
		_piece("red-general-1", "red", "general", [4, 0]),
		_piece("red-rook-1", "red", "rook", [4, 8]),
		_piece("black-general-1", "black", "general", [4, 23]),
	]
	player_data.public_flags = [{
		"id": "flag-a", "owner": "",
		"capturing_side": "red", "capture_progress": 2, "contested": false,
		"discovered": false, "position": [],
	}]
	var preserve_action: Dictionary = _action("preserve-capture", "red-general-1", [4, 0], [3, 0])
	var preserve_result: Dictionary = VisibleStateEvaluator.evaluate(
		preserve_action, player_data, rules, config
	)
	_expect(
		int(preserve_result.breakdown.dimensions.flag_control.delta) == 0,
		"公开夺旗进度在占领棋子未离开时保持评分",
		failures
	)
	var alternate_action: Dictionary = _action("unknown-occupier", "red-rook-1", [4, 8], [4, 9])
	var alternate_result: Dictionary = VisibleStateEvaluator.evaluate(alternate_action, player_data, rules, config)
	_expect(int(alternate_result.breakdown.dimensions.flag_control.delta) == 0,
		"只公开进度时AI不得推断哪枚棋子位于隐藏旗格", failures)
	var valid_view := AiPlayerView.new(player_data)
	_expect(valid_view.is_valid(), "未发现旗帜DTO通过AI白名单", failures)
	var leaking_projection: Dictionary = player_data.duplicate(true)
	leaking_projection.public_flags[0]["position"] = [4, 10]
	_expect(
		not AiPlayerView.new(leaking_projection).is_valid(),
		"未发现旗帜携带position时被AI白名单拒绝",
		failures
	)
	var discovered_projection: Dictionary = player_data.duplicate(true)
	discovered_projection.public_flags[0]["discovered"] = true
	discovered_projection.public_flags[0]["position"] = [4, 10]
	_expect(AiPlayerView.new(discovered_projection).is_valid(), "已发现旗位可供AI使用", failures)
	var enter_flag_action: Dictionary = _action("enter-discovered-flag", "red-rook-1", [4, 8], [4, 10])
	var enter_flag_result: Dictionary = VisibleStateEvaluator.evaluate(
		enter_flag_action, discovered_projection, rules, config
	)
	_expect(int(enter_flag_result.breakdown.dimensions.flag_control.delta) > 0,
		"AI会利用己方已经发现的旗位争夺目标", failures)
	var indirect_leak: Dictionary = player_data.duplicate(true)
	indirect_leak.public_flags[0]["occupier_piece_id"] = "red-rook-1"
	_expect(not AiPlayerView.new(indirect_leak).is_valid(), "occupier_piece_id间接旗位泄漏也被白名单拒绝", failures)


static func _test_advisor_resurrection_scoring(failures: Array[String]) -> void:
	var config := DifficultyConfig.new()
	config.candidate_limit = 2
	config.random_score_span = 0
	config.material_weight = 1
	config.mobility_weight = 0
	config.threat_penalty_percent = 0
	config.support_bonus_percent = 0
	config.general_safety_penalty = 0
	config.territory_weight = 0
	config.enemy_general_attack_priority = 0
	config.search_candidate_limit = 0
	config.belief_sample_count = 0
	config.resurrection_value_weight_percent = 100
	var resurrect_action: Dictionary = _action(
		"resurrect-red-advisor-1", "red-advisor-1", [3, 0], [0, 0]
	)
	resurrect_action.kind = "resurrect"
	resurrect_action.path_length = 0
	resurrect_action.resurrection_candidate_count = 2
	resurrect_action.resurrection_average_piece_value = 50
	var pass_action: Dictionary = _action("pass", "", [0, 0], [0, 0])
	pass_action.kind = "pass"
	pass_action.path_length = 0
	var projection: Dictionary = _projection([resurrect_action, pass_action], [
		_piece("red-general-1", "red", "general", [4, 0]),
		_piece("red-advisor-1", "red", "advisor", [3, 0]),
		_piece("black-general-1", "black", "general", [4, 23]),
	])
	var decision: Dictionary = DecisionEngine.new().decide(
		AiPlayerView.new(projection), PublicRules.new(_rules()), Memory.new(_memory()), 40417, config
	)
	_expect(
		bool(decision.get("ok", false)) \
		and str(decision.get("action", {}).get("id", "")) == "resurrect-red-advisor-1",
		"复活池平均棋值高于献祭士时AI可主动选择复活",
		failures
	)
	_expect(
		VisibleStateEvaluator.critical_reasons(
			resurrect_action, projection, PublicRules.new(_rules()), config
		).has("positive_expected_resurrection"),
		"正期望复活动作受低预算关键候选保护",
		failures
	)
	var leaked_candidates: Dictionary = projection.duplicate(true)
	leaked_candidates.legal_actions[0]["resurrection_candidates"] = [
		{"piece_type": "advisor"}, {"piece_type": "general"},
	]
	_expect(
		not AiPlayerView.new(leaked_candidates).is_valid(),
		"AI拒绝复活候选身份与类型列表，仅消费已排除士和帅将后的公开聚合值",
		failures
	)


static func _test_two_ply_avoids_recapture(failures: Array[String]) -> void:
	var config := DifficultyConfig.new()
	config.candidate_limit = 2
	config.random_score_span = 0
	config.material_weight = 1
	config.threat_penalty_percent = 0
	config.support_bonus_percent = 0
	config.general_safety_penalty = 900
	config.flag_capture_priority = 820
	config.flag_defense_priority = 650
	config.enemy_general_attack_priority = 820
	config.search_candidate_limit = 2
	config.opponent_response_limit = 8
	config.belief_sample_count = 0
	config.belief_risk_weight_percent = 100
	var actions: Array = [
		_action("greedy-capture", "red-rook-1", [4, 4], [4, 5], [{"piece_id": "black-pawn-1", "piece_type": "pawn"}]),
		_action("safe-move", "red-rook-1", [4, 4], [3, 4]),
	]
	var pieces: Array = [
		_piece("red-general-1", "red", "general", [0, 0]),
		_piece("red-rook-1", "red", "rook", [4, 4]),
		_piece("black-pawn-1", "black", "pawn", [4, 5]),
		_piece("black-rook-1", "black", "rook", [4, 8]),
		_piece("black-general-1", "black", "general", [8, 23]),
	]
	var projection: Dictionary = _projection(actions, pieces)
	var memory := Memory.new(_memory())
	var decision: Dictionary = DecisionEngine.new().decide(
		AiPlayerView.new(projection), PublicRules.new(_rules()), memory, 77117, config
	)
	_expect(bool(decision.get("ok", false)), "二层搜索夹具可完成决策", failures)
	_expect(
		str(decision.get("action", {}).get("id", "")) == "safe-move",
		"二层搜索避开吃兵后被车反吃的贪吃行动",
		failures
	)
	var greedy_audit: Dictionary = _candidate(decision.get("audit", {}).get("candidates", []), "greedy-capture")
	_expect(
		int(greedy_audit.get("search_adjustment", 0)) < 0,
		"贪吃候选审计记录对手最强反吃造成的负向调整",
		failures
	)


static func _test_belief_determinism(failures: Array[String]) -> void:
	var projection: Dictionary = _projection([], [
		_piece("red-general-1", "red", "general", [4, 0]),
		_piece("red-rook-1", "red", "rook", [0, 6]),
	])
	projection.turn_index = 12
	projection.visible_cells = [[4, 0], [0, 6], [0, 7], [1, 6]]
	var memory_data: Dictionary = _memory()
	memory_data.enemy_piece_observations = {
		"black-rook-1": {"piece_type": "rook", "position": [2, 18], "turn_index": 8},
	}
	var memory := Memory.new(memory_data)
	var rules := PublicRules.new(_rules())
	var first: Array = BeliefModel.build_samples(projection, memory, rules, 99173, 4)
	var second: Array = BeliefModel.build_samples(projection, memory, rules, 99173, 4)
	_expect(
		Canonical.digest(first) == Canonical.digest(second),
		"相同公开视图、历史记忆和 AI seed 生成完全一致的信念样本",
		failures
	)
	var visible_set: Dictionary = {}
	for cell: Array in projection.visible_cells:
		visible_set["%d,%d" % [cell[0], cell[1]]] = true
	var hidden_on_visible_cell: bool = false
	for sample: Array in first:
		for piece: Dictionary in sample:
			if piece.get("status_tags", []).has("belief") \
			and visible_set.has("%d,%d" % [piece.position[0], piece.position[1]]):
				hidden_on_visible_cell = true
	_expect(not hidden_on_visible_cell, "信念棋子不会被采样到当前已见空格", failures)


static func _projection(actions: Array, pieces: Array) -> Dictionary:
	return {
		"schema_version": "player-view-ai-v1",
		"decision_id": "fixture-two-ply",
		"viewer_side": "red",
		"turn_index": 4,
		"visible_cells": [],
		"visible_pieces": pieces,
		"public_flags": [],
		"public_walls": [
			{"side": "red", "status": "INTACT"},
			{"side": "black", "status": "INTACT"},
		],
		"legal_actions": actions,
		"public_events": [],
	}


static func _action(
	action_id: String,
	actor_id: String,
	origin: Array,
	target: Array,
	captures: Array = []
) -> Dictionary:
	return {
		"id": action_id,
		"kind": "move",
		"actor_id": actor_id,
		"origin": origin,
		"target": target,
		"visible_captures": captures,
		"reveal_cell_count": 0,
		"attacks_wall": false,
		"path_length": absi(int(target[0]) - int(origin[0])) + absi(int(target[1]) - int(origin[1])),
	}


static func _piece(piece_id: String, side: String, piece_type: String, position: Array) -> Dictionary:
	return {
		"id": piece_id,
		"side": side,
		"piece_type": piece_type,
		"position": position,
		"status_tags": ["owned"] if side == "red" else ["visible"],
	}


static func _rules() -> Dictionary:
	return {
		"schema_version": "public-ai-rules-v1",
		"board_width": 9,
		"board_height": 24,
		"piece_values": {
			"pawn": 10, "rook": 50, "horse": 30, "elephant": 25,
			"advisor": 25, "cannon": 45, "general": 10000,
		},
		"action_kind_bias": {"move": 0, "bombard": 0, "resurrect": 0, "pass": -100},
	}


static func _memory() -> Dictionary:
	return {
		"schema_version": "ai-memory-v1",
		"recent_action_ids": [],
		"action_visit_counts": {},
		"actor_visit_counts": {},
		"last_visible_piece_turns": {},
		"enemy_piece_observations": {},
		"known_captured_enemy_ids": [],
	}


static func _candidate(candidates: Array, action_id: String) -> Dictionary:
	for candidate: Dictionary in candidates:
		if str(candidate.get("action_id", "")) == action_id:
			return candidate
	return {}


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
