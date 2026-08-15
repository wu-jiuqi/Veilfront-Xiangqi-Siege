extends RefCounted

const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const ReplayRunner = preload("res://scripts/prototype/replay/replay_runner.gd")


static func run_suite() -> bool:
	var failures: Array[String] = []
	var initial: Dictionary = MatchState.create(601)
	var reserve_piece_id: String = "red-pawn-1"
	MatchState.remove_piece_from_board(initial, reserve_piece_id)
	initial["pieces"][reserve_piece_id]["in_reserve"] = true
	initial["pieces"][reserve_piece_id]["reserve_queue_index"] = 0
	initial["reserve_queues"][MatchState.RED] = [reserve_piece_id]
	var state: Dictionary = MatchState.clone(initial)
	var prepared_result: Dictionary = RuleEngine.prepare_action(state)
	_expect(prepared_result.get("ok", false), "行动准备成功", failures)
	var preparation: Dictionary = prepared_result.get("preparation", {})
	_expect(preparation.get("deployments", []).size() == 1 \
		and preparation["deployments"][0]["piece_id"] == reserve_piece_id, "后备部署发生在行动生成前", failures)
	var legal_actions: Array = RuleEngine.list_legal_actions(state)
	var selected: Dictionary = {}
	for intent: Dictionary in legal_actions:
		if intent["piece_id"] == reserve_piece_id:
			selected = intent
			break
	_expect(not selected.is_empty(), "本行动刚部署棋子可被选择", failures)
	if selected.is_empty():
		selected = {"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""}
	var wrong_token_result: Dictionary = RuleEngine.submit_action(state, selected, {
		"preparation_token": "prepared-stale-token",
	})
	_expect(not wrong_token_result.get("consumed", false), "错误准备 token 不可消费行动", failures)
	var result: Dictionary = RuleEngine.submit_action(state, selected, {
		"preparation_token": preparation.get("token", ""),
	})
	_expect(result.get("ok", false), "同一准备 token 可提交行动", failures)
	_expect(result.get("event", {}).get("deployments_before_action", []) == preparation.get("deployments", []), "部署写入同一行动事件", failures)
	_expect(result.get("event", {}).get("random_samples", []).size() >= 1, "部署随机样本写入行动事件", failures)
	_expect(not state.has("prepared_action"), "消费后准备 token 清除", failures)
	var recording: Dictionary = ReplayRunner.capture_from_state(initial, [selected])
	_expect(recording["action_events"][0]["deployments_before_action"].size() == 1, "状态回放记录后备部署", failures)
	var replayed: Dictionary = ReplayRunner.replay(recording)
	_expect(replayed.get("ok", false), "含后备部署的状态事件与摘要可重放", failures)
	for failure: String in failures:
		push_error("PREPARED_ACTION_FAIL: %s" % failure)
	return failures.is_empty()


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
