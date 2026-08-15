extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")


static func run_suite() -> bool:
	if not _test_flag_lifecycle():
		return false
	if not _test_flag_third_opportunity_resolves_death_first():
		return false
	if not _test_bombardment_origin_and_no_cooldown():
		return false
	if not _test_simultaneous_generals_draw():
		return false
	if not _test_bombardment_rescue_uses_impact_order_and_excludes_hit_advisor():
		return false
	if not _test_reserve_queue_and_free_deployment():
		return false
	if not _test_wall_repair_counts_actions_after_trigger():
		return false
	return true


static func _test_flag_lifecycle() -> bool:
	var state: Dictionary = RuleEngine.create_match(1101)
	state["flags"] = [
		_flag("flag-1", Vector2i(5, 12)),
		_flag("flag-2", Vector2i(3, 12)),
		_flag("flag-3", Vector2i(7, 12)),
	]
	MatchState.relocate_piece(state, "red-rook-1", Vector2i(5, 11))
	assert(_assert_consumed(RuleEngine.submit_action(state, _move("red-rook-1", Vector2i(5, 12)))))
	assert(state["flags"][0]["capture_progress"] == 0)
	assert(_assert_consumed(RuleEngine.submit_action(state, _pass())))
	assert(state["flags"][0]["capture_progress"] == 1)
	assert(_assert_consumed(RuleEngine.submit_action(state, _pass())))
	assert(_assert_consumed(RuleEngine.submit_action(state, _pass())))
	assert(state["flags"][0]["capture_progress"] == 2)
	assert(_assert_consumed(RuleEngine.submit_action(state, _pass())))
	assert(_assert_consumed(RuleEngine.submit_action(state, _pass())))
	assert(state["flags"][0]["owner"] == MatchState.RED)
	assert(state["flags"][0]["capture_progress"] == 0)

	assert(_assert_consumed(RuleEngine.submit_action(state, _move("red-rook-1", Vector2i(5, 13)))))
	assert(state["flags"][0]["owner"] == MatchState.RED, "完成占领后棋子离开不丢所有权")
	MatchState.relocate_piece(state, "black-rook-1", Vector2i(5, 11))
	assert(_assert_consumed(RuleEngine.submit_action(state, _move("black-rook-1", Vector2i(5, 12)))))
	assert(state["flags"][0]["contested"])
	assert(_assert_consumed(RuleEngine.submit_action(state, _pass())))
	assert(state["flags"][0]["capture_progress"] == 1)
	assert(_assert_consumed(RuleEngine.submit_action(state, _move("black-rook-1", Vector2i(5, 11)))))
	assert(state["flags"][0]["owner"] == MatchState.RED)
	assert(not state["flags"][0]["contested"] and state["flags"][0]["capture_progress"] == 0)
	return true


static func _test_bombardment_origin_and_no_cooldown() -> bool:
	var state: Dictionary = RuleEngine.create_match(2202)
	var cannon_id: String = "red-cannon-1"
	assert(RuleEngine.can_bombard(state, cannon_id))
	MatchState.relocate_piece(state, cannon_id, Vector2i(2, 6))
	assert(not RuleEngine.can_bombard(state, cannon_id), "炮离开己方大本营不得区域轰炸")
	MatchState.relocate_piece(state, cannon_id, Vector2i(2, 3))
	state["walls"][MatchState.BLACK]["status"] = "REPAIRING"
	assert(not RuleEngine.can_bombard(state, cannon_id), "敌墙修复中不等于 INTACT")
	state["walls"][MatchState.BLACK]["status"] = "INTACT"
	assert(RuleEngine.can_bombard(state, cannon_id))
	var first: Dictionary = RuleEngine.submit_action(state, {
		"piece_id": cannon_id,
		"action_type": "bombard",
		"target_cell": [5, 12],
		"skill_type": "area_bombardment",
	})
	assert(_assert_consumed(first))
	assert(first["event"]["outcome"]["bombardment_result"]["impact_cells"].size() == 3)
	assert(state["pieces"][cannon_id]["bombard_ammo"] == 1)
	assert(_assert_consumed(RuleEngine.submit_action(state, _pass())))
	assert(RuleEngine.can_bombard(state, cannon_id), "无冷却裁决：下一次红方行动仍仅由位置、墙和弹药决定")
	assert(not Canonical.json(state).to_lower().contains("cooldown"))
	return true


static func _test_flag_third_opportunity_resolves_death_first() -> bool:
	var state: Dictionary = RuleEngine.create_match(1155)
	state["flags"] = [_flag("flag-1", Vector2i(5, 12)), _flag("flag-2", Vector2i(3, 12)), _flag("flag-3", Vector2i(7, 12))]
	MatchState.relocate_piece(state, "red-pawn-1", Vector2i(5, 12))
	MatchState.relocate_piece(state, "black-rook-1", Vector2i(5, 13))
	state["flags"][0]["occupier_piece_id"] = "red-pawn-1"
	state["flags"][0]["capturing_side"] = MatchState.RED
	state["flags"][0]["capture_progress"] = 2
	state["active_side"] = MatchState.BLACK
	assert(_assert_consumed(RuleEngine.submit_action(state, _move("black-rook-1", Vector2i(5, 12)))))
	assert(state["flags"][0]["owner"] == MatchState.NEUTRAL)
	assert(state["flags"][0]["occupier_piece_id"] == "black-rook-1")
	assert(state["flags"][0]["capturing_side"] == MatchState.BLACK)
	assert(state["flags"][0]["capture_progress"] == 0)
	return true


