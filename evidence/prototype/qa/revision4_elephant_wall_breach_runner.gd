extends SceneTree

const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const MoveRules = preload("res://scripts/prototype/core/move_rules.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")


func _init() -> void:
	var state: Dictionary = MatchState.create(541001)
	MatchState.relocate_piece(state, "red-elephant-1", Vector2i(4, 17))
	MatchState.relocate_piece(state, "red-rook-1", Vector2i(5, 17))
	MatchState.relocate_piece(state, "red-horse-1", Vector2i(6, 17))
	state["vision_sources"][MatchState.RED]["elephant_reveal_zones"]["red-elephant-1"] = \
		MoveRules.reveal_cells_for_elephant_move(Vector2i(2, 15), Vector2i(4, 17))
	var result: Dictionary = RuleEngine.submit_action(state, {
		"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": "",
	})
	var passed: bool = result.get("consumed", false) \
		and state["walls"][MatchState.BLACK]["status"] == "BREACHED" \
		and state["vision_sources"][MatchState.RED]["elephant_reveal_zones"].is_empty()
	if passed:
		print("REVISION4_ELEPHANT_WALL_BREACH_CLEAR_PASS")
		quit(0)
		return
	push_error("REVISION4_ELEPHANT_WALL_BREACH_CLEAR_FAIL")
	quit(1)
