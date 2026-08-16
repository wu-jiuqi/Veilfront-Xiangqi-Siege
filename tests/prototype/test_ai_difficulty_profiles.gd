extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const Projector = preload("res://scripts/prototype/view/player_view_projector.gd")
const AiPlayerView = preload("res://scripts/prototype/ai/ai_player_view.gd")
const PublicRules = preload("res://scripts/prototype/ai/ai_public_rules.gd")
const Memory = preload("res://scripts/prototype/ai/ai_memory.gd")
const DecisionEngine = preload("res://scripts/prototype/ai/ai_decision_engine.gd")
const AiSeedDeriver = preload("res://scripts/prototype/ai/ai_seed_deriver.gd")
const ControllerScene = preload("res://scenes/prototype/match_controller.tscn")

const EXPECTED: Dictionary = {
	"easy": {
		"profile_id": "prototype-low-budget-hypothesis",
		"path": "res://resources/prototype/ai/prototype_low_budget_hypothesis.tres",
		"candidate_limit_hypothesis": 8,
		"random_score_span_hypothesis": 12,
	},
	"medium": {
		"profile_id": "prototype-default-hypothesis",
		"path": "res://resources/prototype/ai/prototype_default_hypothesis.tres",
		"candidate_limit_hypothesis": 32,
		"random_score_span_hypothesis": 4,
	},
	"hard": {
		"profile_id": "prototype-high-budget-hypothesis",
		"path": "res://resources/prototype/ai/prototype_high_budget_hypothesis.tres",
		"candidate_limit_hypothesis": 96,
		"random_score_span_hypothesis": 1,
	},
	"expert": {
		"profile_id": "prototype-expert-tactical-hypothesis",
		"path": "res://resources/prototype/ai/prototype_expert_tactical_hypothesis.tres",
		"candidate_limit_hypothesis": 512,
		"random_score_span_hypothesis": 0,
		"strategy_mode_hypothesis": "visible-tactical-one-ply",
	},
}

const DIFFICULTY_IDS: Array[String] = ["easy", "medium", "hard", "expert"]


