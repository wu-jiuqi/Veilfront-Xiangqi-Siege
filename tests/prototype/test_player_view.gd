extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const Projector = preload("res://scripts/prototype/view/player_view_projector.gd")
const AiPlayerView = preload("res://scripts/prototype/ai/ai_player_view.gd")


static func run_suite() -> bool:
	var state_a: Dictionary = MatchState.create(80123)
	var state_b: Dictionary = MatchState.clone(state_a)
	MatchState.relocate_piece(state_a, "red-rook-1", Vector2i(1, 9))
	MatchState.relocate_piece(state_b, "red-rook-1", Vector2i(1, 9))
	MatchState.relocate_piece(state_a, "black-pawn-1", Vector2i(1, 11))
	state_a["pieces"]["black-pawn-1"]["hidden"] = true

	var view_a: Dictionary = Projector.project(state_a, MatchState.RED)
	var view_b: Dictionary = Projector.project(state_b, MatchState.RED)
	assert(Canonical.digest(view_a) == Canonical.digest(view_b), "隐藏差异不得改变 PlayerView")
	assert(not view_a.has("rng") and not view_a.has("board"), "PlayerView 不得携带 RNG 或完整棋盘")

	var intent: Dictionary = {
		"piece_id": "red-rook-1",
		"action_type": "move",
		"target_cell": [1, 12],
		"skill_type": "",
	}
	var preview_a: Dictionary = Projector.preview_intent(view_a, intent)
	var preview_b: Dictionary = Projector.preview_intent(view_b, intent)
	assert(preview_a == preview_b, "隐藏阻挡前的查询与错误外形必须不可区分")
	assert(preview_a["classification"] == Projector.TENTATIVE)
	assert(preview_a["error"] == {"code": "", "fields": []})

	var ai_projection_a: Dictionary = Projector.export_ai_projection(view_a, [intent])
	var ai_projection_b: Dictionary = Projector.export_ai_projection(view_b, [intent])
	assert(Canonical.digest(ai_projection_a) == Canonical.digest(ai_projection_b))
	assert(AiPlayerView.new(ai_projection_a).is_valid(), "真实投影导出的 AI DTO 必须满足 AI 白名单")
	assert(ai_projection_a["legal_actions"].size() == 1, "TENTATIVE 意图必须可交给 AI，不能暴露完整合法真值")

	var resolved_a: Dictionary = RuleEngine.submit_action(state_a, intent)
	var resolved_b: Dictionary = RuleEngine.submit_action(state_b, intent)
	assert(resolved_a["event"]["outcome"]["result_code"] == "route_unknown_blocked")
	assert(resolved_b["event"]["outcome"]["result_code"] == "move_resolved")
	assert(resolved_a["event"]["outcome"]["position"] == [1, 9], "隐藏阻挡必须原地并消耗行动")
	assert(resolved_a["event"]["outcome"].keys().has("result_code"))
	assert(state_a["contact_intel"][MatchState.RED].size() == 1)
	assert(state_a["contact_intel"][MatchState.RED][0]["cell"].is_empty(), "模糊路径接触不得公开阻挡坐标")

	var state_c: Dictionary = MatchState.clone(state_b)
	MatchState.relocate_piece(state_c, "black-pawn-1", Vector2i(1, 10))
	var view_c: Dictionary = Projector.project(state_c, MatchState.RED)
	assert(Projector.preview_intent(view_c, intent)["classification"] == Projector.KNOWN_ILLEGAL)
	var visible_rejection: Dictionary = RuleEngine.submit_action(state_c, intent)
	assert(not visible_rejection["consumed"], "可见阻挡必须作为已知非法免费拒绝")
	assert(state_c["contact_intel"][MatchState.RED].is_empty())
	return true
