extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const MoveRules = preload("res://scripts/prototype/core/move_rules.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const Projector = preload("res://scripts/prototype/view/player_view_projector.gd")

static var _failures: Array[String] = []


static func run_suite() -> bool:
	_failures.clear()
	_test_wall_geometry_and_hidden_flags()
	_test_elephant_vision_and_enemy_rook_interception()
	_test_flag_capture_starts_at_one()
	_test_active_advisor_resurrection_pool()
	for failure: String in _failures:
		push_error("OWNER_RULE_V4_FAIL: %s" % failure)
	return _failures.is_empty()


static func _test_wall_geometry_and_hidden_flags() -> void:
	var state: Dictionary = RuleEngine.create_match(8401)
	_expect(MatchState.is_in_base(Vector2i(5, 3), MatchState.RED), "红方大本营应为1..3行")
	_expect(not MatchState.is_in_base(Vector2i(5, 4), MatchState.RED), "红方4行应位于墙外缓冲区")
	_expect(MatchState.is_in_buffer(Vector2i(5, 4), MatchState.RED), "红方缓冲区应从4行开始")
	_expect(MatchState.is_in_buffer(Vector2i(5, 21), MatchState.BLACK), "黑方缓冲区应延伸到21行")
	_expect(MatchState.is_in_base(Vector2i(5, 22), MatchState.BLACK), "黑方大本营应从22行开始")
	_expect(Canonical.coordinate(state["pieces"]["red-pawn-1"]["position"]).y == 4, "兵应在红方城墙线上")
	_expect(Canonical.coordinate(state["pieces"]["black-pawn-1"]["position"]).y == 21, "卒应在黑方城墙线上")
	var unique_flags: Dictionary = {}
	for flag: Dictionary in state["flags"]:
		var flag_cell := Canonical.coordinate(flag["position"])
		_expect(flag_cell.y >= 9 and flag_cell.y <= 16, "旗帜必须位于8x9战区")
		unique_flags[Canonical.cell_key(flag_cell)] = true
	_expect(unique_flags.size() == 3, "三面旗帜位置不得重复")
	for side: String in [MatchState.RED, MatchState.BLACK]:
		var view: Dictionary = Projector.project(state, side)
		for public_flag: Dictionary in view["flags"]:
			_expect(not public_flag.has("position") and not public_flag.has("occupier_piece_id"),
					"PlayerView旗帜不得直接或间接公开位置")
		var ai_view: Dictionary = Projector.export_ai_projection_from_view(view)
		for public_flag: Dictionary in ai_view["public_flags"]:
			_expect(not public_flag.has("position"), "AI DTO旗帜不得公开位置")
		for action: Dictionary in ai_view["legal_actions"]:
			_expect(not action.has("occupies_flag") and not action.has("flag_vicinity_reveal_count"),
					"AI动作不得包含旗帜位置推断元数据")


static func _test_elephant_vision_and_enemy_rook_interception() -> void:
	var state: Dictionary = _empty_state(8402)
	_place(state, "red-elephant-1", Vector2i(4, 8))
	_place(state, "black-rook-1", Vector2i(1, 9))
	state["active_side"] = MatchState.RED
	var elephant_result: Dictionary = RuleEngine.submit_action(state, _move("red-elephant-1", Vector2i(6, 10)))
	_expect(elephant_result.get("consumed", false), "相应能在特殊区完成移动")
	var expected_vision: Array = MoveRules.reveal_cells_for_elephant_move(Vector2i(4, 8), Vector2i(6, 10))
	_expect(expected_vision.size() == 19, "相视野应为起点3x3、路径田字格、终点3x3的并集")
	_expect(state["vision_sources"][MatchState.RED]["elephant_reveal_zones"]["red-elephant-1"] == expected_vision,
			"相视野源应保存完整19格并集")
	_expect(state["vision_sources"][MatchState.RED]["elephant_block_fields"]["red-elephant-1"].size() == 9,
			"相阻挡源应保存田字格九点")
	state["active_side"] = MatchState.BLACK
	var enemy_rook_result: Dictionary = RuleEngine.submit_action(state, _move("black-rook-1", Vector2i(9, 9)))
	_expect(enemy_rook_result.get("event", {}).get("outcome", {}).get("position", []) == [4, 9],
			"敌车从田字格外进入时应停在首个交点")

	var friendly: Dictionary = _empty_state(8403)
	_place(friendly, "red-elephant-1", Vector2i(4, 8))
	_place(friendly, "red-rook-1", Vector2i(1, 9))
	friendly["active_side"] = MatchState.RED
	RuleEngine.submit_action(friendly, _move("red-elephant-1", Vector2i(6, 10)))
	friendly["active_side"] = MatchState.RED
	var friendly_rook_result: Dictionary = RuleEngine.submit_action(friendly, _move("red-rook-1", Vector2i(9, 9)))
	_expect(friendly_rook_result.get("event", {}).get("outcome", {}).get("position", []) == [9, 9],
			"己方相田字格不得阻挡己方车")

	var exiting: Dictionary = _empty_state(8404)
	_place(exiting, "red-elephant-1", Vector2i(4, 8))
	_place(exiting, "black-rook-1", Vector2i(4, 9))
	exiting["active_side"] = MatchState.RED
	RuleEngine.submit_action(exiting, _move("red-elephant-1", Vector2i(6, 10)))
	exiting["active_side"] = MatchState.BLACK
	var exit_result: Dictionary = RuleEngine.submit_action(exiting, _move("black-rook-1", Vector2i(1, 9)))
	_expect(exit_result.get("event", {}).get("outcome", {}).get("position", []) == [1, 9],
			"已在田字格内的敌车下一次应能正常离开")


static func _test_flag_capture_starts_at_one() -> void:
	var state: Dictionary = _empty_state(8405)
	state["flags"] = [_flag("flag-1", Vector2i(5, 12)), _flag("flag-2", Vector2i(3, 15)), _flag("flag-3", Vector2i(8, 10))]
	_place(state, "red-rook-1", Vector2i(5, 11))
	state["active_side"] = MatchState.RED
	RuleEngine.submit_action(state, _move("red-rook-1", Vector2i(5, 12)))
	_expect(state["flags"][0]["capture_progress"] == 1, "踏入隐藏旗应立即显示正在夺旗(1/3)")
	RuleEngine.submit_action(state, _pass())
	_expect(state["flags"][0]["capture_progress"] == 2, "对方一次行动机会后应推进至2/3")
	RuleEngine.submit_action(state, _pass())
	RuleEngine.submit_action(state, _pass())
	_expect(state["flags"][0]["owner"] == MatchState.RED, "第三次进度应完成夺旗")


static func _test_active_advisor_resurrection_pool() -> void:
	var state: Dictionary = _empty_state(8406)
	_place(state, "red-advisor-1", Vector2i(4, 1))
	for piece_value: Variant in state["pieces"].values():
		var pooled_piece: Dictionary = piece_value
		if pooled_piece["side"] == MatchState.RED and pooled_piece["piece_type"] not in ["advisor", "general"] \
		and pooled_piece["id"] != "red-rook-1":
			pooled_piece["in_reserve"] = true
	_kill(state, "red-rook-1")
	_kill(state, "red-advisor-2")
	_kill(state, "red-general-1")
	# 测试动作本身时恢复帅，避免预设终局；帅与阵亡士仍保持死亡池状态。
	state["terminal"] = false
	state["winner"] = ""
	state["win_reason"] = ""
	state["active_side"] = MatchState.RED
	var result: Dictionary = RuleEngine.submit_action(state, {
		"piece_id": "red-advisor-1", "action_type": "resurrect", "target_cell": [],
		"skill_type": "advisor_resurrection",
	})
	_expect(result.get("consumed", false), "士应能主动献祭复活")
	_expect(not state["pieces"]["red-advisor-1"]["alive"], "发动复活的士应阵亡")
	_expect(state["pieces"]["red-rook-1"]["alive"], "随机池仅有车时应复活该车")
	_expect(not state["pieces"]["red-advisor-2"]["alive"], "阵亡士明确不得进入复活随机池")
	_expect(not state["pieces"]["red-general-1"]["alive"], "阵亡帅将不得进入复活随机池")
	_expect(MatchState.is_in_base(Canonical.coordinate(state["pieces"]["red-rook-1"]["position"]), MatchState.RED),
			"复活棋子应随机放入己方大本营")


static func _empty_state(seed_value: int) -> Dictionary:
	var state: Dictionary = RuleEngine.create_match(seed_value)
	for piece_value: Variant in state["pieces"].values():
		var piece: Dictionary = piece_value
		MatchState.remove_piece_from_board(state, piece["id"])
		piece["alive"] = false
		piece["in_reserve"] = false
	state["board"].clear()
	return state


static func _place(state: Dictionary, piece_id: String, cell: Vector2i) -> void:
	MatchState.relocate_piece(state, piece_id, cell)


static func _kill(state: Dictionary, piece_id: String) -> void:
	MatchState.remove_piece_from_board(state, piece_id)
	state["pieces"][piece_id]["alive"] = false
	state["pieces"][piece_id]["in_reserve"] = false


static func _flag(flag_id: String, position: Vector2i) -> Dictionary:
	return {
		"id": flag_id, "position": [position.x, position.y], "owner": MatchState.NEUTRAL,
		"occupier_piece_id": "", "capturing_side": "", "capture_progress": 0, "contested": false,
	}


static func _move(piece_id: String, target: Vector2i) -> Dictionary:
	return {"piece_id": piece_id, "action_type": "move", "target_cell": [target.x, target.y], "skill_type": ""}


static func _pass() -> Dictionary:
	return {"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""}


static func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
