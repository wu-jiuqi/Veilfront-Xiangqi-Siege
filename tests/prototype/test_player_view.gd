extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const Projector = preload("res://scripts/prototype/view/player_view_projector.gd")
const AiPlayerView = preload("res://scripts/prototype/ai/ai_player_view.gd")


static func run_suite() -> bool:
	var failures: Array[String] = []
	var state_a: Dictionary = MatchState.create(80123)
	var state_b: Dictionary = MatchState.clone(state_a)
	MatchState.relocate_piece(state_a, "red-rook-1", Vector2i(1, 9))
	MatchState.relocate_piece(state_b, "red-rook-1", Vector2i(1, 9))
	state_a["walls"][MatchState.BLACK]["status"] = "BREACHED"
	state_b["walls"][MatchState.BLACK]["status"] = "BREACHED"
	MatchState.relocate_piece(state_a, "black-pawn-1", Vector2i(1, 11))
	state_a["pieces"]["black-pawn-1"]["hidden"] = true
	state_a["walls"][MatchState.BLACK]["repair_start_action_index"] = 77
	state_a["walls"][MatchState.BLACK]["sides_acted_since_repair_start"] = [MatchState.RED]
	state_a["walls"][MatchState.BLACK]["invading_piece_count"] = 9
	state_a["flags"][0]["occupier_piece_id"] = "black-pawn-1"
	state_b["flags"][0]["occupier_piece_id"] = "black-pawn-2"
	state_a["flags"][0]["capturing_side"] = MatchState.BLACK
	state_b["flags"][0]["capturing_side"] = MatchState.BLACK
	state_a["flags"][0]["capture_progress"] = 1
	state_b["flags"][0]["capture_progress"] = 1

	var view_a: Dictionary = Projector.project(state_a, MatchState.RED)
	var view_b: Dictionary = Projector.project(state_b, MatchState.RED)
	_expect(Canonical.digest(view_a) == Canonical.digest(view_b), "隐藏差异不得改变 PlayerView", failures)
	_expect(not view_a.has("rng") and not view_a.has("board"), "PlayerView 不得携带 RNG 或完整棋盘", failures)
	for wall: Dictionary in view_a["walls"]:
		_expect(wall.size() == 2 and wall.has("side") and wall.has("status"), "墙投影仅公开阵营与状态", failures)
	_expect(view_a["flags"][0]["occupier_piece_id"] == "", "不可见敌方占旗棋子 ID 必须匿名", failures)
	_expect(not view_a["flags"][0].has("repair_start_action_index"), "旗投影不携带墙修复内部计数", failures)

	var ammo_a: Dictionary = MatchState.create(80124)
	var ammo_b: Dictionary = MatchState.clone(ammo_a)
	MatchState.relocate_piece(ammo_a, "red-rook-1", Vector2i(2, 21))
	MatchState.relocate_piece(ammo_b, "red-rook-1", Vector2i(2, 21))
	ammo_a["pieces"]["black-cannon-1"]["bombard_ammo"] = 0
	ammo_b["pieces"]["black-cannon-1"]["bombard_ammo"] = 2
	var ammo_view_a: Dictionary = Projector.project(ammo_a, MatchState.RED)
	var ammo_view_b: Dictionary = Projector.project(ammo_b, MatchState.RED)
	_expect(Canonical.digest(ammo_view_a) == Canonical.digest(ammo_view_b), "可见敌炮弹药差异不得改变 PlayerView", failures)
	var visible_enemy_cannon: Dictionary = _find_piece(ammo_view_a, "black-cannon-1")
	var owned_cannon: Dictionary = _find_piece(ammo_view_a, "red-cannon-1")
	_expect(not visible_enemy_cannon.is_empty() and not visible_enemy_cannon.has("bombard_ammo"), "敌炮投影省略永久弹药资源", failures)
	_expect(owned_cannon.get("bombard_ammo", -1) == 2, "己方炮投影保留弹药资源", failures)

	var intent: Dictionary = {
		"piece_id": "red-rook-1",
		"action_type": "move",
		"target_cell": [1, 12],
		"skill_type": "",
	}
	var preview_a: Dictionary = Projector.preview_intent(view_a, intent)
	var preview_b: Dictionary = Projector.preview_intent(view_b, intent)
	_expect(preview_a == preview_b, "隐藏阻挡前的查询与错误外形必须不可区分", failures)
	_expect(preview_a["classification"] == Projector.TENTATIVE, "隐藏阻挡意图必须为 TENTATIVE", failures)
	_expect(preview_a["error"] == {"code": "", "fields": []}, "TENTATIVE 查询不得预泄漏错误", failures)

	var ai_projection_a: Dictionary = Projector.export_ai_projection(view_a, [intent])
	var ai_projection_b: Dictionary = Projector.export_ai_projection(view_b, [intent])
	_expect(Canonical.digest(ai_projection_a) == Canonical.digest(ai_projection_b), "隐藏差异不得改变 AI DTO", failures)
	_expect(AiPlayerView.new(ai_projection_a).is_valid(), "真实投影导出的 AI DTO 必须满足 AI 白名单", failures)
	_expect(ai_projection_a["legal_actions"].size() == 1, "TENTATIVE 意图必须可交给 AI，不能暴露完整合法真值", failures)

	var resolved_a: Dictionary = RuleEngine.submit_action(state_a, intent)
	var resolved_b: Dictionary = RuleEngine.submit_action(state_b, intent)
	_expect(resolved_a["event"]["outcome"]["result_code"] == "route_unknown_blocked", "隐藏阻挡返回模糊结果", failures)
	_expect(resolved_b["event"]["outcome"]["result_code"] == "move_resolved", "无隐藏阻挡时移动结算", failures)
	_expect(resolved_a["event"]["outcome"]["position"] == [1, 9], "隐藏阻挡必须原地并消耗行动", failures)
	_expect(resolved_a["event"]["outcome"].keys().has("result_code"), "行动结果包含稳定结果码", failures)
	_expect(state_a["contact_intel"][MatchState.RED].size() == 1, "隐藏接触写入己方情报", failures)
	_expect(state_a["contact_intel"][MatchState.RED][0]["cell"].is_empty(), "模糊路径接触不得公开阻挡坐标", failures)

	var state_c: Dictionary = MatchState.clone(state_b)
	MatchState.relocate_piece(state_c, "black-pawn-1", Vector2i(1, 10))
	var view_c: Dictionary = Projector.project(state_c, MatchState.RED)
	_expect(Projector.preview_intent(view_c, intent)["classification"] == Projector.KNOWN_ILLEGAL, "可见阻挡意图为 KNOWN_ILLEGAL", failures)
	var visible_rejection: Dictionary = RuleEngine.submit_action(state_c, intent)
	_expect(not visible_rejection["consumed"], "可见阻挡必须作为已知非法免费拒绝", failures)
	_expect(state_c["contact_intel"][MatchState.RED].is_empty(), "可见阻挡不写隐藏接触情报", failures)
	for failure: String in failures:
		push_error("PLAYER_VIEW_FAIL: %s" % failure)
	return failures.is_empty()


static func _find_piece(player_view: Dictionary, piece_id: String) -> Dictionary:
	for piece: Dictionary in player_view["pieces"]:
		if piece["id"] == piece_id:
			return piece
	return {}


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
