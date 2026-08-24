extends SceneTree

const MatchState = preload("res://scripts/game/domain/match_state.gd")
const ScenarioObjectiveResolver = preload("res://scripts/game/domain/scenario_objective_resolver.gd")
const ChallengeCatalog = preload("res://scripts/game/challenge/challenge_catalog.gd")
const ChallengeSession = preload("res://scripts/game/challenge/challenge_session.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cleared_state := MatchState.create(9001, {"full_round_limit_hypothesis": 51})
	cleared_state["flags"] = []
	_disable_side(cleared_state, "black")
	ScenarioObjectiveResolver.resolve(cleared_state, _objective())
	_expect(bool(cleared_state.get("terminal", false)), "clearing the black force did not end the challenge")
	_expect(str(cleared_state.get("winner", "")) == "red", "clearing the black force must award red victory")
	_expect(str(cleared_state.get("win_reason", "")) == "challenge_enemies_cleared", "enemy-clear reason is incorrect")

	var timeout_state := MatchState.create(9002, {"full_round_limit_hypothesis": 51})
	timeout_state["flags"] = []
	timeout_state["full_round_index"] = 50
	ScenarioObjectiveResolver.resolve(timeout_state, _objective())
	_expect(str(timeout_state.get("winner", "")) == "black", "surviving 50 rounds must award black victory")
	_expect(str(timeout_state.get("win_reason", "")) == "challenge_round_limit", "challenge timeout reason is incorrect")

	var general_state := MatchState.create(9003, {"full_round_limit_hypothesis": 51})
	general_state["flags"] = []
	_disable_piece(general_state, "red-general-1")
	ScenarioObjectiveResolver.resolve(general_state, _objective())
	_expect(str(general_state.get("winner", "")) == "black", "red general loss must award black victory")
	_expect(str(general_state.get("win_reason", "")) == "general_destroyed", "general loss reason is incorrect")

	var integration_definition: Resource = ChallengeCatalog.definition("C1").duplicate(true)
	var integration_pieces: Array[Dictionary] = integration_definition.initial_pieces.duplicate(true)
	integration_pieces[integration_pieces.size() - 1]["position"] = [1, 5]
	integration_definition.initial_pieces = integration_pieces
	var integration_session: RefCounted = ChallengeSession.create(integration_definition)
	var initial_payload: Dictionary = integration_session.current_payload()
	var capture_preview := _find_preview(
		initial_payload.get("action_previews", []),
		"red-pawn-1",
		[1, 5],
	)
	var terminal_result: Dictionary = integration_session.submit_preview(capture_preview)
	var terminal_view: Dictionary = terminal_result.get("player_view", {})
	_expect(bool(terminal_result.get("consumed", false)), "integration capture was not consumed")
	_expect(str(terminal_view.get("winner", "")) == "red", "application did not apply enemy-clear objective")
	_expect(str(terminal_view.get("win_reason", "")) == "challenge_enemies_cleared", "application returned the wrong challenge terminal reason")
	_expect(terminal_view.get("flags", []).is_empty(), "integration challenge unexpectedly restored flags")

	if _failures.is_empty():
		print("CHALLENGE_OBJECTIVE_CONTRACT_PASS outcomes=3 flags=disabled")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("CHALLENGE_OBJECTIVE_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _objective() -> Dictionary:
	return {
		"objective_type": "eliminate_side",
		"player_side": "red",
		"target_side": "black",
		"round_limit": 50,
	}


func _disable_side(state: Dictionary, side: String) -> void:
	for piece: Dictionary in state["pieces"].values():
		if str(piece.get("side", "")) == side:
			_disable_piece(state, str(piece.get("id", "")))


func _disable_piece(state: Dictionary, piece_id: String) -> void:
	var piece: Dictionary = state["pieces"][piece_id]
	var position: Array = piece.get("position", []).duplicate()
	if position.size() == 2:
		state["board"].erase("%d,%d" % [int(position[0]), int(position[1])])
	piece["position"] = []
	piece["alive"] = false


func _find_preview(previews: Array, piece_id: String, target: Array) -> Dictionary:
	for preview: Dictionary in previews:
		if str(preview.get("piece_id", "")) == piece_id \
		and preview.get("target_cell", []) == target \
		and str(preview.get("classification", "")) in ["KNOWN_LEGAL", "TENTATIVE"]:
			return preview
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
