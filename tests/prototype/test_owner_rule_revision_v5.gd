extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const MoveRules = preload("res://scripts/prototype/core/move_rules.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const Projector = preload("res://scripts/prototype/view/player_view_projector.gd")

static var _failures: Array[String] = []


static func run_suite() -> bool:
	_failures.clear()
	_test_wall_line_blocks_until_breached()
	_test_hidden_horse_contact_stops_and_resolves_rook()
	_test_elephant_field_blocks_enemy_pawn_and_exposes_overlays()
	_test_flag_discovery_is_private_and_persistent()
	_test_all_deaths_use_shared_casualty_pool()
	_test_advisor_sacrifice_and_revive_update_pool()
	_test_capture_ghost_lasts_one_round()
	for failure: String in _failures:
		push_error("OWNER_RULE_V5_FAIL: %s" % failure)
	return _failures.is_empty()


static func _test_hidden_horse_contact_stops_and_resolves_rook() -> void:
	var state: Dictionary = _empty_state(8510)
	state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(state, "red-rook-1", Vector2i(5, 10))
	_place(state, "black-horse-1", Vector2i(5, 12))
	state["pieces"]["black-horse-1"]["hidden"] = true
	state["active_side"] = MatchState.RED
	var result: Dictionary = RuleEngine.submit_action(
		state, _move("red-rook-1", Vector2i(5, 14))
	)
	_expect(result.get("consumed", false), "车接触路径中的隐身马时应正常结算行动")
	_expect(Canonical.coordinate(state["pieces"]["red-rook-1"]["position"]) == Vector2i(5, 12),
		"普通车接触首枚隐身马后应停在接触交点")
	_expect(not state["pieces"]["black-horse-1"]["alive"] \
		and state["casualty_pools"][MatchState.BLACK].has("black-horse-1"),
		"路径首枚隐身马应被车吃掉而不是成为无反馈路障")


static func _test_wall_line_blocks_until_breached() -> void:
	var state: Dictionary = _empty_state(8501)
	_place(state, "red-rook-1", Vector2i(5, 19))
	var front_result: Dictionary = MoveRules.evaluate_move(
		state, _move("red-rook-1", Vector2i(5, 20)), MatchState.RED
	)
	var wall_result: Dictionary = MoveRules.evaluate_move(
		state, _move("red-rook-1", Vector2i(5, 21)), MatchState.RED
	)
	_expect(front_result.get("legal", false), "黑墙完整时红子应能到达墙线前一条y=20")
	_expect(not wall_result.get("legal", false), "黑墙完整时红子不得踏上城墙线y=21")
	state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	var breached_result: Dictionary = MoveRules.evaluate_move(
		state, _move("red-rook-1", Vector2i(5, 21)), MatchState.RED
	)
	_expect(breached_result.get("legal", false), "黑墙倒塌后红子应能踏上城墙线")


static func _test_elephant_field_blocks_enemy_pawn_and_exposes_overlays() -> void:
	var state: Dictionary = _empty_state(8507)
	_place(state, "red-elephant-1", Vector2i(4, 8))
	_place(state, "red-rook-1", Vector2i(1, 9))
	_place(state, "black-pawn-1", Vector2i(4, 12))
	state["active_side"] = MatchState.RED
	RuleEngine.submit_action(state, _move("red-elephant-1", Vector2i(6, 10)))
	state["active_side"] = MatchState.RED
	RuleEngine.submit_action(state, _move("red-rook-1", Vector2i(3, 9)))
	var overlay_view: Dictionary = Projector.project(state, MatchState.RED)
	_expect(overlay_view.get("vision_overlays", {}).get("elephant_reveal_zones", []).size() == 1,
		"相的19点侦察范围应进入玩家专属高亮覆盖层")
	_expect(overlay_view.get("vision_overlays", {}).get("elephant_block_fields", []).size() == 1,
		"相的田字九点阻挡范围应进入玩家专属高亮覆盖层")
	_expect(overlay_view.get("vision_overlays", {}).get("rook_paths", []).size() == 1,
		"车的条形视野应进入玩家专属高亮覆盖层")
	state["active_side"] = MatchState.BLACK
	var enemy_pawn: Dictionary = RuleEngine.submit_action(
		state, _move("black-pawn-1", Vector2i(4, 7))
	)
	_expect(enemy_pawn.get("event", {}).get("outcome", {}).get("position", []) == [4, 10],
		"敌兵从田字格外穿越时应停在路径首个交点")

	var friendly: Dictionary = _empty_state(8508)
	_place(friendly, "red-elephant-1", Vector2i(4, 8))
	_place(friendly, "red-pawn-1", Vector2i(4, 12))
	friendly["active_side"] = MatchState.RED
	RuleEngine.submit_action(friendly, _move("red-elephant-1", Vector2i(6, 10)))
	friendly["active_side"] = MatchState.RED
	var friendly_pawn: Dictionary = RuleEngine.submit_action(
		friendly, _move("red-pawn-1", Vector2i(4, 7))
	)
	_expect(friendly_pawn.get("event", {}).get("outcome", {}).get("position", []) == [4, 7],
		"己方相田字格不得阻挡己方兵")


static func _test_flag_discovery_is_private_and_persistent() -> void:
	var state: Dictionary = _empty_state(8502)
	state["flags"] = [
		_flag("flag-1", Vector2i(5, 12)),
		_flag("flag-2", Vector2i(2, 15)),
		_flag("flag-3", Vector2i(8, 10)),
	]
	_place(state, "red-rook-1", Vector2i(5, 11))
	var before_red: Dictionary = Projector.project(state, MatchState.RED)
	var before_black: Dictionary = Projector.project(state, MatchState.BLACK)
	_expect(_flag_by_id(before_red, "flag-1").get("position", []) == [],
		"旗帜尚未登记发现时不得直接公开坐标")
	_expect(_flag_by_id(before_black, "flag-1").get("position", []) == [],
		"另一方未发现旗帜时不得获得坐标")
	state["active_side"] = MatchState.RED
	RuleEngine.submit_action(state, _pass())
	var discovered_red: Dictionary = Projector.project(state, MatchState.RED)
	var undiscovered_black: Dictionary = Projector.project(state, MatchState.BLACK)
	_expect(_flag_by_id(discovered_red, "flag-1").get("position", []) == [5, 12],
		"旗帜进入红方视野后应显示真实坐标")
	_expect(_flag_by_id(discovered_red, "flag-1").get("discovered", false),
		"红方旗帜发现状态应写入PlayerView")
	_expect(_flag_by_id(undiscovered_black, "flag-1").get("position", []) == [],
		"红方发现旗帜不得同步泄露给黑方")
	MatchState.relocate_piece(state, "red-rook-1", Vector2i(1, 1))
	state["active_side"] = MatchState.BLACK
	RuleEngine.submit_action(state, _pass())
	var remembered_red: Dictionary = Projector.project(state, MatchState.RED)
	_expect(_flag_by_id(remembered_red, "flag-1").get("position", []) == [5, 12],
		"旗帜离开视野后红方仍应永久保留发现图标")
	var ai_view: Dictionary = Projector.export_ai_projection_from_view(remembered_red)
	_expect(_flag_by_id(ai_view, "flag-1", "public_flags").get("position", []) == [4, 11],
		"AI应获得与玩家等价的已发现旗帜零基坐标")


static func _test_all_deaths_use_shared_casualty_pool() -> void:
	var state: Dictionary = _empty_state(8503)
	_place(state, "red-rook-1", Vector2i(5, 10))
	_place(state, "black-horse-1", Vector2i(5, 11))
	state["active_side"] = MatchState.RED
	var capture_result: Dictionary = RuleEngine.submit_action(
		state, _move("red-rook-1", Vector2i(5, 11))
	)
	_expect(capture_result.get("consumed", false), "吃子动作应完成")
	_expect(state.get("casualty_pools", {}).get(MatchState.BLACK, []).has("black-horse-1"),
		"被吃棋子必须进入所属方阵亡池")
	var red_view: Dictionary = Projector.project(state, MatchState.RED)
	var black_view: Dictionary = Projector.project(state, MatchState.BLACK)
	_expect(red_view.get("casualties", []) == black_view.get("casualties", []),
		"双方PlayerView必须同步显示同一份公开阵亡棋子")
	_expect(_casualty_ids(red_view).has("black-horse-1"), "公开阵亡信息应包含被吃的黑马")

	var bombard: Dictionary = _empty_state(8504)
	_place(bombard, "red-pawn-1", Vector2i(4, 12))
	_place(bombard, "black-cannon-1", Vector2i(5, 12))
	RuleEngine.resolve_bombardment_window(
		bombard, "red-cannon-1", Vector2i(5, 12),
		[Vector2i(4, 12), Vector2i(5, 12), Vector2i(6, 12)]
	)
	_expect(bombard.get("casualty_pools", {}).get(MatchState.RED, []).has("red-pawn-1"),
		"炮击阵亡的红兵必须进入红方阵亡池")
	_expect(bombard.get("casualty_pools", {}).get(MatchState.BLACK, []).has("black-cannon-1"),
		"炮击阵亡的黑炮必须进入黑方阵亡池")


static func _test_advisor_sacrifice_and_revive_update_pool() -> void:
	var state: Dictionary = _empty_state(8505)
	_place(state, "red-advisor-1", Vector2i(4, 1))
	_mark_dead_for_setup(state, "red-rook-1")
	_mark_dead_for_setup(state, "red-advisor-2")
	_mark_dead_for_setup(state, "red-general-1")
	state["active_side"] = MatchState.RED
	var view: Dictionary = Projector.project(state, MatchState.RED)
	var public_actions: Array = Projector.generate_action_intents(view)
	var registered_public_action: Dictionary = _find_action(
		public_actions, "red-advisor-1", "resurrect"
	)
	var core_actions: Array = MoveRules.generate_legal_actions(
		state, MatchState.RED, Projector.visibility_context(state, MatchState.RED)
	)
	_expect(not registered_public_action.is_empty() \
		and registered_public_action.get("classification", "") == Projector.KNOWN_LEGAL,
		"士的复活动作必须注册到玩家公开行动列表")
	_expect(not _find_action(core_actions, "red-advisor-1", "resurrect").is_empty(),
		"士的复活动作必须注册到规则核心合法行动列表")
	var result: Dictionary = RuleEngine.submit_action(state, {
		"piece_id": "red-advisor-1",
		"action_type": "resurrect",
		"target_cell": [],
		"skill_type": "advisor_resurrection",
	})
	_expect(result.get("consumed", false), "士应能从统一阵亡池发动献祭复活")
	_expect(state["casualty_pools"][MatchState.RED].has("red-advisor-1"),
		"献祭的士必须进入红方阵亡池")
	_expect(not state["casualty_pools"][MatchState.RED].has("red-rook-1"),
		"复活的车必须从阵亡池移除")
	_expect(state["pieces"]["red-rook-1"]["alive"], "唯一合格候选红车应被复活")
	_expect(not state["pieces"]["red-advisor-2"]["alive"], "阵亡士不得成为复活候选")
	_expect(not state["pieces"]["red-general-1"]["alive"], "阵亡帅不得成为复活候选")


static func _find_action(actions: Array, piece_id: String, action_type: String) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("piece_id", "")) == piece_id \
		and str(action.get("action_type", "")) == action_type:
			return action
	return {}


