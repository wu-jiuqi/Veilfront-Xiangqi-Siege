extends SceneTree

const MAIN_SCENE := preload("res://scenes/prototype/gate1_logic_lab.tscn")
const Canonical := preload("res://scripts/prototype/core/canonical.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	_check(scene.get_board_cell_count() == 216, "灰盒预置 24×9 共 216 个交互格")
	var grid := scene.get_node_or_null("SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/BoardScroll/BoardGrid") as GridContainer
	_check(grid != null and grid.get_child_count() == 216, "BoardGrid 固定节点数为 216")
	var initial_view: Dictionary = scene.get_player_view_snapshot()
	var initial_digest: String = Canonical.digest(initial_view)
	_check(int(initial_view.get("full_round_limit_hypothesis", -1)) == 50, "默认完整回合上限为 50")
	_check(str(initial_view.get("round_limit_status", "")) == "hypothesis_cli_overridable", "回合上限保持可覆盖假设")
	_check(not initial_view.has("board") and not initial_view.has("rng"), "UI PlayerView 不含 FullState board/rng")
	_check(not scene.get_node("MatchController").has_method("get_full_state"), "控制器不暴露 FullState getter")
	_check(not scene.get_action_preview_snapshot().is_empty(), "人类公开候选已生成")

	var move_preview: Dictionary = _first_preview(scene.get_action_preview_snapshot(), "move")
	_check(not move_preview.is_empty(), "存在可提交的人类移动候选")
	if not move_preview.is_empty():
		var piece: Dictionary = _piece_by_id(initial_view, str(move_preview["piece_id"]))
		scene.select_cell_for_test(piece["position"])
		scene.select_cell_for_test(move_preview["target_cell"])
		var moved: Dictionary = scene.confirm_action_for_test()
		_check(bool(moved.get("consumed", false)), "选择、目标、确认可消费一次人类移动")
		await process_frame
		_check(int(scene.get_player_view_snapshot()["action_index"]) == 1, "人类行动后 action_index 为 1")
		var ai_result: Dictionary = scene.step_ai_for_test()
		_check(bool(ai_result.get("consumed", false)), "基线 AI 可单步消费行动")
		await process_frame
		_check(int(scene.get_player_view_snapshot()["action_index"]) == 2, "AI 行动后完成一个完整轮")

	scene.restart_match_for_test()
	await process_frame
	var restarted_view: Dictionary = scene.get_player_view_snapshot()
	_check(Canonical.digest(restarted_view) == initial_digest, "同种子同配置重开恢复相同公开初态")
	_check(restarted_view.get("player_events", []).is_empty(), "重开清空上一局玩家事件")

	scene.choose_pass_for_test()
	var passed: Dictionary = scene.confirm_action_for_test()
	_check(bool(passed.get("consumed", false)), "主动跳过经过二次确认并消费行动")
	await process_frame

	scene.restart_match_for_test()
	await process_frame
	var bombard_preview: Dictionary = _first_preview(scene.get_action_preview_snapshot(), "bombard")
	_check(not bombard_preview.is_empty(), "开局存在公开可用炮击候选")
	if not bombard_preview.is_empty():
		var bombard_piece: Dictionary = _piece_by_id(scene.get_player_view_snapshot(), str(bombard_preview["piece_id"]))
		scene.select_cell_for_test(bombard_piece["position"])
		var bombard_button := scene.get_node("SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/ActionMode/BombardButton") as Button
		bombard_button.pressed.emit()
		scene.select_cell_for_test(bombard_preview["target_cell"])
		var bombarded: Dictionary = scene.confirm_action_for_test()
		_check(bool(bombarded.get("consumed", false)), "区域炮击不预演命中格并可确认消费")
		await process_frame

	var difficulty_select := scene.get_node("SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/DifficultyGroup/DifficultySelect") as OptionButton
	_check(difficulty_select.item_count == 4, "灰盒预置简单/中等/困难/专家四档选择")
	var expected_profiles: Dictionary = {
		"easy": "prototype-low-budget-hypothesis",
		"medium": "prototype-default-hypothesis",
		"hard": "prototype-high-budget-hypothesis",
		"expert": "prototype-expert-tactical-hypothesis",
	}
	var expected_candidate_limits: Dictionary = {
		"easy": 8,
		"medium": 32,
		"hard": 96,
		"expert": 512,
	}
	var match_controller := scene.get_node("MatchController")
	for difficulty_id: String in ["easy", "medium", "hard", "expert"]:
		scene.set_ai_difficulty_for_test(difficulty_id)
		await process_frame
		var difficulty_snapshot: Dictionary = scene.get_ai_difficulty_snapshot()
		_check(
			str(difficulty_snapshot.get("profile_id", "")) == expected_profiles[difficulty_id],
			"灰盒 %s 档绑定正确 PlayerView AI profile" % difficulty_id
		)
		scene.choose_pass_for_test()
		var difficulty_pass: Dictionary = scene.confirm_action_for_test()
		var difficulty_ai: Dictionary = scene.step_ai_for_test()
		_check(
			bool(difficulty_pass.get("consumed", false)) and bool(difficulty_ai.get("consumed", false)),
			"灰盒 %s 档可完成一次 AI 单步" % difficulty_id
		)
		await process_frame
		var decision_audit: Dictionary = match_controller.get_last_ai_decision_audit_for_test()
		var controller_context: Dictionary = decision_audit.get("controller_context", {})
		var budget_audit: Dictionary = decision_audit.get("budget", {})
		_check(
			not decision_audit.is_empty()
			and str(controller_context.get("profile_id", "")) == expected_profiles[difficulty_id]
			and not str(controller_context.get("profile_config_digest", "")).is_empty()
			and not str(controller_context.get("input_projection_digest", "")).is_empty()
			and int(controller_context.get("ai_seed", -1)) >= 0
			and bool(controller_context.get("action_id_mapped", false)),
			"灰盒 %s 档受控测试接口保留完整 AI 决策上下文" % difficulty_id
		)
		_check(
			int(budget_audit.get("candidate_limit_hypothesis", -1)) == expected_candidate_limits[difficulty_id]
			and int(budget_audit.get("evaluated_candidates", -1)) > 0
			and int(budget_audit.get("evaluated_candidates", -1)) <= expected_candidate_limits[difficulty_id],
			"灰盒 %s 档审计记录实际候选评估数与预算" % difficulty_id
		)
		var internal_audit_digest: String = Canonical.digest(decision_audit)
		decision_audit["controller_context"]["profile_config_digest"] = "mutated-test-copy"
		_check(
			Canonical.digest(match_controller.get_last_ai_decision_audit_for_test()) == internal_audit_digest,
			"灰盒 %s 档 AI 审计测试接口返回深复制" % difficulty_id
		)
		var public_view_after_ai: Dictionary = scene.get_player_view_snapshot()
		_check(
			not public_view_after_ai.has("ai_decision_audit")
			and not public_view_after_ai.has("controller_context")
			and not public_view_after_ai.has("profile_config_digest"),
			"灰盒 %s 档 AI 审计未进入人类 PlayerView" % difficulty_id
		)
		var event_log := scene.get_node("SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/EventLog") as RichTextLabel
		_check(
			not event_log.text.contains("profile_config_digest")
			and not event_log.text.contains("input_projection_digest")
			and not event_log.text.contains(internal_audit_digest),
			"灰盒 %s 档 AI 审计未进入玩家事件日志" % difficulty_id
		)

	var ui_source: String = FileAccess.get_file_as_string("res://scripts/prototype/gate1_logic_lab.gd")
	_check(
		not ui_source.contains("get_last_ai_decision_audit_for_test")
		and not ui_source.contains("controller_context"),
		"灰盒 UI 脚本没有接入受控 AI 审计接口"
	)

	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("PLAYTEST_GRAYBOX_SMOKE_PASSED cells=216 round_limit=50 human_move=true ai_step=true pass=true bombard=true ai_difficulties=4 ai_audit_test_only=true")
		quit(0)
		return
	print("PLAYTEST_GRAYBOX_SMOKE_FAILED count=%d" % failures.size())
	quit(1)


func _first_preview(previews: Array, action_type: String) -> Dictionary:
	for preview: Dictionary in previews:
		if str(preview["action_type"]) == action_type and str(preview["classification"]) != "KNOWN_ILLEGAL":
			return preview
	return {}


func _piece_by_id(player_view: Dictionary, piece_id: String) -> Dictionary:
	for piece: Dictionary in player_view["pieces"]:
		if str(piece["id"]) == piece_id:
			return piece
	return {}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
		return
	failures.append(description)
	push_error("FAIL: %s" % description)
