extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/level_test/level_match_controller.tscn")
const MAIN_SCENE := preload("res://scenes/level_test/level_test_lab.tscn")
const MatchState := preload("res://scripts/prototype/core/match_state.gd")
const SeededRandom := preload("res://scripts/prototype/core/seeded_random.gd")
const AiPublicRules := preload("res://scripts/prototype/ai/ai_public_rules.gd")
const SafeRandomAi := preload("res://scripts/level_test/safe_random_ai.gd")
const SAFETY_PROFILE := preload("res://resources/level_test/level_safe_random_profile.tres")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_safe_random_priority()
	for selector_id: String in ["easy", "medium", "hard"]:
		await _test_level(selector_id)
	await _test_objective_outcomes()
	await _test_main_scene()
	if failures.is_empty():
		print("LEVEL_TEST_CHECKS_PASSED levels=3 playable_cells=144 round_limit=50 safe_random=true")
		quit(0)
		return
	print("LEVEL_TEST_CHECKS_FAILED count=%d" % failures.size())
	quit(1)


func _test_safe_random_priority() -> void:
	var projection: Dictionary = {
		"viewer_side": "black",
		"visible_pieces": [
			{"id": "black-elephant-1", "side": "black", "piece_type": "elephant", "position": [4, 15]},
			{"id": "red-rook-1", "side": "red", "piece_type": "rook", "position": [4, 10]},
		],
		"public_walls": [
			{"side": "red", "status": "INTACT"},
			{"side": "black", "status": "BREACHED"},
		],
		"legal_actions": [
			_action("unsafe", [4, 15], [4, 12]),
			_action("safe", [4, 15], [6, 13]),
		],
	}
	var public_rules := AiPublicRules.new({
		"schema_version": "public-ai-rules-v1",
		"board_width": 9,
		"board_height": 24,
		"piece_values": {
			"pawn": 10, "rook": 50, "horse": 30, "elephant": 25,
			"advisor": 25, "cannon": 45, "general": 10000,
		},
		"action_kind_bias": {"move": 0, "pass": 0},
	})
	for seed_value: int in range(1, 21):
		var decision: Dictionary = SafeRandomAi.choose(
			projection,
			SeededRandom.create_state(seed_value),
			public_rules,
			SAFETY_PROFILE
		)
		_check(str(decision.get("action", {}).get("id", "")) == "safe",
			"存在安全落点时种子%d排除明确受攻击落点" % seed_value)


func _test_level(selector_id: String) -> void:
	var controller := CONTROLLER_SCENE.instantiate()
	root.add_child(controller)
	controller.initialize(471001, 50, selector_id)
	await process_frame
	var snapshot: Dictionary = controller.get_scenario_snapshot_for_test()
	var level_id: int = ["easy", "medium", "hard"].find(selector_id) + 1
	var expected_count: int = 1 if level_id == 1 else 2
	var expected_type: String = "horse" if level_id == 3 else "elephant"
	_check(int(snapshot.get("level_id", 0)) == level_id, "选择器映射到第%d关" % level_id)
	_check(int(snapshot.get("round_limit", 0)) == 50, "第%d关固定50完整回合" % level_id)
	_check(snapshot.get("flags", []).is_empty(), "第%d关不生成夺旗目标" % level_id)
	_check(snapshot.get("red_pieces", []).size() == 16, "第%d关保留我方全部16枚棋子" % level_id)
	for piece: Dictionary in snapshot.get("red_pieces", []):
		_check(int(piece["position"][1]) >= 1 and int(piece["position"][1]) <= 3,
			"第%d关我方%s位于大本营" % [level_id, str(piece["id"])])
	_check(snapshot.get("black_pieces", []).size() == expected_count,
		"第%d关敌军数量正确" % level_id)
	for piece: Dictionary in snapshot.get("black_pieces", []):
		_check(str(piece["piece_type"]) == expected_type,
			"第%d关敌军类型为%s" % [level_id, expected_type])
		_check(int(piece["position"][1]) == 16, "第%d关敌军部署在战区最远边界Y=16" % level_id)
	var previews_inside_bounds: bool = true
	for preview: Dictionary in controller.get_human_action_previews():
		var target: Array = preview.get("target_cell", [])
		if not target.is_empty() and int(target[1]) > 16:
			previews_inside_bounds = false
	_check(previews_inside_bounds, "第%d关人类候选不越过战区边界" % level_id)
	var initial_view: Dictionary = controller.get_human_player_view()
	var visible_enemy_count: int = 0
	for piece: Dictionary in initial_view.get("pieces", []):
		if str(piece.get("side", "")) == "black":
			visible_enemy_count += 1
	_check(visible_enemy_count == 0, "第%d关敌军初始受迷雾遮蔽" % level_id)
	var pass_result: Dictionary = controller.submit_human_intent({
		"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": "",
	})
	var ai_result: Dictionary = controller.step_ai()
	_check(bool(pass_result.get("consumed", false)) and bool(ai_result.get("consumed", false)),
		"第%d关可完成玩家与敌方各一次行动" % level_id)
	var audit: Dictionary = controller.get_last_ai_decision_audit_for_test()
	_check(bool(audit.get("controller_context", {}).get("uses_player_view_only", false)),
		"第%d关敌方AI审计确认只使用PlayerView" % level_id)
	for piece: Dictionary in controller.get_scenario_snapshot_for_test().get("black_pieces", []):
		_check(int(piece["position"][1]) <= 16, "第%d关敌方行动不越过战区边界" % level_id)
	controller.queue_free()
	await process_frame