static func run_suite() -> bool:
	var failures: Array[String] = []
	var controller: Node = ControllerScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(controller)
	var profile_config_digests: Dictionary = {}
	var budget_audit_digests: Dictionary = {}

	for difficulty_id: String in DIFFICULTY_IDS:
		_expect(controller.set_ai_difficulty(difficulty_id), "%s 档可被控制器选择" % difficulty_id, failures)
		var snapshot: Dictionary = controller.get_ai_difficulty_snapshot()
		_expect(snapshot.get("profile_id", "") == EXPECTED[difficulty_id]["profile_id"], "%s 档绑定正确 hypothesis profile" % difficulty_id, failures)
		_expect(snapshot.get("conclusion_status", "") == "hypothesis", "%s 档不冻结为正式结论" % difficulty_id, failures)
		_expect(snapshot.get("candidate_limit_hypothesis", -1) == EXPECTED[difficulty_id]["candidate_limit_hypothesis"], "%s 档候选预算配置正确" % difficulty_id, failures)
		_expect(snapshot.get("random_score_span_hypothesis", -1) == EXPECTED[difficulty_id]["random_score_span_hypothesis"], "%s 档随机分差配置正确" % difficulty_id, failures)
		_expect(
			str(snapshot.get("strategy_mode_hypothesis", "weighted-one-ply"))
			== str(EXPECTED[difficulty_id].get("strategy_mode_hypothesis", "weighted-one-ply")),
			"%s 档策略模式配置正确" % difficulty_id,
			failures
		)

		var first: Dictionary = _run_one_controller_ai_turn(controller, difficulty_id)
		var second: Dictionary = _run_one_controller_ai_turn(controller, difficulty_id)
		_expect(bool(first.get("ok", false)) and bool(second.get("ok", false)), "%s 档均可完成受控 AI 单步" % difficulty_id, failures)
		_expect(first.get("audit_digest", "") == second.get("audit_digest", ""), "%s 档同 seed 完整 audit 一致" % difficulty_id, failures)
		_expect(first.get("view_digest", "") == second.get("view_digest", ""), "%s 档同 seed 最终 PlayerView 一致" % difficulty_id, failures)
		_expect(first.get("difficulty_id", "") == difficulty_id, "%s 档 audit 绑定所选难度" % difficulty_id, failures)
		_expect(first.get("profile_id", "") == EXPECTED[difficulty_id]["profile_id"], "%s 档 audit 含 profile id" % difficulty_id, failures)
		_expect(first.get("profile_config_digest", "") != "", "%s 档 audit 含 profile/config digest" % difficulty_id, failures)
		_expect(first.get("input_projection_digest", "") != "", "%s 档 audit 含 input projection digest" % difficulty_id, failures)
		_expect(int(first.get("ai_seed", -1)) >= 0, "%s 档 audit 含 AI seed" % difficulty_id, failures)
		_expect(int(first.get("evaluated_candidates", 0)) > 0, "%s 档 audit 含实际候选评估数" % difficulty_id, failures)
		profile_config_digests[first.get("profile_config_digest", "")] = true

		var hidden_pair: Dictionary = _hidden_equivalent_decisions(difficulty_id, 661701)
		_expect(bool(hidden_pair.get("views_equal", false)), "%s 档真实隐藏差异保持 PlayerView 等价" % difficulty_id, failures)
		_expect(bool(hidden_pair.get("actions_equal", false)), "%s 档隐藏等价配对选择相同动作" % difficulty_id, failures)
		_expect(bool(hidden_pair.get("audits_equal", false)), "%s 档隐藏等价配对产生相同完整 audit" % difficulty_id, failures)

		var budget_result: Dictionary = _budget_fixture_decision(difficulty_id)
		var expected_limit: int = int(EXPECTED[difficulty_id]["candidate_limit_hypothesis"])
		var expected_evaluated: int = mini(expected_limit, 128)
		_expect(int(budget_result.get("available_candidates", 0)) == 128, "%s 档公开预算夹具有 128 个候选" % difficulty_id, failures)
		_expect(int(budget_result.get("evaluated_candidates", -1)) == expected_evaluated, "%s 档实际评估数精确为 min(%d, 128)" % [difficulty_id, expected_limit], failures)
		_expect(bool(budget_result.get("deterministic_audit", false)), "%s 档公开预算夹具 audit 可确定复现" % difficulty_id, failures)
		budget_audit_digests[budget_result.get("audit_digest", "")] = true

	var unmapped: Dictionary = controller.call(
		"_map_ai_action_or_error",
		controller.get_human_action_previews(),
		"fixture:unmapped-action-id"
	)
	_expect(
		not bool(unmapped.get("ok", true))
		and not bool(unmapped.get("consumed", true))
		and str(unmapped.get("error", "")) == "ai_action_id_unmapped",
		"无法映射的 AI action_id 走 step_ai 共用映射路径并 fail-closed",
		failures
	)
	_expect(profile_config_digests.size() == 4, "四档 profile/config digest 可观察且互异", failures)
	_expect(budget_audit_digests.size() == 4, "四档预算 audit 可观察且互异", failures)
	var tactical_result: Dictionary = _expert_tactical_fixture_decision()
	_expect(tactical_result.get("selected_action_id", "") == "expert-safe", "专家档避开可见车的一步反吃", failures)
	_expect(int(tactical_result.get("visible_attackers", 0)) >= 1, "专家档审计记录危险候选的可见攻击者", failures)
	_expect(int(tactical_result.get("strategic_adjustment", 0)) < 0, "专家档对可见送车候选施加负向战术调整", failures)
	var bombard_heavy: Dictionary = _bombard_heavy_sampling_fixture()
	_expect(bombard_heavy.get("sampling_strategy", "") == "actor-kind-stratified-v1",
		"炮击落点密集时使用按棋子和行动类型分层的候选抽样", failures)
	_expect(int(bombard_heavy.get("move_candidates", 0)) >= 1 \
		and int(bombard_heavy.get("distinct_actors", 0)) >= 4,
		"低预算候选仍覆盖移动动作及多枚棋子，不被炮击落点淹没", failures)
	_expect(not controller.set_ai_difficulty("unsupported"), "未知难度被拒绝", failures)
	controller.queue_free()
	for failure: String in failures:
		push_error("AI_DIFFICULTY_FAIL: %s" % failure)
	return failures.is_empty()


