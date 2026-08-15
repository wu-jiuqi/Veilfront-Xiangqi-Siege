extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const MoveRules = preload("res://scripts/prototype/core/move_rules.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const Projector = preload("res://scripts/prototype/view/player_view_projector.gd")


static func run_suite() -> bool:
	var failures: Array[String] = []
	_test_rook_path_resolution(failures)
	_test_horse_hidden_contact(failures)
	_test_elephant_reveal_strategy_lifecycle(failures)
	_test_hidden_cannon_screens(failures)
	_test_player_event_filter(failures)
	_test_public_flag_wall_whitelist(failures)
	_test_ai_action_semantics(failures)
	_test_blind_capture_target_classification(failures)
	_test_route_failure_target_identity_boundary(failures)
	_test_pawn_public_candidates_and_special_contact(failures)
	_test_cannon_target_contact_boundary(failures)
	_test_transient_sources_clear_on_exit(failures)
	_test_rescued_hidden_contact_authorization(failures)
	for failure: String in failures:
		push_error("REVISION3_RULE_FAIL: %s" % failure)
	return failures.is_empty()


static func _test_rook_path_resolution(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(401)
	_place(state, "red-rook-1", Vector2i(5, 10))
	_place(state, "black-pawn-1", Vector2i(5, 12))
	_place(state, "black-pawn-2", Vector2i(5, 14))
	_place(state, "black-advisor-1", Vector2i(4, 24))
	_place(state, "black-advisor-2", Vector2i(6, 24))
	var result: Dictionary = RuleEngine.submit_action(state, _move("red-rook-1", Vector2i(5, 15)))
	var casualties: Array = result.get("event", {}).get("outcome", {}).get("casualties", [])
	_expect(result.get("ok", false) and casualties.size() == 2, "特殊车逐目标结算两枚敌棋", failures)
	_expect(casualties.size() == 2 and casualties[0]["piece_id"] == "black-pawn-1" \
		and casualties[1]["piece_id"] == "black-pawn-2", "特殊车保持起点到终点顺序", failures)
	_expect(casualties.size() == 2 and casualties[0]["rescued"] and casualties[1]["rescued"], "普通吃子同样执行前两次士替死", failures)
	var base_entry: Dictionary = _empty_state(409)
	base_entry["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(base_entry, "red-rook-1", Vector2i(5, 19))
	_place(base_entry, "black-pawn-1", Vector2i(5, 20))
	_place(base_entry, "black-general-1", Vector2i(5, 24))
	var blocked: Dictionary = MoveRules.evaluate_move(base_entry, _move("red-rook-1", Vector2i(5, 24)), MatchState.RED, _all_visible(base_entry))
	_expect(not blocked.get("legal", true) and blocked.get("reason", "") == "route_blocked", "跨入大本营的车恢复普通路径阻挡", failures)
	MatchState.remove_piece_from_board(base_entry, "black-pawn-1")
	base_entry["pieces"]["black-pawn-1"]["alive"] = false
	var ordinary_eval: Dictionary = MoveRules.evaluate_move(base_entry, _move("red-rook-1", Vector2i(5, 24)), MatchState.RED, _all_visible(base_entry))
	_expect(ordinary_eval.get("legal", false) and ordinary_eval.get("move_kind", "") == "rook_standard", "进入大本营捕将只能使用普通车规则", failures)
	var ordinary_result: Dictionary = RuleEngine.submit_action(base_entry, _move("red-rook-1", Vector2i(5, 24)))
	_expect(ordinary_result.get("consumed", false) and Canonical.coordinate(base_entry["pieces"]["red-rook-1"]["position"]) == Vector2i(5, 24) \
		and base_entry["board"].get("5,24", "") == "red-rook-1", "普通车捕将落到目标格", failures)


static func _test_horse_hidden_contact(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(403)
	state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(state, "red-horse-1", Vector2i(5, 10))
	_place(state, "black-horse-1", Vector2i(6, 10))
	state["pieces"]["black-horse-1"]["hidden"] = true
	var intent: Dictionary = _move("red-horse-1", Vector2i(7, 11))
	var view: Dictionary = Projector.project(state, MatchState.RED)
	_expect(Projector.preview_intent(view, intent)["classification"] == Projector.TENTATIVE, "未显形隐身马腿只能标可尝试", failures)
	var result: Dictionary = RuleEngine.submit_action(state, intent)
	_expect(result.get("consumed", false) and result["event"]["outcome"]["result_code"] == "route_unknown_blocked", "隐藏马腿失败消耗行动", failures)
	_expect(state["contact_intel"][MatchState.RED].back()["cell"].is_empty(), "隐藏腿阻不公开坐标", failures)


static func _test_elephant_reveal_strategy_lifecycle(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(404)
	_place(state, "red-elephant-1", Vector2i(5, 10))
	_place(state, "black-horse-1", Vector2i(6, 11))
	state["pieces"]["black-horse-1"]["hidden"] = true
	var first: Dictionary = RuleEngine.submit_action(state, _move("red-elephant-1", Vector2i(7, 12)))
	_expect(first.get("ok", false), "相象显形策略首个特殊移动可执行", failures)
	var first_view: Dictionary = Projector.project(state, MatchState.RED)
	_expect(_view_has_piece(first_view, "black-horse-1"), "当前技术假设显形区能投影隐身马", failures)
	state["active_side"] = MatchState.RED
	var second: Dictionary = RuleEngine.submit_action(state, _move("red-elephant-1", Vector2i(9, 14)))
	_expect(second.get("ok", false), "相象第二次特殊移动可刷新显形区", failures)
	var second_view: Dictionary = Projector.project(state, MatchState.RED)
	_expect(not _view_has_piece(second_view, "black-horse-1"), "旧田字显形区立即失效", failures)
	_expect(state["vision_sources"][MatchState.RED]["elephant_reveal_zones"].size() == 1, "每枚相象只保留最新可替换策略区", failures)


static func _test_hidden_cannon_screens(failures: Array[String]) -> void:
	var zero: Dictionary = _cannon_pair_state(405, 0)
	var one: Dictionary = _cannon_pair_state(405, 1)
	var two: Dictionary = _cannon_pair_state(405, 2)
	var intent: Dictionary = _move("red-cannon-1", Vector2i(2, 14))
	var zero_view: Dictionary = Projector.project(zero, MatchState.RED)
	var one_view: Dictionary = Projector.project(one, MatchState.RED)
	var two_view: Dictionary = Projector.project(two, MatchState.RED)
	_expect(Canonical.digest(zero_view) == Canonical.digest(one_view) \
		and Canonical.digest(one_view) == Canonical.digest(two_view), "隐藏炮架差异保持 PlayerView 等价", failures)
	_expect(Projector.preview_intent(zero_view, intent)["classification"] == Projector.TENTATIVE \
		and Projector.preview_intent(one_view, intent)["classification"] == Projector.TENTATIVE \
		and Projector.preview_intent(two_view, intent)["classification"] == Projector.TENTATIVE, "0/1/2 隐藏炮架均为相同 TENTATIVE", failures)
	var zero_result: Dictionary = RuleEngine.submit_action(zero, intent)
	var one_result: Dictionary = RuleEngine.submit_action(one, intent)
	var two_result: Dictionary = RuleEngine.submit_action(two, intent)
	_expect(zero_result["event"]["outcome"]["result_code"] == "cannon_path_invalid" \
		and two_result["event"]["outcome"]["result_code"] == "cannon_path_invalid", "零或多炮架统一失败外形", failures)
	_expect(one_result["event"]["outcome"]["result_code"] == "move_resolved", "恰一隐藏炮架精确吃子成功", failures)


static func _test_player_event_filter(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(406)
	state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(state, "red-rook-1", Vector2i(1, 9))
	var result: Dictionary = RuleEngine.submit_action(state, _move("red-rook-1", Vector2i(1, 12)))
	_expect(result.get("ok", false), "雾中移动完成", failures)
	_expect(state["player_events"][MatchState.RED].size() == 1 \
		and state["player_events"][MatchState.BLACK].is_empty(), "不可见移动事件不投给对手", failures)
	result = RuleEngine.submit_action(state, {"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""})
	_expect(result.get("ok", false) and state["player_events"][MatchState.RED].size() == 2, "公开跳过事件投给双方", failures)


static func _test_public_flag_wall_whitelist(failures: Array[String]) -> void:
	var state_a: Dictionary = _empty_state(407)
	var state_b: Dictionary = MatchState.clone(state_a)
	var flag_cell := Canonical.coordinate(state_a["flags"][0]["position"])
	_place(state_a, "black-horse-1", flag_cell)
	_place(state_b, "black-horse-2", flag_cell)
	state_a["pieces"]["black-horse-1"]["hidden"] = true
	state_b["pieces"]["black-horse-2"]["hidden"] = true
	for state: Dictionary in [state_a, state_b]:
		state["flags"][0]["owner"] = MatchState.RED
		state["flags"][0]["capturing_side"] = MatchState.BLACK
		state["flags"][0]["capture_progress"] = 1
		state["flags"][0]["contested"] = true
	state_a["flags"][0]["occupier_piece_id"] = "black-horse-1"
	state_b["flags"][0]["occupier_piece_id"] = "black-horse-2"
	state_a["walls"][MatchState.BLACK]["repair_start_action_index"] = 3
	state_b["walls"][MatchState.BLACK]["repair_start_action_index"] = 99
	state_a["walls"][MatchState.BLACK]["sides_acted_since_repair_start"] = [MatchState.RED]
	state_b["walls"][MatchState.BLACK]["sides_acted_since_repair_start"] = [MatchState.BLACK]
	state_a["walls"][MatchState.BLACK]["invading_piece_count"] = 1
	state_b["walls"][MatchState.BLACK]["invading_piece_count"] = 2
	var view_a: Dictionary = Projector.project(state_a, MatchState.RED)
	var view_b: Dictionary = Projector.project(state_b, MatchState.RED)
	_expect(Canonical.digest(view_a) == Canonical.digest(view_b), "隐藏旗占领者与墙内部计时差异不改变投影", failures)
	_expect(view_a["walls"][1].size() == 2 and view_a["walls"][1].has("side") \
		and view_a["walls"][1].has("status"), "墙投影严格白名单 side/status", failures)
	_expect(view_a["flags"][0]["occupier_piece_id"].is_empty(), "不可见敌占领者ID匿名", failures)
	var own_state: Dictionary = _empty_state(408)
	var own_flag_cell := Canonical.coordinate(own_state["flags"][0]["position"])
	_place(own_state, "red-pawn-1", own_flag_cell)
	own_state["flags"][0]["occupier_piece_id"] = "red-pawn-1"
	_expect(Projector.project(own_state, MatchState.RED)["flags"][0]["occupier_piece_id"] == "red-pawn-1", "自有占领者ID可见", failures)


static func _test_ai_action_semantics(failures: Array[String]) -> void:
	var bombard_state: Dictionary = _empty_state(410)
	_place(bombard_state, "red-cannon-1", Vector2i(2, 3))
	_place(bombard_state, "red-rook-1", Vector2i(4, 12))
	_place(bombard_state, "black-pawn-1", Vector2i(5, 12))
	bombard_state["flags"][0]["position"] = [5, 12]
	var bombard_intent: Dictionary = {
		"piece_id": "red-cannon-1", "action_type": "bombard",
		"target_cell": [5, 12], "skill_type": "area_bombardment",
	}
	var bombard_dto: Dictionary = Projector.export_ai_projection(
		Projector.project(bombard_state, MatchState.RED), [bombard_intent]
	)
	var bombard_action: Dictionary = bombard_dto["legal_actions"][0]
	_expect(bombard_action["visible_captures"].is_empty() and bombard_action["reveal_cell_count"] == 0 \
		and not bombard_action["occupies_flag"] and bombard_action["path_length"] == 0,
		"炮击 DTO 不伪造移动式捕获/显形/占旗/路径评分", failures)

	var rook_state: Dictionary = _empty_state(411)
	_place(rook_state, "red-rook-1", Vector2i(5, 10))
	_place(rook_state, "red-advisor-1", Vector2i(4, 13))
	_place(rook_state, "black-pawn-1", Vector2i(5, 11))
	_place(rook_state, "black-horse-1", Vector2i(5, 12))
	_place(rook_state, "black-pawn-2", Vector2i(5, 13))
	rook_state["pieces"]["black-horse-1"]["hidden"] = true
	var rook_dto: Dictionary = Projector.export_ai_projection(
		Projector.project(rook_state, MatchState.RED), [_move("red-rook-1", Vector2i(5, 15))]
	)
	var captures: Array = rook_dto["legal_actions"][0]["visible_captures"]
	_expect(captures == [
		{"piece_id": "black-pawn-1", "piece_type": "pawn"},
		{"piece_id": "black-pawn-2", "piece_type": "pawn"},
	], "特殊车 DTO 按路径列出可见多目标且不泄漏隐藏目标", failures)


static func _test_blind_capture_target_classification(failures: Array[String]) -> void:
	var empty_target: Dictionary = _empty_state(412)
	empty_target["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(empty_target, "red-pawn-1", Vector2i(5, 10))
	var hidden_target: Dictionary = MatchState.clone(empty_target)
	_place(hidden_target, "black-horse-1", Vector2i(5, 11))
	hidden_target["pieces"]["black-horse-1"]["hidden"] = true
	var intent: Dictionary = _move("red-pawn-1", Vector2i(5, 11))
	var empty_view: Dictionary = Projector.project(empty_target, MatchState.RED)
	var hidden_view: Dictionary = Projector.project(hidden_target, MatchState.RED)
	_expect(Canonical.digest(empty_view) == Canonical.digest(hidden_view), "空目标与隐藏敌目标投影等价", failures)
	_expect(Projector.preview_intent(empty_view, intent)["classification"] == Projector.KNOWN_LEGAL \
		and Projector.preview_intent(hidden_view, intent)["classification"] == Projector.KNOWN_LEGAL,
		"普通可吃子移动的雾中目标不产生 TENTATIVE", failures)
	var empty_result: Dictionary = RuleEngine.submit_action(empty_target, intent)
	var hidden_result: Dictionary = RuleEngine.submit_action(hidden_target, intent)
	_expect(empty_result.get("consumed", false) and hidden_result.get("consumed", false) \
		and not hidden_target["pieces"]["black-horse-1"]["alive"], "空格移动与隐藏敌盲吃均可结算", failures)
	var empty_captures: Array = empty_target["player_events"][MatchState.RED].back()["authorized_captures"]
	var hidden_captures: Array = hidden_target["player_events"][MatchState.RED].back()["authorized_captures"]
	_expect(empty_captures.is_empty() and hidden_captures == [{
		"piece_id": "black-horse-1", "piece_type": "horse", "rescued": false,
	}], "盲吃后仅actor通过固定白名单获知被吃身份", failures)
	var event_keys: Array = hidden_target["player_events"][MatchState.RED].back().keys()
	event_keys.sort()
	_expect(event_keys == ["actor_side", "authorized_captures", "event_type", "id", "position", "public_code", "schema_version"],
		"捕获授权事件不携带额外 FullState 字段", failures)


static func _test_route_failure_target_identity_boundary(failures: Array[String]) -> void:
	var no_target: Dictionary = _empty_state(413)
	no_target["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(no_target, "red-horse-1", Vector2i(5, 10))
	_place(no_target, "black-horse-1", Vector2i(6, 10))
	no_target["pieces"]["black-horse-1"]["hidden"] = true
	var hidden_target: Dictionary = MatchState.clone(no_target)
	_place(hidden_target, "black-horse-2", Vector2i(7, 11))
	hidden_target["pieces"]["black-horse-2"]["hidden"] = true
	var intent: Dictionary = _move("red-horse-1", Vector2i(7, 11))
	_expect(Canonical.digest(Projector.project(no_target, MatchState.RED)) \
		== Canonical.digest(Projector.project(hidden_target, MatchState.RED)), "前置阻挡配对决策前投影等价", failures)
	var first: Dictionary = RuleEngine.submit_action(no_target, intent)
	var second: Dictionary = RuleEngine.submit_action(hidden_target, intent)
	_expect(first["event"]["outcome"] == second["event"]["outcome"] \
		and no_target["contact_intel"][MatchState.RED] == hidden_target["contact_intel"][MatchState.RED] \
		and no_target["player_events"][MatchState.RED] == hidden_target["player_events"][MatchState.RED],
		"前置阻挡失败不得读取或发布终点隐藏马身份", failures)


static func _test_pawn_public_candidates_and_special_contact(failures: Array[String]) -> void:
	var initial_view: Dictionary = Projector.project(MatchState.create(414), MatchState.RED)
	var generated: Array = Projector.generate_action_intents(initial_view)
	for preview: Dictionary in generated:
		if preview["piece_id"] != "red-pawn-1" or preview["classification"] == Projector.KNOWN_ILLEGAL:
			continue
		var target := Canonical.coordinate(preview["target_cell"])
		_expect(target.y >= 4 and absi(target.x - 1) + absi(target.y - 4) == 1,
			"普通兵公开候选无后退或多格非法动作", failures)

	var empty_target: Dictionary = _empty_state(415)
	_place(empty_target, "red-pawn-1", Vector2i(5, 10))
	var hidden_target: Dictionary = MatchState.clone(empty_target)
	_place(hidden_target, "black-horse-1", Vector2i(5, 15))
	hidden_target["pieces"]["black-horse-1"]["hidden"] = true
	var intent: Dictionary = _move("red-pawn-1", Vector2i(5, 15))
	var empty_view: Dictionary = Projector.project(empty_target, MatchState.RED)
	var hidden_view: Dictionary = Projector.project(hidden_target, MatchState.RED)
	_expect(Canonical.digest(empty_view) == Canonical.digest(hidden_view), "特殊兵雾中空/隐藏敌终点投影等价", failures)
	_expect(Projector.preview_intent(empty_view, intent)["classification"] == Projector.TENTATIVE \
		and Projector.preview_intent(hidden_view, intent)["classification"] == Projector.TENTATIVE,
		"特殊兵终点必须空，雾中终点统一TENTATIVE", failures)
	var empty_result: Dictionary = RuleEngine.submit_action(empty_target, intent)
	var hidden_result: Dictionary = RuleEngine.submit_action(hidden_target, intent)
	_expect(empty_result["event"]["outcome"]["result_code"] == "move_resolved" \
		and hidden_result["event"]["outcome"]["result_code"] == "target_unknown_occupied",
		"特殊兵空终点成功、隐藏占据终点在真实接触失败", failures)
	_expect(hidden_target["contact_intel"][MatchState.RED].back()["cell"] == [5, 15] \
		and hidden_target["contact_intel"][MatchState.RED].back()["revealed_identity"] == "black-horse-1",
		"特殊兵真实终点接触授权坐标与隐藏马身份", failures)
	var blocked: Dictionary = _empty_state(416)
	_place(blocked, "red-pawn-1", Vector2i(5, 10))
	_place(blocked, "red-rook-1", Vector2i(5, 12))
	_place(blocked, "black-horse-1", Vector2i(5, 15))
	blocked["pieces"]["black-horse-1"]["hidden"] = true
	var evaluation: Dictionary = MoveRules.evaluate_move(blocked, intent, MatchState.RED, _all_visible(blocked))
	_expect(not evaluation.get("legal", true) and not evaluation.get("contact_reached_target", false),
		"特殊兵更早路径阻挡不得授权终点接触", failures)


static func _test_cannon_target_contact_boundary(failures: Array[String]) -> void:
	var direct: Dictionary = _empty_state(417)
	_place(direct, "red-cannon-1", Vector2i(2, 10))
	_place(direct, "black-horse-1", Vector2i(2, 14))
	direct["pieces"]["black-horse-1"]["hidden"] = true
	var intent: Dictionary = _move("red-cannon-1", Vector2i(2, 14))
	var direct_result: Dictionary = RuleEngine.submit_action(direct, intent)
	_expect(direct_result["event"]["outcome"]["result_code"] == "target_unknown_occupied" \
		and direct["contact_intel"][MatchState.RED].back()["cell"] == [2, 14] \
		and direct["contact_intel"][MatchState.RED].back()["revealed_identity"] == "black-horse-1",
		"炮无前置炮架时真实接触隐藏目标并授权显形", failures)

	var no_target: Dictionary = _empty_state(418)
	_place(no_target, "red-cannon-1", Vector2i(2, 10))
	_place(no_target, "black-horse-1", Vector2i(2, 12))
	no_target["pieces"]["black-horse-1"]["hidden"] = true
	var hidden_target: Dictionary = MatchState.clone(no_target)
	_place(hidden_target, "black-horse-2", Vector2i(2, 14))
	hidden_target["pieces"]["black-horse-2"]["hidden"] = true
	var first: Dictionary = RuleEngine.submit_action(no_target, intent)
	var second: Dictionary = RuleEngine.submit_action(hidden_target, intent)
	_expect(first["event"]["outcome"] == second["event"]["outcome"] \
		and first["event"]["outcome"]["result_code"] == "cannon_path_invalid" \
		and no_target["contact_intel"][MatchState.RED] == hidden_target["contact_intel"][MatchState.RED],
		"炮更早隐藏炮架失败不得读取或发布终点隐藏马", failures)


static func _test_transient_sources_clear_on_exit(failures: Array[String]) -> void:
	var captured: Dictionary = _empty_state(419)
	captured["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(captured, "red-rook-1", Vector2i(5, 10))
	_place(captured, "black-rook-1", Vector2i(5, 12))
	captured["vision_sources"][MatchState.BLACK]["rook_paths"]["black-rook-1"] = [[5, 11], [5, 12]]
	RuleEngine.submit_action(captured, _move("red-rook-1", Vector2i(5, 12)))
	_expect(not captured["vision_sources"][MatchState.BLACK]["rook_paths"].has("black-rook-1"),
		"普通吃死清除棋子旧车视野源", failures)

	var bombed: Dictionary = _empty_state(420)
	_place(bombed, "black-elephant-1", Vector2i(4, 12))
	bombed["vision_sources"][MatchState.BLACK]["elephant_reveal_zones"]["black-elephant-1"] = [[4, 12]]
	RuleEngine.resolve_bombardment_window(bombed, "red-cannon-1", Vector2i(5, 12), [
		Vector2i(4, 12), Vector2i(5, 12), Vector2i(6, 12),
	])
	_expect(not bombed["vision_sources"][MatchState.BLACK]["elephant_reveal_zones"].has("black-elephant-1"),
		"炮击直接阵亡清除相象旧显形源", failures)

	var rescued: Dictionary = _empty_state(421)
	_place(rescued, "red-pawn-1", Vector2i(4, 12))
	_place(rescued, "red-advisor-1", Vector2i(4, 1))
	rescued["vision_sources"][MatchState.RED]["elephant_reveal_zones"]["red-advisor-1"] = [[4, 12]]
	RuleEngine.resolve_bombardment_window(rescued, "black-cannon-1", Vector2i(5, 12), [
		Vector2i(4, 12), Vector2i(5, 12), Vector2i(6, 12),
	])
	_expect(not rescued["pieces"]["red-advisor-1"]["alive"] \
		and not rescued["vision_sources"][MatchState.RED]["elephant_reveal_zones"].has("red-advisor-1"),
		"士替死牺牲清除其旧视野源", failures)

	var reserve: Dictionary = MatchState.create(422)
	MatchState.relocate_piece(reserve, "red-rook-1", Vector2i(5, 10))
	_fill_base_with_blockers(reserve, MatchState.RED)
	reserve["vision_sources"][MatchState.RED]["rook_paths"]["red-rook-1"] = [[5, 11]]
	RuleEngine.return_pieces_to_base(reserve, MatchState.RED, ["red-rook-1"], "test_reserve")
	_expect(reserve["pieces"]["red-rook-1"]["in_reserve"] \
		and not reserve["vision_sources"][MatchState.RED]["rook_paths"].has("red-rook-1"),
		"回营进入后备队列清除旧车视野源", failures)

	var withdrawn: Dictionary = _empty_state(423)
	_place(withdrawn, "red-elephant-1", Vector2i(5, 22))
	withdrawn["vision_sources"][MatchState.RED]["elephant_reveal_zones"]["red-elephant-1"] = [[5, 22]]
	withdrawn["walls"][MatchState.BLACK]["status"] = "REPAIRING"
	withdrawn["walls"][MatchState.BLACK]["sides_acted_since_repair_start"] = [MatchState.RED]
	withdrawn["active_side"] = MatchState.BLACK
	RuleEngine.submit_action(withdrawn, {"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""})
	_expect(withdrawn["walls"][MatchState.BLACK]["status"] == "INTACT" \
		and not MatchState.is_in_base(Canonical.coordinate(withdrawn["pieces"]["red-elephant-1"]["position"]), MatchState.BLACK) \
		and not withdrawn["vision_sources"][MatchState.RED]["elephant_reveal_zones"].has("red-elephant-1"),
		"墙修复撤回清除旧相象显形源", failures)


static func _test_rescued_hidden_contact_authorization(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(424)
	_place(state, "red-rook-1", Vector2i(5, 10))
	_place(state, "black-horse-1", Vector2i(5, 12))
	_place(state, "black-advisor-1", Vector2i(4, 24))
	state["pieces"]["black-horse-1"]["hidden"] = true
	var result: Dictionary = RuleEngine.submit_action(state, _move("red-rook-1", Vector2i(5, 12)))
	var captures: Array = state["player_events"][MatchState.RED].back()["authorized_captures"]
	_expect(result.get("consumed", false) and state["pieces"]["black-horse-1"]["alive"] \
		and captures == [{"piece_id": "black-horse-1", "piece_type": "horse", "rescued": true}],
		"盲吃触发士替死时actor仍获知实际接触目标及rescued结果", failures)


static func _cannon_pair_state(seed_value: int, screen_count: int) -> Dictionary:
	var state: Dictionary = _empty_state(seed_value)
	_place(state, "red-cannon-1", Vector2i(2, 10))
	_place(state, "red-rook-1", Vector2i(3, 14))
	_place(state, "black-pawn-1", Vector2i(2, 14))
	var horse_cells: Array[Vector2i] = [Vector2i(9, 18), Vector2i(9, 17)]
	if screen_count >= 1:
		horse_cells[0] = Vector2i(2, 12)
	if screen_count >= 2:
		horse_cells[1] = Vector2i(2, 11)
	for index: int in 2:
		var horse_id: String = "black-horse-%d" % (index + 1)
		_place(state, horse_id, horse_cells[index])
		state["pieces"][horse_id]["hidden"] = true
	return state


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
		MatchState.remove_piece_from_board(state, occupant["id"])
		occupant["alive"] = false
	state["pieces"][piece_id]["alive"] = true
	state["pieces"][piece_id]["in_reserve"] = false
	MatchState.relocate_piece(state, piece_id, cell)


static func _move(piece_id: String, target: Vector2i) -> Dictionary:
	return {"piece_id": piece_id, "action_type": "move", "target_cell": [target.x, target.y], "skill_type": ""}


static func _view_has_piece(view: Dictionary, piece_id: String) -> bool:
	for piece: Dictionary in view["pieces"]:
		if piece["id"] == piece_id:
			return true
	return false


static func _all_visible(state: Dictionary) -> Dictionary:
	var cells: Array = []
	for y: int in range(1, MatchState.BOARD_HEIGHT + 1):
		for x: int in range(1, MatchState.BOARD_WIDTH + 1):
			cells.append([x, y])
	return {"visible_cells": cells, "visible_piece_ids": state["pieces"].keys()}


static func _fill_base_with_blockers(state: Dictionary, side: String) -> void:
	var empty_cells: Array = MatchState.base_empty_cells(state, side)
	for index: int in empty_cells.size():
		var cell: Vector2i = empty_cells[index]
		var piece_id: String = "revision3-blocker-%s-%d" % [side, index]
		state["pieces"][piece_id] = {
			"id": piece_id, "side": side, "piece_type": "blocker",
			"position": [cell.x, cell.y], "alive": true, "in_reserve": false,
			"reserve_queue_index": -1, "hidden": false, "revealed_to": [],
			"bombard_ammo": 0, "rescue_available": false, "temporary_effects": [],
		}
		state["board"][Canonical.cell_key(cell)] = piece_id


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
