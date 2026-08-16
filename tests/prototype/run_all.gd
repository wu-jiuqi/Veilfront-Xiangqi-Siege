extends SceneTree

const MAIN_SCENE_PATH: String = "res://scenes/prototype/gate1_logic_lab.tscn"
const EXPECTED_CELL_COUNT: int = 216
const EXPECTED_SEED: int = 471001
const MatchStateTests = preload("res://tests/prototype/test_match_state.gd")
const PlayerViewTests = preload("res://tests/prototype/test_player_view.gd")
const RulesCoreTests = preload("res://tests/prototype/test_rules_core.gd")
const ReplayTests = preload("res://tests/prototype/test_replay.gd")
const MoveRulesTests = preload("res://tests/prototype/test_move_rules.gd")
const Revision3RulesTests = preload("res://tests/prototype/test_revision3_rules.gd")
const ElephantRevealTests = preload("res://tests/prototype/test_elephant_reveal.gd")
const SimulationTests = preload("res://tests/prototype/test_simulation.gd")
const PreparedActionTests = preload("res://tests/prototype/test_prepared_action.gd")
const AiFairnessTests = preload("res://tests/prototype/test_ai_fairness.gd")
const AiDifficultyProfileTests = preload("res://tests/prototype/test_ai_difficulty_profiles.gd")
const AiPieceDiversityTests = preload("res://tests/prototype/test_ai_piece_diversity.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_phase1_checks")


func _run_phase1_checks() -> void:
	var packed_scene := load(MAIN_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "主场景可作为 PackedScene 加载")
	if packed_scene == null:
		_finish()
		return

	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	_check(scene.has_method("get_board_cell_count"), "场景暴露 Phase 1 棋盘数据计数接口")
	_check(scene.has_method("get_initial_seed"), "场景暴露 Phase 1 种子读取接口")
	_check(scene.has_method("get_player_view_snapshot"), "UI 仅暴露 PlayerView 快照接口")
	_check(scene.has_node("MatchController"), "预置非 UI MatchController 节点存在")
	var controller: Node = scene.get_node_or_null("MatchController")
	_check(controller != null and controller.has_method("get_human_player_view") \
		and not controller.has_method("get_player_view"), "UI-facing controller仅暴露无side的人类视图入口")
	_check(scene.has_node("SafeMargin/Page/Workspace/BoardShell"), "预置 BoardShell 存在")
	_check(scene.has_node("SafeMargin/Page/Workspace/StatusShell"), "预置 StatusShell 存在")
	_check(scene.has_node("SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/SeedGroup/SeedValue"), "预置种子 Label 存在")

	if scene.has_method("get_board_cell_count"):
		_check(scene.get_board_cell_count() == EXPECTED_CELL_COUNT, "运行时棋盘数据恰有 216 格")
	if scene.has_method("get_initial_seed"):
		_check(scene.get_initial_seed() == EXPECTED_SEED, "Phase 1 默认种子保持可读")
	if scene.has_method("get_player_view_snapshot"):
		var ui_view: Dictionary = scene.get_player_view_snapshot()
		_check(not ui_view.has("board") and not ui_view.has("rng"), "Control 层取得对象不含 FullState board/rng")
	var ui_source: String = FileAccess.get_file_as_string("res://scripts/prototype/gate1_logic_lab.gd")
	_check(not ui_source.contains("MatchState") and not ui_source.contains("prototype_state") \
		and not ui_source.contains("FullState"), "Control 脚本无 MatchState/FullState 旁路")

	var seed_label := scene.get_node_or_null("SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/SeedGroup/SeedValue") as Label
	_check(seed_label != null and seed_label.text == str(EXPECTED_SEED), "预置 Label 回显公开种子")

	_check(MatchStateTests.run_suite(), "FullState 冻结开局、红先、确定性旗帜与无冷却字段")
	_check(PlayerViewTests.run_suite(), "FullState→PlayerView 隐藏等价投影、查询、错误与 AI DTO")
	_check(RulesCoreTests.run_suite(), "旗帜生命周期、无冷却炮击资格、同步双将平局、士替死、后备队列与修墙时序")
	_check(ReplayTests.run_suite(), "同 seed + 行动意图的事件日志与最终状态摘要重放一致")
	_check(MoveRulesTests.run_suite(), "传统棋子几何、特殊资格、炮架与完整墙线约束")
	_check(Revision3RulesTests.run_suite(), "车逐目标、隐藏马/炮架、显形策略生命周期与玩家事件过滤")
	_check(ElephantRevealTests.run_suite(), "冻结田字九格、相象多源并集、刷新与全离场清源")
	_check(SimulationTests.run_suite(), "可配置轮上限整局终止、确定性与完整对局重放")
	_check(PreparedActionTests.run_suite(), "后备部署准备 token、当回合可选、事件记录与状态回放")
	var ai_result: Dictionary = AiFairnessTests.run_suite()
	if ai_result.ok:
		print("PASS: 真实 PlayerView AI 隐藏等价、独立种子与公开审计一致")
	else:
		for ai_failure: String in ai_result.failures:
			var description: String = "AI 公平性：%s" % ai_failure
			failures.append(description)
			push_error("FAIL: %s" % description)
	_check(AiDifficultyProfileTests.run_suite(), "简单/中等/困难/专家四档 PlayerView AI 配置差异、战术审计与固定种子复现")
	await process_frame
	_check(AiPieceDiversityTests.run_suite(), "专家 AI 固定种子开局会发展兵、马、车且不再由炮垄断")
	await process_frame

	scene.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=12 full_gate1=false")
		quit(0)
		return
	print("PHASE1_SCAFFOLD_CHECKS_FAILED count=%d" % failures.size())
	quit(1)
