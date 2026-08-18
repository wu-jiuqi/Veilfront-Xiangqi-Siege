extends RefCounted

const MatchState = preload("res://scripts/prototype/core/match_state.gd")

const PLAYABLE_MAX_Y: int = 16
const ROUND_LIMIT: int = 50
const RED_WALL_Y: int = 4

const LEVEL_SPECS: Dictionary = {
	1: {
		"title": "第一关：孤象",
		"enemy_piece_type": "elephant",
		"enemy_piece_ids": ["black-elephant-1"],
		"enemy_positions": [[5, PLAYABLE_MAX_Y]],
	},
	2: {
		"title": "第二关：双象",
		"enemy_piece_type": "elephant",
		"enemy_piece_ids": ["black-elephant-1", "black-elephant-2"],
		"enemy_positions": [[3, PLAYABLE_MAX_Y], [7, PLAYABLE_MAX_Y]],
	},
	3: {
		"title": "第三关：双马",
		"enemy_piece_type": "horse",
		"enemy_piece_ids": ["black-horse-1", "black-horse-2"],
		"enemy_positions": [[3, PLAYABLE_MAX_Y], [7, PLAYABLE_MAX_Y]],
	},
}


static func level_from_selector(selector_id: String) -> int:
	return clampi(["easy", "medium", "hard"].find(selector_id) + 1, 1, 3)


static func title(level_id: int) -> String:
	return str(_spec(level_id)["title"])


static func enemy_count(level_id: int) -> int:
	return _spec(level_id)["enemy_piece_ids"].size()


static func configure(state: Dictionary, level_id: int) -> void:
	var spec: Dictionary = _spec(level_id)
	state["rules_revision"] = "level-test-owner-scope-2026-08-18"
	state["implementation_revision"] = "level-test-v2"
	state["configuration"]["full_round_limit_hypothesis"] = ROUND_LIMIT
	state["configuration"]["round_limit_status"] = "fixed_level_objective"
	state["configuration"]["level_id"] = level_id
	state["configuration"]["level_title"] = str(spec["title"])
	state["flags"] = []
	state["flag_discoveries"] = {MatchState.RED: [], MatchState.BLACK: []}

	_place_red_army(state)
	_configure_enemy_force(state, spec)


static func is_inside_playable_area(cell: Array) -> bool:
	return cell.size() == 2 \
		and int(cell[0]) >= 1 and int(cell[0]) <= MatchState.BOARD_WIDTH \
		and int(cell[1]) >= 1 and int(cell[1]) <= PLAYABLE_MAX_Y


static func _place_red_army(state: Dictionary) -> void:
	for pawn_index: int in range(1, 6):
		var pawn_id: String = "red-pawn-%d" % pawn_index
		var pawn_x: int = 1 + (pawn_index - 1) * 2
		MatchState.relocate_piece(state, pawn_id, Vector2i(pawn_x, RED_WALL_Y))


static func _configure_enemy_force(state: Dictionary, spec: Dictionary) -> void:
	var keep_ids: Array = spec["enemy_piece_ids"]
	var piece_ids: Array = state["pieces"].keys()
	for piece_id_value: Variant in piece_ids:
		var piece_id: String = str(piece_id_value)
		var piece: Dictionary = state["pieces"][piece_id]
		if str(piece["side"]) != MatchState.BLACK:
			continue
		MatchState.remove_piece_from_board(state, piece_id)
		if piece_id not in keep_ids:
			state["pieces"].erase(piece_id)

	for index: int in keep_ids.size():
		var enemy_id: String = str(keep_ids[index])
		var position: Array = spec["enemy_positions"][index]
		var enemy: Dictionary = state["pieces"][enemy_id]
		enemy["hidden"] = false
		enemy["revealed_to"] = []
		enemy["temporary_effects"] = []
		MatchState.relocate_piece(
			state,
			enemy_id,
			Vector2i(int(position[0]), int(position[1]))
		)


static func _spec(level_id: int) -> Dictionary:
	assert(LEVEL_SPECS.has(level_id), "关卡编号必须在 1 到 3 之间")
	return LEVEL_SPECS[level_id]