static func _test_capture_ghost_lasts_one_round() -> void:
	var state: Dictionary = _empty_state(8506)
	_place(state, "red-rook-1", Vector2i(6, 10))
	_place(state, "black-pawn-1", Vector2i(6, 11))
	state["active_side"] = MatchState.RED
	RuleEngine.submit_action(state, _move("red-rook-1", Vector2i(6, 11)))
	var black_after_capture: Dictionary = Projector.project(state, MatchState.BLACK)
	_expect(_ghost_ids(black_after_capture).has("black-pawn-1"),
		"黑卒被吃后黑方应在原点看到虚影")
	_expect(not _ghost_ids(Projector.project(state, MatchState.RED)).has("black-pawn-1"),
		"被吃虚影仅用于阵亡方自己的短期记忆")
	RuleEngine.submit_action(state, _pass())
	var black_after_round: Dictionary = Projector.project(state, MatchState.BLACK)
	_expect(not _ghost_ids(black_after_round).has("black-pawn-1"),
		"双方各推进一次行动后被吃虚影应消失")


static func _empty_state(seed_value: int) -> Dictionary:
	var state: Dictionary = RuleEngine.create_match(seed_value)
	for piece_value: Variant in state["pieces"].values():
		var piece: Dictionary = piece_value
		MatchState.remove_piece_from_board(state, piece["id"])
		piece["alive"] = false
		piece["in_reserve"] = false
	state["board"].clear()
	state["casualty_pools"] = {MatchState.RED: [], MatchState.BLACK: []}
	state["capture_ghosts"] = {MatchState.RED: [], MatchState.BLACK: []}
	state["flag_discoveries"] = {MatchState.RED: [], MatchState.BLACK: []}
	return state


