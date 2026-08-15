const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const MoveRules = preload("res://scripts/prototype/core/move_rules.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const Projector = preload("res://scripts/prototype/view/player_view_projector.gd")


static func run_suite() -> bool:
	var failures: Array[String] = []
	_test_exact_nine_cells_without_clipping(failures)
	_test_standard_move_reveals_hidden_horse_only_inside_zone(failures)
	_test_multiple_elephants_union_and_move_refresh(failures)
	_test_source_clears_when_next_move_reaches_resolution(failures)
	_test_source_clears_on_all_exit_paths(failures)
	_test_hidden_full_states_remain_player_view_equivalent(failures)
	for failure: String in failures:
		push_error("ELEPHANT_REVEAL_FAIL: %s" % failure)
	return failures.is_empty()


static func _test_exact_nine_cells_without_clipping(failures: Array[String]) -> void:
	var expected: Array = [
		[5, 10], [6, 10], [7, 10],
		[5, 11], [6, 11], [7, 11],
		[5, 12], [6, 12], [7, 12],
	]
	_expect(MoveRules.reveal_cells_for_elephant_move(Vector2i(5, 10), Vector2i(7, 12)) == expected,
			"起点、象眼、终点构成完整且稳定排序的3×3九格", failures)
	var unbounded_expected: Array = [
		[0, 0], [1, 0], [2, 0],
		[0, 1], [1, 1], [2, 1],
		[0, 2], [1, 2], [2, 2],
	]
	_expect(MoveRules.reveal_cells_for_elephant_move(Vector2i(0, 0), Vector2i(2, 2)) == unbounded_expected,
			"九格定义本身不按棋盘边界裁切", failures)


static func _test_standard_move_reveals_hidden_horse_only_inside_zone(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(501)
	state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(state, "red-elephant-1", Vector2i(5, 10))
	_place(state, "black-horse-1", Vector2i(6, 10))
	_place(state, "black-horse-2", Vector2i(8, 10))
	state["pieces"]["black-horse-1"]["hidden"] = true
	state["pieces"]["black-horse-2"]["hidden"] = true
	var result: Dictionary = RuleEngine.submit_action(state, _move("red-elephant-1", Vector2i(7, 12)))
	_expect(result.get("consumed", false)
			and result.get("event", {}).get("outcome", {}).get("move_kind", "") == "elephant_standard",
			"破墙状态下普通相象移动可结算", failures)
	var zone: Array = state["vision_sources"][MatchState.RED]["elephant_reveal_zones"].get("red-elephant-1", [])
	_expect(zone == MoveRules.reveal_cells_for_elephant_move(Vector2i(5, 10), Vector2i(7, 12)),
			"每次合法普通相象移动也建立九格源", failures)
	var view: Dictionary = Projector.project(state, MatchState.RED)
	_expect(_view_has_piece(view, "black-horse-1"), "九格内隐藏马显形", failures)
	_expect(not _view_has_piece(view, "black-horse-2"), "九格外隐藏马不显形", failures)
	MatchState.relocate_piece(state, "black-horse-1", Vector2i(4, 10))
	_expect(not _view_has_piece(Projector.project(state, MatchState.RED), "black-horse-1"),
			"隐藏马离开九格后恢复不可见", failures)


static func _test_multiple_elephants_union_and_move_refresh(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(502)
	state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(state, "red-elephant-1", Vector2i(3, 10))
	_place(state, "red-elephant-2", Vector2i(7, 10))
	_place(state, "black-horse-1", Vector2i(4, 10))
	_place(state, "black-horse-2", Vector2i(8, 10))
	state["pieces"]["black-horse-1"]["hidden"] = true
	state["pieces"]["black-horse-2"]["hidden"] = true
	RuleEngine.submit_action(state, _move("red-elephant-1", Vector2i(5, 12)))
	state["active_side"] = MatchState.RED
	RuleEngine.submit_action(state, _move("red-elephant-2", Vector2i(9, 12)))
	var zones: Dictionary = state["vision_sources"][MatchState.RED]["elephant_reveal_zones"]
	_expect(zones.size() == 2, "两枚相象各自保留一个显形源", failures)
	var union_view: Dictionary = Projector.project(state, MatchState.RED)
	_expect(_view_has_piece(union_view, "black-horse-1") and _view_has_piece(union_view, "black-horse-2"),
			"多枚相象九格源按并集投影", failures)
	state["active_side"] = MatchState.RED
	RuleEngine.submit_action(state, _move("red-elephant-1", Vector2i(7, 14)))
	var refreshed: Dictionary = state["vision_sources"][MatchState.RED]["elephant_reveal_zones"]
	_expect(refreshed.size() == 2
			and refreshed["red-elephant-1"] == MoveRules.reveal_cells_for_elephant_move(Vector2i(5, 12), Vector2i(7, 14))
			and refreshed.has("red-elephant-2"),
			"一枚相象移动只刷新自身旧源并保留其他相象源", failures)


static func _test_source_clears_when_next_move_reaches_resolution(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(503)
	state["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(state, "red-elephant-1", Vector2i(5, 10))
	RuleEngine.submit_action(state, _move("red-elephant-1", Vector2i(7, 12)))
	state["active_side"] = MatchState.RED
	_place(state, "black-horse-1", Vector2i(8, 13))
	state["pieces"]["black-horse-1"]["hidden"] = true
	var blocked: Dictionary = RuleEngine.submit_action(state, _move("red-elephant-1", Vector2i(9, 14)))
	_expect(blocked.get("consumed", false)
			and not state["vision_sources"][MatchState.RED]["elephant_reveal_zones"].has("red-elephant-1"),
			"相象下一次真实移动开始并在象眼受阻时旧源也立即清除", failures)


static func _test_source_clears_on_all_exit_paths(failures: Array[String]) -> void:
	var death: Dictionary = _empty_state(504)
	death["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(death, "red-rook-1", Vector2i(5, 10))
	_place(death, "black-elephant-1", Vector2i(5, 12))
	_set_zone(death, MatchState.BLACK, "black-elephant-1")
	RuleEngine.submit_action(death, _move("red-rook-1", Vector2i(5, 12)))
	_expect(not death["pieces"]["black-elephant-1"]["alive"] and not _has_zone(death, MatchState.BLACK, "black-elephant-1"),
			"相象死亡清除九格源", failures)

	var rescue: Dictionary = _empty_state(505)
	rescue["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(rescue, "red-rook-1", Vector2i(5, 10))
	_place(rescue, "black-elephant-1", Vector2i(5, 12))
	_place(rescue, "black-advisor-1", Vector2i(4, 24))
	_set_zone(rescue, MatchState.BLACK, "black-elephant-1")
	RuleEngine.submit_action(rescue, _move("red-rook-1", Vector2i(5, 12)))
	_expect(rescue["pieces"]["black-elephant-1"]["alive"]
			and MatchState.is_in_base(Canonical.coordinate(rescue["pieces"]["black-elephant-1"]["position"]), MatchState.BLACK)
			and not _has_zone(rescue, MatchState.BLACK, "black-elephant-1"),
			"士替死救援回营清除被救相象九格源", failures)

	var returned: Dictionary = _empty_state(506)
	_place(returned, "red-elephant-1", Vector2i(5, 10))
	_set_zone(returned, MatchState.RED, "red-elephant-1")
	RuleEngine.return_pieces_to_base(returned, MatchState.RED, ["red-elephant-1"], "elephant_reveal_test")
	_expect(MatchState.is_in_base(Canonical.coordinate(returned["pieces"]["red-elephant-1"]["position"]), MatchState.RED)
			and not _has_zone(returned, MatchState.RED, "red-elephant-1"),
			"显式回营清除相象九格源", failures)

	var reserve: Dictionary = MatchState.create(507)
	MatchState.relocate_piece(reserve, "red-elephant-1", Vector2i(5, 10))
	_fill_base_with_blockers(reserve, MatchState.RED)
	_set_zone(reserve, MatchState.RED, "red-elephant-1")
	RuleEngine.return_pieces_to_base(reserve, MatchState.RED, ["red-elephant-1"], "elephant_reserve_test")
	_expect(reserve["pieces"]["red-elephant-1"]["in_reserve"]
			and not _has_zone(reserve, MatchState.RED, "red-elephant-1"),
			"回营无空位进入后备队列时清除相象九格源", failures)

	var withdrawn: Dictionary = _empty_state(508)
	_place(withdrawn, "red-elephant-1", Vector2i(5, 22))
	_set_zone(withdrawn, MatchState.RED, "red-elephant-1")
	withdrawn["walls"][MatchState.BLACK]["status"] = "REPAIRING"
	withdrawn["walls"][MatchState.BLACK]["sides_acted_since_repair_start"] = [MatchState.RED]
	withdrawn["active_side"] = MatchState.BLACK
	RuleEngine.submit_action(withdrawn, {"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""})
	_expect(withdrawn["walls"][MatchState.BLACK]["status"] == "INTACT"
			and not MatchState.is_in_base(Canonical.coordinate(withdrawn["pieces"]["red-elephant-1"]["position"]), MatchState.BLACK)
			and not _has_zone(withdrawn, MatchState.RED, "red-elephant-1"),
			"修墙撤回清除入侵相象九格源", failures)


static func _test_hidden_full_states_remain_player_view_equivalent(failures: Array[String]) -> void:
	var first: Dictionary = _empty_state(509)
	first["walls"][MatchState.BLACK]["status"] = "BREACHED"
	_place(first, "red-elephant-1", Vector2i(5, 10))
	RuleEngine.submit_action(first, _move("red-elephant-1", Vector2i(7, 12)))
	var second: Dictionary = MatchState.clone(first)
	_place(first, "black-horse-1", Vector2i(9, 18))
	_place(second, "black-horse-2", Vector2i(9, 18))
	first["pieces"]["black-horse-1"]["hidden"] = true
	second["pieces"]["black-horse-2"]["hidden"] = true
	_expect(Canonical.digest(Projector.project(first, MatchState.RED))
			== Canonical.digest(Projector.project(second, MatchState.RED)),
			"九格外隐藏身份差异保持PlayerView黑盒等价", failures)


static func _empty_state(seed_value: int) -> Dictionary:
	var state: Dictionary = MatchState.create(seed_value)
	for piece_id_value: Variant in state["pieces"].keys():
		var piece_id: String = str(piece_id_value)
		MatchState.remove_piece_from_board(state, piece_id)
		state["pieces"][piece_id]["alive"] = false
		state["pieces"][piece_id]["in_reserve"] = false
	return state


static func _place(state: Dictionary, piece_id: String, cell: Vector2i) -> void:
	if state["pieces"][piece_id]["alive"]:
		MatchState.remove_piece_from_board(state, piece_id)
	var occupant: Dictionary = MatchState.piece_at(state, cell)
	if not occupant.is_empty():
		MatchState.remove_piece_from_board(state, occupant["id"])
		occupant["alive"] = false
	state["pieces"][piece_id]["alive"] = true
	state["pieces"][piece_id]["in_reserve"] = false
	MatchState.relocate_piece(state, piece_id, cell)


static func _move(piece_id: String, target: Vector2i) -> Dictionary:
	return {"piece_id": piece_id, "action_type": "move", "target_cell": [target.x, target.y], "skill_type": ""}


static func _set_zone(state: Dictionary, side: String, piece_id: String) -> void:
	state["vision_sources"][side]["elephant_reveal_zones"][piece_id] = [
		[5, 10], [6, 10], [7, 10], [5, 11], [6, 11], [7, 11], [5, 12], [6, 12], [7, 12],
	]


static func _has_zone(state: Dictionary, side: String, piece_id: String) -> bool:
	return state["vision_sources"][side]["elephant_reveal_zones"].has(piece_id)


static func _view_has_piece(view: Dictionary, piece_id: String) -> bool:
	for piece: Dictionary in view["pieces"]:
		if piece["id"] == piece_id:
			return true
	return false


static func _fill_base_with_blockers(state: Dictionary, side: String) -> void:
	var empty_cells: Array = MatchState.base_empty_cells(state, side)
	for index: int in empty_cells.size():
		var cell: Vector2i = empty_cells[index]
		var piece_id: String = "elephant-reveal-blocker-%s-%d" % [side, index]
		state["pieces"][piece_id] = {
			"id": piece_id, "side": side, "piece_type": "blocker",
			"position": [cell.x, cell.y], "alive": true, "in_reserve": false,
			"reserve_queue_index": -1, "hidden": false, "revealed_to": [],
			"bombard_ammo": 0, "rescue_available": false, "temporary_effects": [],
		}
		state["board"][Canonical.cell_key(cell)] = piece_id


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
