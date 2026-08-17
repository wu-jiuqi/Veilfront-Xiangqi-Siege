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
	_test_flag_scoring(failures)
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


static func _test_flag_scoring(failures: Array[String]) -> void:
	var config: Resource = load("res://resources/prototype/ai/prototype_default_hypothesis.tres")
	var rules := PublicRules.new(_rules())
	var player_data: Dictionary = _projection([], [])
	player_data.visible_pieces = [
		_piece("red-general-1", "red", "general", [4, 0]),
		_piece("red-rook-1", "red", "rook", [4, 8]),
		_piece("black-general-1", "black", "general", [4, 23]),
	]
	player_data.public_flags = [{
		"id": "flag-a", "position": [4, 10], "owner": "",
		"capturing_side": "", "capture_progress": 0, "contested": false,
	}]
	var flag_action: Dictionary = _action("capture-flag", "red-rook-1", [4, 8], [4, 10])
	flag_action.occupies_flag = true
	flag_action.flag_vicinity_reveal_count = 2
	var result: Dictionary = VisibleStateEvaluator.evaluate(flag_action, player_data, rules, config)
	var dimensions: Dictionary = result.breakdown.dimensions
	_expect(
		int(dimensions.flag_control.delta) >= int(config.flag_capture_priority),
		"踩入非己方旗格至少获得完整夺旗优先级",
		failures
	)
	_expect(
		int(dimensions.vision.delta) == 2 * int(config.flag_vision_weight),
		"旗帜附近新视野使用独立加权",
		failures
	)
	player_data.public_flags[0].owner = "red"
	player_data.public_flags[0].capturing_side = "black"
	player_data.public_flags[0].capture_progress = 1
	var defend_action: Dictionary = _action("defend-flag", "red-rook-1", [4, 8], [4, 9])
	var defend_result: Dictionary = VisibleStateEvaluator.evaluate(defend_action, player_data, rules, config)
	_expect(
		int(defend_result.breakdown.dimensions.flag_control.delta) > 0,
		"接近被敌方占领中的己方旗帜获得回防收益",
		failures
	)
	_expect(
		VisibleStateEvaluator.critical_reasons(defend_action, player_data, rules, config).has("defend_flag_zone"),
		"进入受威胁旗区的行动受关键候选保护",
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
		"flag_vicinity_reveal_count": 0,
		"occupies_flag": false,
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
		"action_kind_bias": {"move": 0, "bombard": 0, "pass": -100},
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