static func _place(state: Dictionary, piece_id: String, cell: Vector2i) -> void:
	MatchState.relocate_piece(state, piece_id, cell)
	state["casualty_pools"][state["pieces"][piece_id]["side"]].erase(piece_id)


static func _mark_dead_for_setup(state: Dictionary, piece_id: String) -> void:
	MatchState.remove_piece_from_board(state, piece_id)
	var piece: Dictionary = state["pieces"][piece_id]
	piece["alive"] = false
	piece["in_reserve"] = false
	if not state["casualty_pools"][piece["side"]].has(piece_id):
		state["casualty_pools"][piece["side"]].append(piece_id)


static func _flag(flag_id: String, position: Vector2i) -> Dictionary:
	return {
		"id": flag_id,
		"position": [position.x, position.y],
		"owner": MatchState.NEUTRAL,
		"occupier_piece_id": "",
		"capturing_side": "",
		"capture_progress": 0,
		"contested": false,
	}


static func _move(piece_id: String, target: Vector2i) -> Dictionary:
	return {
		"piece_id": piece_id,
		"action_type": "move",
		"target_cell": [target.x, target.y],
		"skill_type": "",
	}


static func _pass() -> Dictionary:
	return {"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""}


static func _flag_by_id(view: Dictionary, flag_id: String, key: String = "flags") -> Dictionary:
	for flag: Dictionary in view.get(key, []):
		if str(flag.get("id", "")) == flag_id:
			return flag
	return {}


static func _casualty_ids(view: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for casualty: Dictionary in view.get("casualties", []):
		result.append(str(casualty.get("piece_id", "")))
	return result


static func _ghost_ids(view: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for ghost: Dictionary in view.get("capture_ghosts", []):
		result.append(str(ghost.get("piece_id", "")))
	return result


static func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