static func _run_one_controller_ai_turn(controller: Node, difficulty_id: String) -> Dictionary:
	controller.initialize(553311, 3, difficulty_id)
	var initial_view: Dictionary = controller.get_human_player_view()
	if initial_view.has("board") or initial_view.has("rng") or initial_view.has("ai_decision_audit"):
		return {"ok": false, "stage": "player_view_boundary"}
	var pass_intent: Dictionary = _pass_intent(controller.get_human_action_previews())
	if pass_intent.is_empty():
		return {"ok": false, "stage": "pass_missing"}
	var human_result: Dictionary = controller.submit_human_intent(pass_intent)
	if not bool(human_result.get("consumed", false)):
		return {"ok": false, "stage": "human_pass", "result": human_result}
	var ai_result: Dictionary = controller.step_ai()
	if not bool(ai_result.get("consumed", false)):
		return {"ok": false, "stage": "ai_step", "result": ai_result}
	var final_view: Dictionary = controller.get_human_player_view()
	var audit: Dictionary = controller.get_last_ai_decision_audit_for_test()
	if audit.is_empty() or final_view.has("ai_decision_audit"):
		return {"ok": false, "stage": "audit_boundary"}
	var context: Dictionary = audit.get("controller_context", {})
	var copied_audit: Dictionary = audit.duplicate(true)
	copied_audit["controller_context"]["difficulty_id"] = "tampered-copy"
	if controller.get_last_ai_decision_audit_for_test()["controller_context"]["difficulty_id"] != difficulty_id:
		return {"ok": false, "stage": "audit_not_deep_copy"}
	return {
		"ok": true,
		"difficulty_id": str(context.get("difficulty_id", "")),
		"profile_id": str(context.get("profile_id", "")),
		"profile_config_digest": str(context.get("profile_config_digest", "")),
		"input_projection_digest": str(context.get("input_projection_digest", "")),
		"ai_seed": int(context.get("ai_seed", -1)),
		"evaluated_candidates": int(audit.get("budget", {}).get("evaluated_candidates", 0)),
		"audit_digest": Canonical.digest(audit),
		"view_digest": Canonical.digest(final_view),
	}


static func _hidden_equivalent_decisions(difficulty_id: String, seed_value: int) -> Dictionary:
	var state_a: Dictionary = MatchState.create(seed_value)
	var state_b: Dictionary = MatchState.clone(state_a)
	MatchState.relocate_piece(state_b, "black-pawn-1", Vector2i(2, 18))
	var view_a: Dictionary = Projector.project(state_a, MatchState.RED)
	var view_b: Dictionary = Projector.project(state_b, MatchState.RED)
	var projection_a: Dictionary = Projector.export_ai_projection_from_view(view_a)
	var projection_b: Dictionary = Projector.export_ai_projection_from_view(view_b)
	var ai_seed: int = AiSeedDeriver.derive(seed_value + 880021, str(projection_a["decision_id"]))
	var decision_a: Dictionary = _decide(projection_a, difficulty_id, ai_seed)
	var decision_b: Dictionary = _decide(projection_b, difficulty_id, ai_seed)
	return {
		"views_equal": Canonical.digest(view_a) == Canonical.digest(view_b)
			and Canonical.digest(projection_a) == Canonical.digest(projection_b),
		"actions_equal": decision_a.get("action", {}) == decision_b.get("action", {}),
		"audits_equal": Canonical.digest(decision_a.get("audit", {}))
			== Canonical.digest(decision_b.get("audit", {})),
	}


