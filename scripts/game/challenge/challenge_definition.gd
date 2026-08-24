class_name ChallengeDefinition
extends TutorialScenarioDefinition

@export_range(1, 24, 1) var playable_max_y: int = 16
@export_range(1, 200, 1) var round_limit: int = 50
@export var opponent_policy_seed: int = 73001


func is_valid_definition() -> bool:
	if scenario_id.is_empty() or fixture_key.is_empty() \
	or level_id not in ["C1", "C2", "C3"] or bound_seat != "red":
		return false
	if seed_value <= 0 or opponent_policy_seed <= 0 \
	or playable_max_y < 1 or playable_max_y > 24 or round_limit <= 0:
		return false
	if not initial_flags.is_empty() or not initial_casualties.is_empty() \
	or not initial_visible_cells.is_empty() or not allow_any_public_preview \
	or skip_allowed or not restart_allowed:
		return false
	var occupied: Dictionary = {}
	var piece_ids: Dictionary = {}
	var red_count := 0
	var black_count := 0
	var has_red_general := false
	for piece: Dictionary in initial_pieces:
		var piece_id := str(piece.get("id", ""))
		var side := str(piece.get("side", ""))
		var piece_type := str(piece.get("piece_type", ""))
		var position: Array = piece.get("position", [])
		if piece_id.is_empty() or piece_ids.has(piece_id) or side not in ["red", "black"] \
		or piece_type not in ["rook", "horse", "elephant", "advisor", "general", "cannon", "pawn"] \
		or not _is_challenge_coordinate(position):
			return false
		var key := "%d,%d" % [int(position[0]), int(position[1])]
		if occupied.has(key):
			return false
		piece_ids[piece_id] = true
		occupied[key] = true
		if side == "red":
			red_count += 1
			has_red_general = has_red_general or piece_type == "general"
		else:
			black_count += 1
	return red_count == 16 and black_count > 0 and has_red_general \
		and _has_approved_red_army()


func objective_configuration() -> Dictionary:
	return {
		"objective_type": "eliminate_side",
		"player_side": "red",
		"target_side": "black",
		"round_limit": round_limit,
	}


func _is_challenge_coordinate(value: Variant) -> bool:
	return value is Array and value.size() == 2 \
		and typeof(value[0]) == TYPE_INT and typeof(value[1]) == TYPE_INT \
		and int(value[0]) >= 1 and int(value[0]) <= 9 \
		and int(value[1]) >= 1 and int(value[1]) <= playable_max_y


func _has_approved_red_army() -> bool:
	var expected: Dictionary = {
		"red-rook-1": ["rook", [1, 1]],
		"red-horse-1": ["horse", [2, 1]],
		"red-elephant-1": ["elephant", [3, 1]],
		"red-advisor-1": ["advisor", [4, 1]],
		"red-general-1": ["general", [5, 1]],
		"red-advisor-2": ["advisor", [6, 1]],
		"red-elephant-2": ["elephant", [7, 1]],
		"red-horse-2": ["horse", [8, 1]],
		"red-rook-2": ["rook", [9, 1]],
		"red-cannon-1": ["cannon", [2, 3]],
		"red-cannon-2": ["cannon", [8, 3]],
		"red-pawn-1": ["pawn", [1, 4]],
		"red-pawn-2": ["pawn", [3, 4]],
		"red-pawn-3": ["pawn", [5, 4]],
		"red-pawn-4": ["pawn", [7, 4]],
		"red-pawn-5": ["pawn", [9, 4]],
	}
	for piece: Dictionary in initial_pieces:
		if str(piece.get("side", "")) != "red":
			continue
		var approved: Array = expected.get(str(piece.get("id", "")), [])
		if approved.size() != 2 \
		or str(piece.get("piece_type", "")) != str(approved[0]) \
		or piece.get("position", []) != approved[1]:
			return false
	return true
