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
	MatchState.relocate_piece(state_b, "black-pawn-1", Vector2i(2, 12))
	state_a["pieces"]["black-pawn-1"]["hidden"] = true
	state_b["pieces"]["black-pawn-1"]["hidden"] = true
	state_a["walls"][MatchState.BLACK]["repair_start_action_index"] = 77
	state_a["walls"][MatchState.BLACK]["sides_acted_since_repair_start"] = [MatchState.RED]
	state_a["walls"][MatchState.BLACK]["invading_piece_count"] = 9
	state_a["flags"][0]["occupier_piece_id"] = "black-pawn-1"
	state_b["flags"][0]["occupier_piece_id"] = "black-pawn-1"
	state_a["flags"][0]["capturing_side"] = MatchState.BLACK
	state_b["flags"][0]["capturing_side"] = MatchState.BLACK
	state_a["flags"][0]["capture_progress"] = 1
	state_b["flags"][0]["capture_progress"] = 1

	var view_a: Dictionary = Projector.project(state_a, MatchState.RED)
	var view_b: Dictionary = Projector.project(state_b, MatchState.RED)
	_expect(Canonical.digest(view_a) == Canonical.digest(view_b), "隐藏差异不得改变 PlayerView", failures)
	_expect(not view_a.has("rng") and not view_a.has("board"), "PlayerView 不得携带 RNG 或完整棋盘", failures)
	_expect(view_a["match_seed"] == 80123, "PlayerView 只公开本局 seed 引用而非 RNG 状态", failures)
	_expect(view_a["full_round_limit_hypothesis"] == 50, "PlayerView 公开实际 50 回合试玩假设", failures)
	_expect(view_a["round_limit_status"] == "hypothesis_cli_overridable", "PlayerView 保留回合上限假设状态", failures)
	_expect(view_a["rules_revision"] == "owner-confirm-2026-08-16-breached-wall-vision" \
		and view_a["implementation_revision"] == "prototype-core-revision-5", "PlayerView 公开规则与实现 revision", failures)
	for wall: Dictionary in view_a["walls"]:
		_expect(wall.size() == 2 and wall.has("side") and wall.has("status"), "墙投影仅公开阵营与状态", failures)
	_expect(view_a["flags"][0]["occupier_piece_id"] == "", "不可见敌方占旗棋子 ID 必须匿名", failures)
	_expect(not view_a["flags"][0].has("repair_start_action_index"), "旗投影不携带墙修复内部计数", failures)
	_test_breached_wall_region_visibility(failures)

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


static func _test_breached_wall_region_visibility(failures: Array[String]) -> void:
	var state: Dictionary = MatchState.create(80125)
	var intact_red_view: Dictionary = Projector.project(state, MatchState.RED)
	_expect(not _has_cell(intact_red_view, Vector2i(1, 17)), "黑墙完整时红方不获得黑方缓冲区全视野", failures)
	_expect(_find_piece(intact_red_view, "black-rook-1").is_empty(), "黑墙完整时红方看不到黑方营内非邻近棋子", failures)

	state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	var breached_red_view: Dictionary = Projector.project(state, MatchState.RED)
	_expect(_region_is_fully_visible(breached_red_view, MatchState.BLACK), "黑墙倒塌时红方看见黑方缓冲区与大本营全部格子", failures)
	_expect(not _find_piece(breached_red_view, "black-rook-1").is_empty(), "黑墙倒塌时红方看见黑方营内非隐身棋子", failures)

	state["pieces"]["black-horse-1"]["hidden"] = true
	var hidden_horse_view: Dictionary = Projector.project(state, MatchState.RED)
	_expect(_find_piece(hidden_horse_view, "black-horse-1").is_empty(), "城墙倒塌全视野不额外驱散隐身马", failures)

	state["walls"][MatchState.BLACK]["status"] = "REPAIRING"
	var repairing_red_view: Dictionary = Projector.project(state, MatchState.RED)
	_expect(_region_is_fully_visible(repairing_red_view, MatchState.BLACK), "黑墙修复中仍按倒塌状态保留红方全域视野", failures)

	state["walls"][MatchState.BLACK]["status"] = "INTACT"
	var restored_red_view: Dictionary = Projector.project(state, MatchState.RED)
	_expect(not _has_cell(restored_red_view, Vector2i(1, 17)), "黑墙恢复后红方失去黑方缓冲区额外视野", failures)
	_expect(_find_piece(restored_red_view, "black-rook-1").is_empty(), "黑墙恢复后黑方营内非邻近棋子重新入雾", failures)

	var mirrored_state: Dictionary = MatchState.create(80126)
	mirrored_state["walls"][MatchState.RED]["status"] = "BREACHED"
	var breached_black_view: Dictionary = Projector.project(mirrored_state, MatchState.BLACK)
	_expect(_region_is_fully_visible(breached_black_view, MatchState.RED), "红墙倒塌时黑方对称获得红方缓冲区与大本营全视野", failures)


static func _region_is_fully_visible(player_view: Dictionary, region_side: String) -> bool:
	var first_y: int = 1 if region_side == MatchState.RED else 17
	var last_y: int = 8 if region_side == MatchState.RED else 24
	for y: int in range(first_y, last_y + 1):
		for x: int in range(1, MatchState.BOARD_WIDTH + 1):
			if not _has_cell(player_view, Vector2i(x, y)):
				return false
	return true


static func _has_cell(player_view: Dictionary, cell: Vector2i) -> bool:
	return [cell.x, cell.y] in player_view.get("visible_cells", [])


static func _find_piece(player_view: Dictionary, piece_id: String) -> Dictionary:
	for piece: Dictionary in player_view["pieces"]:
		if piece["id"] == piece_id:
			return piece
	return {}


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
