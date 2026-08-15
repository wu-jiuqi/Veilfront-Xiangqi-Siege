extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const MoveRules = preload("res://scripts/prototype/core/move_rules.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const Projector = preload("res://scripts/prototype/view/player_view_projector.gd")
const SeededRandom = preload("res://scripts/prototype/core/seeded_random.gd")


static func run_suite() -> bool:
	var failures: Array[String] = []
	_test_rook_standard_and_special(failures)
	_test_horse_leg_and_special(failures)
	_test_elephant_eye_and_special(failures)
	_test_palace_and_pawn_geometry(failures)
	_test_cannon_screen_and_wall(failures)
	_test_complete_generator(failures)
	_test_fast_policy_scenarios(failures)
	for failure: String in failures:
		push_error("MOVE_RULES_FAIL: %s" % failure)
	return failures.is_empty()


static func _test_rook_standard_and_special(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(301)
	_place(state, "red-rook-1", Vector2i(5, 10))
	_place(state, "black-pawn-1", Vector2i(5, 12))
	_place(state, "black-pawn-2", Vector2i(5, 14))
	var result: Dictionary = _move(state, "red-rook-1", Vector2i(5, 15), _all_cells())
	_expect(result.get("legal", false), "特殊车可穿敌棋", failures)
	_expect(result.get("move_kind", "") == "rook_special", "车在特殊区且敌墙完整使用特殊规则", failures)
	_expect(result.get("target_piece_ids", []) == ["black-pawn-1", "black-pawn-2"], "特殊车目标按路径顺序", failures)
	_place(state, "red-pawn-1", Vector2i(5, 13))
	result = _move(state, "red-rook-1", Vector2i(5, 15), _all_cells())
	_expect(not result.get("legal", true) and result.get("reason", "") == "own_piece_blocks", "特殊车不可穿己棋", failures)
	_remove(state, "red-pawn-1")
	state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	result = _move(state, "red-rook-1", Vector2i(5, 15), _all_cells())
	_expect(not result.get("legal", true) and result.get("reason", "") == "route_blocked", "敌墙倒塌后车恢复传统阻挡", failures)
	_remove(state, "black-pawn-1")
	result = _move(state, "red-rook-1", Vector2i(5, 14), _all_cells())
	_expect(result.get("legal", false) and result.get("target_piece_ids", []) == ["black-pawn-2"], "普通车末格敌棋进入吃子目标", failures)


static func _test_horse_leg_and_special(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(302)
	_place(state, "red-horse-1", Vector2i(5, 10))
	_place(state, "black-pawn-1", Vector2i(6, 10))
	var result: Dictionary = _move(state, "red-horse-1", Vector2i(7, 11), _all_cells())
	_expect(result.get("legal", false) and result.get("move_kind", "") == "horse_special", "特殊马忽略马腿", failures)
	state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	result = _move(state, "red-horse-1", Vector2i(7, 11), _all_cells())
	_expect(not result.get("legal", true) and result.get("reason", "") == "horse_leg_blocked", "普通马受蹩腿", failures)
	_remove(state, "black-pawn-1")
	result = _move(state, "red-horse-1", Vector2i(7, 11), _all_cells())
	_expect(result.get("legal", false) and result.get("move_kind", "") == "horse_standard", "普通马无腿阻时可走", failures)


static func _test_elephant_eye_and_special(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(303)
	_place(state, "red-elephant-1", Vector2i(5, 10))
	_place(state, "black-pawn-1", Vector2i(6, 11))
	var result: Dictionary = _move(state, "red-elephant-1", Vector2i(7, 12), _all_cells())
	_expect(result.get("legal", false) and result.get("move_kind", "") == "elephant_special", "特殊相忽略象眼", failures)
	state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	result = _move(state, "red-elephant-1", Vector2i(7, 12), _all_cells())
	_expect(not result.get("legal", true) and result.get("reason", "") == "elephant_eye_blocked", "普通相受堵象眼", failures)
	_remove(state, "black-pawn-1")
	result = _move(state, "red-elephant-1", Vector2i(7, 12), _all_cells())
	_expect(result.get("legal", false), "相象无河界限制", failures)


static func _test_palace_and_pawn_geometry(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(304)
	_place(state, "red-advisor-1", Vector2i(4, 1))
	_place(state, "red-general-1", Vector2i(5, 2))
	_expect(_move(state, "red-advisor-1", Vector2i(5, 2), _all_cells()).get("reason", "") == "own_piece_target", "士在九宫斜走但不可占己棋", failures)
	_expect(not _move(state, "red-advisor-1", Vector2i(3, 2), _all_cells()).get("legal", true), "士不可离开九宫", failures)
	_expect(_move(state, "red-general-1", Vector2i(5, 3), _all_cells()).get("legal", false), "将帅九宫内正交一步", failures)
	_expect(not _move(state, "red-general-1", Vector2i(5, 4), _all_cells()).get("legal", true), "将帅不可离宫", failures)
	var pawn_state: Dictionary = _empty_state(305)
	_place(pawn_state, "red-pawn-1", Vector2i(5, 10))
	_place(pawn_state, "black-pawn-1", Vector2i(5, 12))
	var special: Dictionary = _move(pawn_state, "red-pawn-1", Vector2i(5, 15), _all_cells())
	_expect(special.get("legal", false) and special.get("move_kind", "") == "pawn_special", "特殊兵可纵向五格穿敌棋", failures)
	_place(pawn_state, "black-pawn-2", Vector2i(5, 15))
	_expect(not _move(pawn_state, "red-pawn-1", Vector2i(5, 15), _all_cells()).get("legal", true), "特殊兵终点必须为空", failures)
	pawn_state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_expect(_move(pawn_state, "red-pawn-1", Vector2i(4, 10), _all_cells()).get("legal", false), "兵始终按过河可横走", failures)
	_expect(not _move(pawn_state, "red-pawn-1", Vector2i(5, 9), _all_cells()).get("legal", true), "兵不可后退", failures)


static func _test_cannon_screen_and_wall(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(306)
	_place(state, "red-cannon-1", Vector2i(2, 10))
	_place(state, "red-pawn-1", Vector2i(2, 12))
	_place(state, "black-pawn-1", Vector2i(2, 14))
	var result: Dictionary = _move(state, "red-cannon-1", Vector2i(2, 14), _all_cells())
	_expect(result.get("legal", false) and result.get("move_kind", "") == "cannon_capture", "炮恰一炮架精确吃子", failures)
	_remove(state, "red-pawn-1")
	result = _move(state, "red-cannon-1", Vector2i(2, 14), _all_cells())
	_expect(not result.get("legal", true) and result.get("reason", "") == "cannon_screen_count", "炮无炮架不可吃子", failures)
	_place(state, "red-pawn-1", Vector2i(2, 11))
	_place(state, "red-pawn-2", Vector2i(2, 12))
	result = _move(state, "red-cannon-1", Vector2i(2, 14), _all_cells())
	_expect(not result.get("legal", true), "炮多炮架不可吃子", failures)
	var wall_state: Dictionary = _empty_state(307)
	_place(wall_state, "red-rook-1", Vector2i(5, 19))
	_expect(not _move(wall_state, "red-rook-1", Vector2i(5, 20), _all_cells()).get("legal", true), "完整敌墙阻止进入敌营", failures)
	wall_state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_expect(_move(wall_state, "red-rook-1", Vector2i(5, 20), _all_cells()).get("legal", false), "敌墙倒塌后允许进入敌营", failures)


static func _test_complete_generator(failures: Array[String]) -> void:
	var state: Dictionary = MatchState.create(308)
	var visibility: Dictionary = Projector.visibility_context(state, MatchState.RED)
	var actions: Array = MoveRules.generate_legal_actions(state, MatchState.RED, visibility)
	_expect(not actions.is_empty(), "完整真值行动生成器返回行动", failures)
	_expect(actions.back()["action_type"] == "pass", "完整真值行动生成器总有公开跳过出口", failures)
	var repeated: Array = MoveRules.generate_legal_actions(state, MatchState.RED, visibility)
	_expect(Canonical.digest(actions) == Canonical.digest(repeated), "完整真值行动生成稳定排序", failures)
	var expected: Dictionary = _oracle_action_set(state, MatchState.RED, visibility)
	var generated: Dictionary = {}
	for action: Dictionary in actions:
		if action["action_type"] != "pass":
			generated[_action_key(action)] = true
	_expect(_sorted_keys(expected) == _sorted_keys(generated), "全216格 evaluate oracle 与完整生成器规范行动集合全等", failures)
	var representative_actions: Dictionary = {}
	for action: Dictionary in actions:
		var piece_type: String = "none" if action["piece_id"].is_empty() \
			else str(state["pieces"][action["piece_id"]]["piece_type"])
		var signature: String = "%s|%s|%s" % [piece_type, action["action_type"], action["skill_type"]]
		if not representative_actions.has("%s|first" % signature):
			representative_actions["%s|first" % signature] = action
		representative_actions["%s|last" % signature] = action
	for action_value: Variant in representative_actions.values():
		var action: Dictionary = action_value
		var snapshot: Dictionary = MatchState.clone(state)
		var prepared: Dictionary = RuleEngine.prepare_action(snapshot)
		var submitted: Dictionary = RuleEngine.submit_action(snapshot, action, {
			"preparation_token": prepared.get("preparation", {}).get("token", ""),
			"include_state_summary": false,
		})
		_expect(submitted.get("ok", false) and submitted.get("consumed", false),
			"各piece/move_kind边界生成动作可由prepared snapshot提交: %s" % _action_key(action), failures)


static func _test_fast_policy_scenarios(failures: Array[String]) -> void:
	var initial: Dictionary = MatchState.create(309)
	_expect_fast_policy_submits(initial, 9001, "初态", failures)
	var breached: Dictionary = MatchState.create(310)
	breached["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_expect_fast_policy_submits(breached, 9002, "敌墙BREACHED", failures)
	var hidden_screen: Dictionary = MatchState.create(311)
	MatchState.relocate_piece(hidden_screen, "red-cannon-1", Vector2i(2, 10))
	MatchState.relocate_piece(hidden_screen, "black-horse-1", Vector2i(2, 12))
	hidden_screen["pieces"]["black-horse-1"]["hidden"] = true
	_expect_fast_policy_submits(hidden_screen, 9003, "隐藏炮架", failures)
	var reserve: Dictionary = MatchState.create(312)
	MatchState.remove_piece_from_board(reserve, "red-pawn-1")
	reserve["pieces"]["red-pawn-1"]["in_reserve"] = true
	reserve["pieces"]["red-pawn-1"]["reserve_queue_index"] = 0
	reserve["reserve_queues"][MatchState.RED] = ["red-pawn-1"]
	_expect_fast_policy_submits(reserve, 9004, "后备部署后", failures)


static func _expect_fast_policy_submits(
	state: Dictionary,
	policy_seed: int,
	label: String,
	failures: Array[String]
) -> void:
	var prepared: Dictionary = RuleEngine.prepare_action(state)
	if not prepared.get("ok", false):
		failures.append("%s fast policy准备失败" % label)
		return
	var visibility: Dictionary = Projector.visibility_context(state, state["active_side"])
	var all_actions: Array = MoveRules.generate_legal_actions(state, state["active_side"], visibility)
	var has_non_pass: bool = all_actions.size() > 1
	var selection: Dictionary = MoveRules.choose_legal_action_fast(
		state, state["active_side"], visibility, SeededRandom.create_state(policy_seed)
	)
	var intent: Dictionary = selection.get("intent", {})
	_expect(not has_non_pass or intent.get("action_type", "") != "pass", "%s 有合法移动时 fast policy 不退化为pass" % label, failures)
	var submitted: Dictionary = RuleEngine.submit_action(state, intent, {
		"preparation_token": prepared["preparation"]["token"],
		"trusted_generated_action": true,
		"include_state_summary": false,
	})
	_expect(submitted.get("ok", false) and submitted.get("consumed", false), "%s fast policy 选择可提交" % label, failures)


static func _oracle_action_set(state: Dictionary, actor_side: String, visibility: Dictionary) -> Dictionary:
	var expected: Dictionary = {}
	var piece_ids: Array = state["pieces"].keys()
	piece_ids.sort()
	for piece_id_value: Variant in piece_ids:
		var piece_id: String = str(piece_id_value)
		var piece: Dictionary = state["pieces"][piece_id]
		if piece["side"] != actor_side or not piece["alive"] or piece["in_reserve"]:
			continue
		for y: int in range(1, MatchState.BOARD_HEIGHT + 1):
			for x: int in range(1, MatchState.BOARD_WIDTH + 1):
				var intent: Dictionary = {
					"piece_id": piece_id, "action_type": "move",
					"target_cell": [x, y], "skill_type": "",
				}
				var evaluation: Dictionary = MoveRules.evaluate_move(state, intent, actor_side, visibility)
				if evaluation.get("legal", false):
					intent["skill_type"] = evaluation["move_kind"]
					expected[_action_key(intent)] = true
		if piece["piece_type"] == "cannon":
			for y: int in range(1, MatchState.BOARD_HEIGHT + 1):
				for x: int in range(1, MatchState.BOARD_WIDTH + 1):
					var bombard_intent: Dictionary = {
						"piece_id": piece_id, "action_type": "bombard",
						"target_cell": [x, y], "skill_type": "area_bombardment",
					}
					if MoveRules.evaluate_bombard(state, bombard_intent, actor_side).get("legal", false):
						expected[_action_key(bombard_intent)] = true
	return expected


static func _action_key(intent: Dictionary) -> String:
	return "%s|%s|%s|%s" % [
		str(intent.get("action_type", "")), str(intent.get("piece_id", "")),
		Canonical.json(intent.get("target_cell", [])), str(intent.get("skill_type", "")),
	]


static func _sorted_keys(values: Dictionary) -> Array:
	var keys: Array = values.keys()
	keys.sort()
	return keys


static func _empty_state(seed_value: int) -> Dictionary:
	var state: Dictionary = MatchState.create(seed_value)
	for piece_id_value: Variant in state["pieces"].keys():
		var piece_id: String = str(piece_id_value)
		MatchState.remove_piece_from_board(state, piece_id)
		state["pieces"][piece_id]["alive"] = false
		state["pieces"][piece_id]["in_reserve"] = false
	return state


static func _place(state: Dictionary, piece_id: String, cell: Vector2i) -> void:
	if state["pieces"][piece_id]["alive"]:
		MatchState.remove_piece_from_board(state, piece_id)
	var occupant: Dictionary = MatchState.piece_at(state, cell)
	if not occupant.is_empty():
		_remove(state, occupant["id"])
	state["pieces"][piece_id]["alive"] = true
	state["pieces"][piece_id]["in_reserve"] = false
	MatchState.relocate_piece(state, piece_id, cell)


static func _remove(state: Dictionary, piece_id: String) -> void:
	MatchState.remove_piece_from_board(state, piece_id)
	state["pieces"][piece_id]["alive"] = false


static func _move(state: Dictionary, piece_id: String, target: Vector2i, visible_cells: Array) -> Dictionary:
	return MoveRules.evaluate_move(state, {
		"piece_id": piece_id,
		"action_type": "move",
		"target_cell": [target.x, target.y],
		"skill_type": "",
	}, state["pieces"][piece_id]["side"], {
		"visible_cells": visible_cells,
		"visible_piece_ids": state["pieces"].keys(),
	})


static func _all_cells() -> Array:
	var cells: Array = []
	for y: int in range(1, MatchState.BOARD_HEIGHT + 1):
		for x: int in range(1, MatchState.BOARD_WIDTH + 1):
			cells.append([x, y])
	return cells


static func _visibility_context(state: Dictionary) -> Dictionary:
	return {"visible_cells": _all_cells(), "visible_piece_ids": state["pieces"].keys()}


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
