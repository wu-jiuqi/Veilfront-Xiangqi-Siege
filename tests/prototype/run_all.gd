extends SceneTree

const MAIN_SCENE_PATH: String = "res://scenes/prototype/gate1_logic_lab.tscn"
const EXPECTED_CELL_COUNT: int = 216
const EXPECTED_SEED: int = 471001

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
	_check(scene.has_node("SafeMargin/Page/Workspace/BoardShell"), "预置 BoardShell 存在")
	_check(scene.has_node("SafeMargin/Page/Workspace/StatusShell"), "预置 StatusShell 存在")
	_check(scene.has_node("SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/SeedGroup/SeedValue"), "预置种子 Label 存在")

	if scene.has_method("get_board_cell_count"):
		_check(scene.get_board_cell_count() == EXPECTED_CELL_COUNT, "运行时棋盘数据恰有 216 格")
	if scene.has_method("get_initial_seed"):
		_check(scene.get_initial_seed() == EXPECTED_SEED, "Phase 1 默认种子保持可读")

	var seed_label := scene.get_node_or_null("SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/SeedGroup/SeedValue") as Label
	_check(seed_label != null and seed_label.text == str(EXPECTED_SEED), "预置 Label 回显公开种子")

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
		print("PHASE1_SCAFFOLD_CHECKS_PASSED count=9 rules=not_implemented")
		quit(0)
		return
	print("PHASE1_SCAFFOLD_CHECKS_FAILED count=%d" % failures.size())
	quit(1)