static func _test_simultaneous_generals_draw() -> bool:
	var state: Dictionary = RuleEngine.create_match(3303)
	MatchState.relocate_piece(state, "red-general-1", Vector2i(4, 12))
	MatchState.relocate_piece(state, "black-general-1", Vector2i(5, 12))
	var result: Dictionary = RuleEngine.resolve_bombardment_window(
		state,
		"red-cannon-1",
		Vector2i(5, 12),
		[Vector2i(4, 12), Vector2i(5, 12), Vector2i(6, 12)]
	)
	assert(result["schema_version"] == "bombardment-result-v1")
	assert(result["impact_order"] == [1, 2, 3])
	assert(result["general_resolution"]["red_destroyed"] and result["general_resolution"]["black_destroyed"])
	assert(state["terminal"] and state["winner"] == "draw")
	assert(state["win_reason"] == "simultaneous_generals_destroyed")
	return true


static func _test_bombardment_rescue_uses_impact_order_and_excludes_hit_advisor() -> bool:
	var state: Dictionary = RuleEngine.create_match(3355)
	MatchState.relocate_piece(state, "red-pawn-1", Vector2i(4, 12))
	MatchState.relocate_piece(state, "red-advisor-1", Vector2i(5, 12))
	var result: Dictionary = RuleEngine.resolve_bombardment_window(
		state,
		"black-cannon-1",
		Vector2i(5, 12),
		[Vector2i(4, 12), Vector2i(5, 12), Vector2i(6, 12)]
	)
	assert(result["rescue_records"].size() == 1)
	assert(result["rescue_records"][0]["impact_number"] == 1)
	assert(result["rescue_records"][0]["sacrificed_advisor_id"] == "red-advisor-2")
	assert(state["pieces"]["red-pawn-1"]["alive"])
	assert(not state["pieces"]["red-advisor-1"]["alive"], "本窗被命中的士不得救援")
	assert(not state["pieces"]["red-advisor-2"]["alive"])
	return true


static func _test_reserve_queue_and_free_deployment() -> bool:
	var state: Dictionary = RuleEngine.create_match(4404)
	MatchState.relocate_piece(state, "red-pawn-1", Vector2i(5, 10))
	var blocker_ids: Array = _fill_base(state, MatchState.RED)
	var returned: Dictionary = RuleEngine.return_pieces_to_base(
		state, MatchState.RED, ["red-pawn-1"], "test_return"
	)
	assert(returned["queued_piece_ids"] == ["red-pawn-1"])
	assert(state["pieces"]["red-pawn-1"]["in_reserve"])
	assert(state["pieces"]["red-pawn-1"]["position"].is_empty())
	var released_id: String = blocker_ids[0]
	MatchState.remove_piece_from_board(state, released_id)
	state["pieces"][released_id]["alive"] = false
	var action_index_before: int = state["action_index"]
	var deployed: Array = RuleEngine.begin_action(state)
	assert(deployed.size() == 1 and deployed[0]["piece_id"] == "red-pawn-1")
	assert(not state["pieces"]["red-pawn-1"]["in_reserve"])
	assert(state["action_index"] == action_index_before, "行动前自动部署不得消费行动")
	return true


static func _test_wall_repair_counts_actions_after_trigger() -> bool:
	var state: Dictionary = RuleEngine.create_match(5505)
	MatchState.relocate_piece(state, "red-pawn-1", Vector2i(2, 18))
	MatchState.relocate_piece(state, "red-pawn-2", Vector2i(4, 18))
	state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	assert(_assert_consumed(RuleEngine.submit_action(state, _pass())))
	var wall: Dictionary = state["walls"][MatchState.BLACK]
	assert(wall["status"] == "REPAIRING")
	assert(wall["sides_acted_since_repair_start"].is_empty(), "触发行动不计入修复")
	assert(_assert_consumed(RuleEngine.submit_action(state, _pass())))
	assert(wall["sides_acted_since_repair_start"] == [MatchState.BLACK])
	assert(_assert_consumed(RuleEngine.submit_action(state, _pass())))
	assert(wall["status"] == "INTACT", "触发后双方各完成一次行动才恢复")
	return true


static func _fill_base(state: Dictionary, side: String) -> Array:
	var ids: Array = []
	var empty_cells: Array = MatchState.base_empty_cells(state, side)
	for index: int in empty_cells.size():
		var cell: Vector2i = empty_cells[index]
		var piece_id: String = "test-blocker-%d" % index
		state["pieces"][piece_id] = {
			"id": piece_id,
			"side": side,
			"piece_type": "blocker",
			"position": [cell.x, cell.y],
			"alive": true,
			"in_reserve": false,
			"reserve_queue_index": -1,
			"hidden": false,
			"bombard_ammo": 0,
			"rescue_available": false,
			"temporary_effects": [],
		}
		state["board"][Canonical.cell_key(cell)] = piece_id
		ids.append(piece_id)
	return ids


static func _flag(flag_id: String, position: Vector2i) -> Dictionary:
	return {
		"id": flag_id,
		"position": [position.x, position.y],
		"owner": MatchState.NEUTRAL,
		"occupier_piece_id": "",
		"capturing_side": "",
		"capture_progress": 0,
		"contested": false,
	}


static func _move(piece_id: String, target: Vector2i) -> Dictionary:
	return {"piece_id": piece_id, "action_type": "move", "target_cell": [target.x, target.y], "skill_type": ""}


static func _pass() -> Dictionary:
	return {"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""}


static func _assert_consumed(result: Dictionary) -> bool:
	return result.get("ok", false) and result.get("consumed", false)
