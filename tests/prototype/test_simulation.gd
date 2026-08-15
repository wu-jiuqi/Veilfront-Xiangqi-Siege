extends RefCounted

const MatchSimulator = preload("res://scripts/prototype/simulation/match_simulator.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")


static func run_suite() -> bool:
	var failures: Array[String] = []
	var first: Dictionary = MatchSimulator.run_match(501, {
		"full_round_limit_hypothesis": 12,
		"verify_replay": true,
	})
	_expect(first.get("ok", false), "完整种子对局合法终止", failures)
	_expect(first.get("simulation_mode", "") == "rules_stress_full_state_policy", "整局模拟明确标记为 FullState 规则压力模式", failures)
	var band_start: int = int(first.get("initial_flag_band_start", 0))
	var band_positions_valid: bool = band_start in [11, 12]
	for position: Array in first.get("initial_flag_positions", []):
		band_positions_valid = band_positions_valid and int(position[1]) >= band_start \
			and int(position[1]) <= band_start + 2
	_expect(band_positions_valid, "旗带统计来自准确随机记录且三旗位于对应三行", failures)
	_expect(first.get("terminal", false), "完整种子对局到达终局", failures)
	_expect(first.get("replay_verified", false), "完整对局逐行动重放摘要一致", failures)
	_expect(int(first.get("action_count", 0)) <= 24, "可配置12完整轮假设约束终止", failures)
	var repeated: Dictionary = MatchSimulator.run_match(501, {
		"full_round_limit_hypothesis": 12,
		"verify_replay": false,
	})
	_expect(repeated.get("ok", false), "相同种子重复对局合法终止", failures)
	_expect(first.get("state_digest", "") == repeated.get("state_digest", "") \
		and first.get("event_log_digest", "") == repeated.get("event_log_digest", ""), "同种子与策略重放摘要确定", failures)
	var contested_limit: Dictionary = MatchState.create(502, {"full_round_limit_hypothesis": 1})
	contested_limit["flags"][0]["owner"] = MatchState.RED
	contested_limit["flags"][0]["contested"] = true
	contested_limit["flags"][1]["owner"] = MatchState.RED
	contested_limit["flags"][2]["owner"] = MatchState.BLACK
	contested_limit["active_side"] = MatchState.BLACK
	var limit_result: Dictionary = RuleEngine.submit_action(contested_limit, {
		"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": "",
	})
	_expect(limit_result.get("consumed", false) and contested_limit["terminal"] \
		and contested_limit["winner"] == MatchState.RED \
		and contested_limit["win_reason"] == "round_limit_flags",
		"轮上限统计包含仍属原owner的争夺中旗", failures)
	for failure: String in failures:
		push_error("SIMULATION_FAIL: %s" % failure)
	return failures.is_empty()


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
