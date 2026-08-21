extends SceneTree

const RuleEngine = preload("res://scripts/game/domain/rule_engine.gd")
const FormalMatchApplication = preload("res://scripts/game/application/formal_match_application.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_rule_engine_timeout_move()
	_check_application_stale_guard()
	if _failures.is_empty():
		print("TURN_TIMEOUT_AUTHORITY_CONTRACT_PASS random_move=seeded stale_guard=true")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TURN_TIMEOUT_AUTHORITY_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_rule_engine_timeout_move() -> void:
	var first_state := RuleEngine.create_match(20260821)
	var second_state := RuleEngine.create_match(20260821)
	RuleEngine.prepare_action(first_state)
	RuleEngine.prepare_action(second_state)
	var legal_moves: Array = RuleEngine.list_legal_actions(first_state).filter(
		func(intent: Dictionary) -> bool: return str(intent.get("action_type", "")) == "move"
	)
	var first := RuleEngine.submit_timeout_random_move(first_state)
	var second := RuleEngine.submit_timeout_random_move(second_state)
	_expect(bool(first.get("consumed", false)), "超时随机行动没有消耗当前行动")
	var first_event: Dictionary = first.get("event", {})
	var second_event: Dictionary = second.get("event", {})
	var selected_intent: Dictionary = first_event.get("intent", {})
	if legal_moves.is_empty():
		_expect(selected_intent.get("action_type", "") == "timeout", "无合法普通移动时没有回退为超时跳过")
	else:
		_expect(selected_intent.get("action_type", "") == "move", "有合法普通移动时超时没有随机走一步")
		_expect(legal_moves.has(selected_intent), "超时系统选择了不在合法普通移动集合中的行动")
		_expect(selected_intent == second_event.get("intent", {}), "相同种子没有得到可复现的超时随机行动")
	var has_timeout_sample := false
	for sample_value: Variant in first_event.get("random_samples", []):
		if sample_value is Dictionary and str(sample_value.get("reason", "")) == "timeout_random_legal_move":
			has_timeout_sample = true
	_expect(legal_moves.is_empty() or has_timeout_sample, "超时随机选择没有留下可审计随机样本")


func _check_application_stale_guard() -> void:
	var application: RefCounted = FormalMatchApplication.create_trusted(20260821, "red")
	var initial_view: Dictionary = application.current_player_view()
	var action_index := int(initial_view.get("action_index", -1))
	var stale: Dictionary = application.submit_trusted_timeout(action_index + 1)
	_expect(not bool(stale.get("consumed", true)), "过期行动序号仍触发了超时随机行动")
	_expect(int(application.current_player_view().get("action_index", -1)) == action_index, "过期超时请求改变了权威状态")
	var accepted: Dictionary = application.submit_trusted_timeout(action_index)
	_expect(bool(accepted.get("consumed", false)), "当前行动序号的超时请求没有被权威层接受")
	_expect(int(application.current_player_view().get("action_index", -1)) == action_index + 1, "超时随机行动没有推进权威行动序号")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
