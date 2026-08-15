extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")


static func run_suite() -> bool:
	var state: Dictionary = MatchState.create(471001)
	assert(state["schema_version"] == "full-state-v1")
	assert(state["rules_revision"] == "owner-freeze-revision-2")
	assert(state["active_side"] == MatchState.RED, "红方必须固定先手")
	assert(state["pieces"].size() == 32, "冻结阵型必须包含 32 枚棋")
	_assert_piece(state, "red-general-1", Vector2i(5, 1))
	_assert_piece(state, "black-general-1", Vector2i(5, 24))
	_assert_piece(state, "red-cannon-1", Vector2i(2, 3))
	_assert_piece(state, "black-cannon-2", Vector2i(8, 22))
	_assert_piece(state, "red-pawn-5", Vector2i(9, 4))
	_assert_piece(state, "black-pawn-1", Vector2i(1, 21))
	assert(state["flags"].size() == 3)
	var flag_keys: Dictionary = {}
	var band_min: int = 99
	var band_max: int = -1
	for flag: Dictionary in state["flags"]:
		var cell := Canonical.coordinate(flag["position"])
		assert(cell.x >= 1 and cell.x <= 9)
		flag_keys[Canonical.cell_key(cell)] = true
		band_min = mini(band_min, cell.y)
		band_max = maxi(band_max, cell.y)
	assert(flag_keys.size() == 3, "旗帜格必须互不重复")
	assert((band_min == 11 and band_max <= 13) or (band_min >= 12 and band_max <= 14))
	assert(not Canonical.json(state).to_lower().contains("cooldown"), "无冷却裁决后 FullState 不得出现冷却字段")
	assert(not Canonical.json(MatchState.summary(state)).to_lower().contains("cooldown"), "状态摘要不得出现冷却字段")
	return true


static func _assert_piece(state: Dictionary, piece_id: String, expected: Vector2i) -> void:
	assert(state["pieces"].has(piece_id), "缺少冻结阵型棋子 %s" % piece_id)
	assert(Canonical.coordinate(state["pieces"][piece_id]["position"]) == expected)