func _test_objective_outcomes() -> void:
	var controller := CONTROLLER_SCENE.instantiate()
	root.add_child(controller)
	controller.initialize(471001, 50, "easy")
	var enemy_ids: Array[String] = []
	for piece: Dictionary in controller.get_scenario_snapshot_for_test()["black_pieces"]:
		enemy_ids.append(str(piece["id"]))
	for enemy_id: String in enemy_ids:
		var position: Array = controller._full_state["pieces"][enemy_id]["position"].duplicate()
		MatchState.register_casualty(
			controller._full_state,
			enemy_id,
			"test_capture",
			Vector2i(int(position[0]), int(position[1]))
		)
	controller._apply_objective_terminal()
	var victory: Dictionary = controller.get_scenario_snapshot_for_test()
	_check(bool(victory["terminal"]) and str(victory["winner"]) == "red" \
		and str(victory["win_reason"]) == "all_enemies_destroyed",
		"消灭全部敌棋立即判定关卡胜利")
	controller.initialize(471001, 50, "easy")
	controller._full_state["terminal"] = true
	controller._full_state["winner"] = "draw"
	controller._full_state["win_reason"] = "round_limit_draw"
	controller._apply_objective_terminal()
	var timeout: Dictionary = controller.get_scenario_snapshot_for_test()
	_check(str(timeout["winner"]) == "black" and str(timeout["win_reason"]) == "objective_timeout",
		"达到50完整回合仍有敌军时判定关卡失败")
	controller.queue_free()
	await process_frame


func _test_main_scene() -> void:
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	_check(scene.get_board_cell_count() == 144, "主场景只提供9×16共144个可交互点")
	var surface := scene.get_node(
		"SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/BoardScroll/BoardSurface"
	)
	var layout: Dictionary = surface.layout_snapshot()
	_check(int(surface.visible_board_height) == 16, "棋盘预置视图裁切在Y=16")
	_check(layout.get("region_labels", []).size() == 3, "界面只显示我方大本营、缓冲区与战区")
	var selector := scene.get_node(
		"SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/DifficultyGroup/DifficultySelect"
	) as OptionButton
	_check(selector.item_count == 3, "主场景预置三个关卡选项")
	selector.select(2)
	selector.item_selected.emit(2)
	await process_frame
	_check(int(scene.get_node("MatchController").get_level_status().get("level_id", 0)) == 3,
		"界面选择第三关后会按当前种子重新初始化双马关卡")
	scene.queue_free()
	await process_frame


func _action(action_id: String, origin: Array, target: Array) -> Dictionary:
	return {
		"id": action_id,
		"kind": "move",
		"actor_id": "black-elephant-1",
		"origin": origin,
		"target": target,
		"visible_captures": [],
		"reveal_cell_count": 0,
		"attacks_wall": false,
		"path_length": 2,
	}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
		return
	failures.append(description)
	push_error("FAIL: %s" % description)
