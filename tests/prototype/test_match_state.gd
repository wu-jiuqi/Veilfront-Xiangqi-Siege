extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")


static func run_suite() -> bool:
	var failures: Array[String] = []
	var state: Dictionary = MatchState.create(471001)
	_expect(
		state["configuration"]["full_round_limit_hypothesis"] == 50,
		"默认完整回合上限临时调整为 50",
		failures
	)
	_expect(
		state["configuration"]["round_limit_status"] == "hypothesis_cli_overridable",
		"回合上限保持 CLI 可覆盖假设状态",
		failures
	)
	var overridden_state: Dictionary = MatchState.create(471001, {
		"full_round_limit_hypothesis": 7,
	})
	_expect(
		overridden_state["configuration"]["full_round_limit_hypothesis"] == 7,
		"显式回合上限继续覆盖默认假设",
		failures
	)
	_expect(state["schema_version"] == "full-state-v1", "FullState schema版本", failures)
	_expect(state["rules_revision"] == "owner-confirm-2026-08-17-gate1-rule-v4", "规则冻结水位", failures)
	_expect(state["implementation_revision"] == "prototype-core-revision-7", "实现修订水位", failures)
	_expect(state["active_side"] == MatchState.RED, "红方必须固定先手", failures)
	_expect(state["pieces"].size() == 32, "冻结阵型必须包含 32 枚棋", failures)
	_expect_piece(state, "red-general-1", Vector2i(5, 1), failures)
	_expect_piece(state, "black-general-1", Vector2i(5, 24), failures)
	_expect_piece(state, "red-cannon-1", Vector2i(2, 3), failures)
	_expect_piece(state, "black-cannon-2", Vector2i(8, 22), failures)
	_expect_piece(state, "red-pawn-5", Vector2i(9, 4), failures)
	_expect_piece(state, "black-pawn-1", Vector2i(1, 21), failures)
	_expect(state["flags"].size() == 3, "固定生成三面旗", failures)
	var flag_keys: Dictionary = {}
	for flag: Dictionary in state["flags"]:
		var cell := Canonical.coordinate(flag["position"])
		_expect(cell.x >= 1 and cell.x <= 9, "旗帜横坐标在棋盘内", failures)
		_expect(cell.y >= 9 and cell.y <= 16, "旗帜纵坐标覆盖完整战区", failures)
		flag_keys[Canonical.cell_key(cell)] = true
	_expect(flag_keys.size() == 3, "旗帜格必须互不重复", failures)
	_expect(not Canonical.json(state).to_lower().contains("cooldown"), "无冷却裁决后 FullState 不得出现冷却字段", failures)
	_expect(not Canonical.json(MatchState.summary(state)).to_lower().contains("cooldown"), "状态摘要不得出现冷却字段", failures)
	for failure: String in failures:
		push_error("MATCH_STATE_FAIL: %s" % failure)
	return failures.is_empty()


static func _expect_piece(state: Dictionary, piece_id: String, expected: Vector2i, failures: Array[String]) -> void:
	if not state["pieces"].has(piece_id):
		failures.append("缺少冻结阵型棋子 %s" % piece_id)
		return
	_expect(Canonical.coordinate(state["pieces"][piece_id]["position"]) == expected, "%s 开局坐标" % piece_id, failures)


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
