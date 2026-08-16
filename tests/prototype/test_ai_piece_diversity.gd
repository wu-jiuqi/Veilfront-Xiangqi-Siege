extends RefCounted

const ControllerScene = preload("res://scenes/prototype/match_controller.tscn")
const REQUIRED_DEVELOPED_TYPES: Array[String] = ["pawn", "horse", "rook"]
const REGRESSION_SEED: int = 471001
const OBSERVED_AI_TURNS: int = 15


static func run_suite() -> bool:
	var failures: Array[String] = []
	var controller: Node = ControllerScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(controller)
	controller.initialize(REGRESSION_SEED, 50, "expert")
	var selected_types: Dictionary = {}
	var cannon_turns: int = 0
	for turn: int in OBSERVED_AI_TURNS:
		var pass_intent: Dictionary = _pass_intent(controller.get_human_action_previews())
		if pass_intent.is_empty() \
		or not bool(controller.submit_human_intent(pass_intent).get("consumed", false)):
			failures.append("第 %d 轮玩家公开跳过失败" % (turn + 1))
			break
		var ai_result: Dictionary = controller.step_ai()
		if not bool(ai_result.get("consumed", false)):
			failures.append("第 %d 轮专家 AI 行动失败" % (turn + 1))
			break
		var audit: Dictionary = controller.get_last_ai_decision_audit_for_test()
		var actor_id: String = _actor_id(str(audit.get("final_action", {}).get("action_id", "")))
		var piece_type: String = _piece_type(actor_id)
		if not piece_type.is_empty():
			selected_types[piece_type] = int(selected_types.get(piece_type, 0)) + 1
			if piece_type == "cannon":
				cannon_turns += 1
	for required_type: String in REQUIRED_DEVELOPED_TYPES:
		if int(selected_types.get(required_type, 0)) <= 0:
			failures.append("固定种子前 %d 次 AI 行动未发展 %s" % [
				OBSERVED_AI_TURNS, required_type,
			])
	if cannon_turns >= OBSERVED_AI_TURNS:
		failures.append("固定种子前 %d 次 AI 行动仍被炮完全垄断" % OBSERVED_AI_TURNS)
	controller.queue_free()
	for failure: String in failures:
		push_error("AI_PIECE_DIVERSITY_FAIL: %s" % failure)
	return failures.is_empty()


static func _pass_intent(previews: Array) -> Dictionary:
	for preview: Dictionary in previews:
		if str(preview.get("action_type", "")) == "pass":
			return {
				"piece_id": str(preview.get("piece_id", "")),
				"action_type": "pass",
				"target_cell": preview.get("target_cell", []).duplicate(),
				"skill_type": str(preview.get("skill_type", "")),
			}
	return {}


static func _actor_id(action_id: String) -> String:
	var parts: PackedStringArray = action_id.split(":")
	return parts[1] if parts.size() > 1 else ""


static func _piece_type(actor_id: String) -> String:
	var parts: PackedStringArray = actor_id.split("-")
	return parts[1] if parts.size() > 2 else ""
