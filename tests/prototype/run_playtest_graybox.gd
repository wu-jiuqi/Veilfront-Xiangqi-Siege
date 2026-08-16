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

	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("PLAYTEST_GRAYBOX_SMOKE_PASSED cells=216 round_limit=50 human_move=true ai_step=true pass=true bombard=true")
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