static func _budget_fixture_decision(difficulty_id: String) -> Dictionary:
	var projection: Dictionary = _public_budget_fixture(128)
	var first: Dictionary = _decide(projection, difficulty_id, 771991)
	var second: Dictionary = _decide(projection, difficulty_id, 771991)
	var audit: Dictionary = first.get("audit", {})
	return {
		"available_candidates": int(audit.get("budget", {}).get("available_candidates", 0)),
		"evaluated_candidates": int(audit.get("budget", {}).get("evaluated_candidates", 0)),
		"audit_digest": Canonical.digest(audit),
		"deterministic_audit": Canonical.digest(audit)
			== Canonical.digest(second.get("audit", {}))
			and first.get("action", {}) == second.get("action", {}),
	}


static func _expert_tactical_fixture_decision() -> Dictionary:
	var projection: Dictionary = {
		"schema_version": "player-view-ai-v1",
		"decision_id": "fixture-expert-visible-tactic",
		"viewer_side": "red",
		"turn_index": 7,
		"visible_pieces": [
			{"id": "red-rook", "side": "red", "piece_type": "rook", "position": [4, 10], "status_tags": ["owned"]},
			{"id": "red-general", "side": "red", "piece_type": "general", "position": [4, 1], "status_tags": ["owned"]},
			{"id": "black-pawn", "side": "black", "piece_type": "pawn", "position": [4, 12], "status_tags": ["visible"]},
			{"id": "black-rook", "side": "black", "piece_type": "rook", "position": [4, 14], "status_tags": ["visible"]},
		],
		"public_flags": [],
		"public_walls": [
			{"side": "black", "status": "INTACT"},
			{"side": "red", "status": "INTACT"},
		],
		"legal_actions": [
			{
				"id": "expert-greedy-capture", "kind": "move", "actor_id": "red-rook",
				"origin": [4, 10], "target": [4, 12],
				"visible_captures": [{"piece_id": "black-pawn", "piece_type": "pawn"}],
				"reveal_cell_count": 0, "occupies_flag": false, "attacks_wall": false, "path_length": 2,
			},
			{
				"id": "expert-safe", "kind": "move", "actor_id": "red-rook",
				"origin": [4, 10], "target": [3, 10], "visible_captures": [],
				"reveal_cell_count": 0, "occupies_flag": false, "attacks_wall": false, "path_length": 1,
			},
		],
		"public_events": [],
	}
	var decision: Dictionary = _decide(projection, "expert", 991337)
	var dangerous_audit: Dictionary = {}
	for candidate: Dictionary in decision.get("audit", {}).get("candidates", []):
		if str(candidate.get("action_id", "")) == "expert-greedy-capture":
			dangerous_audit = candidate
			break
	var breakdown: Dictionary = dangerous_audit.get("strategic_breakdown", {})
	return {
		"selected_action_id": str(decision.get("action", {}).get("id", "")),
		"visible_attackers": int(breakdown.get("visible_attackers", 0)),
		"strategic_adjustment": int(dangerous_audit.get("strategic_adjustment", 0)),
	}


