class_name ScenarioObjectiveResolver
extends RefCounted


static func resolve(state: Dictionary, objective: Dictionary) -> Dictionary:
	if bool(state.get("terminal", false)):
		return {"changed": false, "winner": state.get("winner", ""), "win_reason": state.get("win_reason", "")}
	if str(objective.get("objective_type", "")) != "eliminate_side":
		return {"changed": false, "winner": "", "win_reason": ""}
	var player_side := str(objective.get("player_side", "red"))
	var target_side := str(objective.get("target_side", "black"))
	var round_limit := int(objective.get("round_limit", 0))
	if player_side not in ["red", "black"] or target_side not in ["red", "black"] \
	or player_side == target_side or round_limit <= 0:
		return {"changed": false, "winner": "", "win_reason": ""}

	if not _has_living_general(state, player_side):
		return _set_terminal(state, target_side, "general_destroyed")
	if _living_piece_count(state, target_side) == 0:
		return _set_terminal(state, player_side, "challenge_enemies_cleared")
	if int(state.get("full_round_index", 0)) >= round_limit:
		return _set_terminal(state, target_side, "challenge_round_limit")
	return {"changed": false, "winner": "", "win_reason": ""}


static func _has_living_general(state: Dictionary, side: String) -> bool:
	for piece: Dictionary in state.get("pieces", {}).values():
		if str(piece.get("side", "")) == side \
		and str(piece.get("piece_type", "")) == "general" \
		and bool(piece.get("alive", false)) and not bool(piece.get("in_reserve", false)):
			return true
	return false


static func _living_piece_count(state: Dictionary, side: String) -> int:
	var count := 0
	for piece: Dictionary in state.get("pieces", {}).values():
		if str(piece.get("side", "")) == side \
		and bool(piece.get("alive", false)) and not bool(piece.get("in_reserve", false)):
			count += 1
	return count


static func _set_terminal(state: Dictionary, winner: String, reason: String) -> Dictionary:
	state["terminal"] = true
	state["winner"] = winner
	state["win_reason"] = reason
	return {"changed": true, "winner": winner, "win_reason": reason}
