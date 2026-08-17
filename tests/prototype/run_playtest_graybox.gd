extends SceneTree

const MAIN_SCENE := preload("res://scenes/prototype/gate1_logic_lab.tscn")
const Canonical := preload("res://scripts/prototype/core/canonical.gd")
const Projector := preload("res://scripts/prototype/view/player_view_projector.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	_check(scene.get_board_cell_count() == 216, "灰盒预置 24×9 共 216 个交互格")
	var surface := scene.get_node_or_null("SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/BoardScroll/BoardSurface") as Control
	_check(surface != null, "BoardSurface 预置交点棋盘节点存在")
	_check(surface != null and surface.has_method("logical_to_local") \
		and surface.has_method("local_to_logical"), "交点棋盘统一提供逻辑坐标与本地坐标互转")
	_check(surface != null and surface.has_method("layout_snapshot"), "交点棋盘暴露可验证的响应式绘制规格")
	if surface != null and surface.has_method("layout_snapshot"):
		var layout: Dictionary = surface.layout_snapshot()
		var spacing: Array = layout.get("point_spacing", [])
		_check(spacing.size() == 2 and is_equal_approx(float(spacing[0]), float(spacing[1])),
			"棋盘横纵交点间距相等，格子保持正方形")
		_check(str(layout.get("fog_style", "")) == "cell_mask", "迷雾使用整格黑色蒙版而非交点黑点")
		_check(not bool(layout.get("region_separator_lines", true)), "区域之间仅用颜色块区分")
		_check(layout.get("region_labels", []).size() == 5, "双侧大本营、缓冲区与中央战区均有背景大字")
		var overlay_style: Dictionary = layout.get("vision_overlay_style", {})
		_check(str(overlay_style.get("rook", "")) == "blue_grid_path_line",
			"车的特殊高亮沿移动路径绘制蓝色棋盘线")
		_check(str(overlay_style.get("elephant", "")) == "yellow_field_grid_outline" \
			and not bool(overlay_style.get("elephant_reveal_outline", true)),
			"相仅沿田字格边界绘制黄色棋盘线，不描绘扩展侦察并集")
	_check(scene.has_method("_submission_accepted") \
		and bool(scene._submission_accepted({"ok": true, "request_id": "queued"}, true)),
		"LAN 已登记请求在等待房主裁决时不误报行动未提交")
	var confirm_button := scene.get_node(
		"SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/ActionConfirm/ConfirmMargin/ConfirmColumn/ConfirmButtons/ConfirmButton"
	) as Button
	confirm_button.disabled = true
	scene._clear_selection(false)
	_check(not confirm_button.disabled, "LAN 新 PlayerView 清除选择后恢复下一回合确认按钮")
	var initial_view: Dictionary = scene.get_player_view_snapshot()
	if surface != null:
		var red_bottom_y: float = surface.logical_to_local(Vector2i(5, 1)).y
		var red_far_y: float = surface.logical_to_local(Vector2i(5, 24)).y
		_check(red_bottom_y > red_far_y, "红方视角以红方大本营置底")
		var black_view: Dictionary = initial_view.duplicate(true) if not initial_view.is_empty() else {}
		black_view["viewer_side"] = "black"
		surface.set_board_data(black_view, [], "", [], "move", false)
		var black_bottom_y: float = surface.logical_to_local(Vector2i(5, 24)).y
		var black_far_y: float = surface.logical_to_local(Vector2i(5, 1)).y
		_check(black_bottom_y > black_far_y, "黑方视角镜像后以黑方大本营置底")
		surface.set_board_data(initial_view, scene.get_action_preview_snapshot(), "", [], "move", true)
	_check(
		scene.get_node_or_null("SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/CasualtyGrid") != null,
		"状态栏预置红黑双方阵亡棋子记录格"
	)
	var initial_digest: String = Canonical.digest(initial_view)
	_check(int(initial_view.get("full_round_limit_hypothesis", -1)) == 50, "默认完整回合上限为 50")
	_check(str(initial_view.get("round_limit_status", "")) == "hypothesis_cli_overridable", "回合上限保持可覆盖假设")
	_check(not initial_view.has("board") and not initial_view.has("rng"), "UI PlayerView 不含 FullState board/rng")
	_check(not scene.get_node("MatchController").has_method("get_full_state"), "控制器不暴露 FullState getter")
	_check(not scene.get_action_preview_snapshot().is_empty(), "人类公开候选已生成")
	var resurrect_button := scene.get_node(
		"SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/ActionMode/ResurrectButton"
	) as Button
	_check(not resurrect_button.disabled, "人类行动阶段献祭复活入口可点击并提供不可用原因")
	resurrect_button.pressed.emit()
	var message_value := scene.get_node(
		"SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/MessageValue"
	) as Label
	_check(message_value.text.contains("没有可复活棋子"), "无合格阵亡棋子时明确说明献祭不可用原因")
	var resurrection_view: Dictionary = initial_view.duplicate(true)
	for piece: Dictionary in resurrection_view["pieces"]:
		if str(piece.get("id", "")) == "red-rook-1":
			piece["alive"] = false
			piece["position"] = []
			break
	resurrection_view["casualties"].append({
		"piece_id": "red-rook-1", "piece_type": "rook", "side": "red",
	})
	scene.player_view = resurrection_view
	scene.action_previews = Projector.generate_action_intents(resurrection_view)
	scene._clear_selection(false)
	scene._refresh_all()
	resurrect_button.pressed.emit()
	_check(str(scene.action_mode) == "resurrect" and str(scene.selected_piece_id).is_empty(),
		"有复活候选时点击入口进入选择献祭士模式")
	scene.select_cell_for_test([4, 1])
	_check(str(scene.selected_piece_id) == "red-advisor-1" \
		and str(scene.pending_preview.get("action_type", "")) == "resurrect",
		"选择在场士后直接登记献祭复活确认动作")
	scene.restart_match_for_test()
	await process_frame
	initial_view = scene.get_player_view_snapshot()
	scene.select_cell_for_test([1, 1])
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	scene._unhandled_input(cancel_event)
	var turn_selection := scene.get_node(
		"SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/TurnAndSelection"
	) as Label
	_check(turn_selection.text.contains("选择：无"), "Esc可取消当前选择")
	if surface != null:
		var marker_event := InputEventMouseButton.new()
		marker_event.button_index = MOUSE_BUTTON_RIGHT
		marker_event.pressed = true
		marker_event.position = surface.logical_to_local(Vector2i(3, 9))
		scene.select_cell_for_test([1, 1])
		surface._gui_input(marker_event)
		_check(turn_selection.text.contains("选择：无") \
			and not surface.annotation_snapshot().has("3,9"), "选中棋子时右键优先取消选择且不打开标注")
		surface._gui_input(marker_event)
		surface.get_node("AnnotationMenu").id_pressed.emit(1)
		_check(surface.annotation_snapshot().get("3,9", "") == "circle", "未选中棋子时右键菜单可添加圆形本地标注")
		scene._unhandled_input(cancel_event)

	var page := scene.get_node("SafeMargin/Page") as Control
	var original_root_size: Vector2i = root.size
	root.size = Vector2i(1024, 640)
	await process_frame
	await process_frame
	var safe_margin := scene.get_node("SafeMargin") as Control
	_check(page.size.x <= safe_margin.size.x and page.size.y <= safe_margin.size.y,
		"1024×640窗口缩放后页面不溢出安全区域（页面 %.0f×%.0f / 安全区 %.0f×%.0f）" % [
			page.size.x, page.size.y, safe_margin.size.x, safe_margin.size.y,
		])
	var compact_cell_size: float = 0.0
	if surface != null and surface.has_method("layout_snapshot"):
		compact_cell_size = float(surface.layout_snapshot().get("cell_size", 0.0))
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame
	var wide_cell_size: float = compact_cell_size
	if surface != null and surface.has_method("layout_snapshot"):
		wide_cell_size = float(surface.layout_snapshot().get("cell_size", 0.0))
	_check(wide_cell_size >= compact_cell_size, "宽窗口不会缩小棋盘交点尺寸")
	root.size = original_root_size
	await process_frame

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

	scene.restart_match_for_test()
	await process_frame
	scene.choose_pass_for_test()
	var auto_pass: Dictionary = scene.confirm_action_for_test()
	_check(bool(auto_pass.get("consumed", false)), "自动 AI 验证前的人类行动已消费")
	var ai_timer := scene.get_node("AiTurnTimer") as Timer
	await ai_timer.timeout
	await process_frame
	_check(int(scene.get_player_view_snapshot()["action_index"]) == 2, "玩家行动后 AI 无需点击即可自动完成行动")

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
		print("PLAYTEST_GRAYBOX_SMOKE_PASSED cells=216 round_limit=50 traditional_pieces=true regions=3 right_click_cancel=true auto_ai=true casualties=true")
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