static func _bombard_heavy_sampling_fixture() -> Dictionary:
	var actions: Array = []
	for cannon_index: int in 2:
		for target_index: int in 84:
			actions.append({
				"id": "bombard:black-cannon-%d:%03d" % [cannon_index + 1, target_index],
				"kind": "bombard", "actor_id": "black-cannon-%d" % (cannon_index + 1),
				"origin": [cannon_index, 23], "target": [target_index % 7 + 1, target_index % 12 + 6],
				"visible_captures": [], "reveal_cell_count": 0, "occupies_flag": false,
				"attacks_wall": false, "path_length": 0,
			})
	for actor_index: int in 12:
		actions.append({
			"id": "move:black-piece-%02d" % actor_index,
			"kind": "move", "actor_id": "black-piece-%02d" % actor_index,
			"origin": [actor_index % 9, 22], "target": [actor_index % 9, 21],
			"visible_captures": [], "reveal_cell_count": 0, "occupies_flag": false,
			"attacks_wall": false, "path_length": 1,
		})
	var projection: Dictionary = {
		"schema_version": "player-view-ai-v1", "decision_id": "fixture-bombard-heavy",
		"viewer_side": "black", "turn_index": 1, "visible_pieces": [],
		"public_flags": [], "public_walls": [], "legal_actions": actions, "public_events": [],
	}
	var profile: Resource = load(str(EXPECTED["easy"]["path"])).duplicate(true)
	var decision: Dictionary = DecisionEngine.new().decide(
		AiPlayerView.new(projection), PublicRules.new(_public_rules()),
		Memory.new(_empty_memory()), 551903, profile
	)
	var audit: Dictionary = decision.get("audit", {})
	var actor_ids: Dictionary = {}
	var move_candidates: int = 0
	for candidate: Dictionary in audit.get("candidates", []):
		var action_id: String = str(candidate.get("action_id", ""))
		if action_id.begins_with("move:"):
			move_candidates += 1
		var parts: PackedStringArray = action_id.split(":")
		if parts.size() >= 2:
			actor_ids[parts[1]] = true
	return {
		"sampling_strategy": str(audit.get("candidate_sampling", {}).get("strategy", "")),
		"move_candidates": move_candidates,
		"distinct_actors": actor_ids.size(),
	}


static func _decide(projection: Dictionary, difficulty_id: String, ai_seed: int) -> Dictionary:
	var profile: Resource = load(str(EXPECTED[difficulty_id]["path"])).duplicate(true)
	return DecisionEngine.new().decide(
		AiPlayerView.new(projection),
		PublicRules.new(_public_rules()),
		Memory.new(_empty_memory()),
		ai_seed,
		profile
	)


static func _public_budget_fixture(candidate_count: int) -> Dictionary:
	var actions: Array = []
	for index: int in candidate_count:
		actions.append({
			"id": "public-fixture-%03d" % index,
			"kind": "pass",
			"actor_id": "",
			"origin": [0, 0],
			"target": [0, 0],
			"visible_captures": [],
			"reveal_cell_count": index % 5,
			"occupies_flag": index % 7 == 0,
			"attacks_wall": index % 11 == 0,
			"path_length": 0,
		})
	return {
		"schema_version": "player-view-ai-v1",
		"decision_id": "fixture-turn-0-red",
		"viewer_side": "red",
		"turn_index": 0,
		"visible_pieces": [],
		"public_flags": [],
		"public_walls": [],
		"legal_actions": actions,
		"public_events": [],
	}


static func _pass_intent(previews: Array) -> Dictionary:
	for preview: Dictionary in previews:
		if preview["action_type"] == "pass":
			return {
				"piece_id": str(preview["piece_id"]),
				"action_type": str(preview["action_type"]),
				"target_cell": preview["target_cell"].duplicate(),
				"skill_type": str(preview["skill_type"]),
			}
	return {}


static func _public_rules() -> Dictionary:
	return {
		"schema_version": "public-ai-rules-v1",
		"board_width": MatchState.BOARD_WIDTH,
		"board_height": MatchState.BOARD_HEIGHT,
		"piece_values": {
			"pawn": 10, "rook": 50, "horse": 30, "elephant": 25,
			"advisor": 25, "cannon": 45, "general": 10000,
		},
		"action_kind_bias": {"move": 0, "bombard": 0, "pass": -100},
	}


static func _empty_memory() -> Dictionary:
	return {
		"schema_version": "ai-memory-v1",
		"recent_action_ids": [],
		"action_visit_counts": {},
		"last_visible_piece_turns": {},
	}


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
