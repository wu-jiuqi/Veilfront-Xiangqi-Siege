extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const MoveRules = preload("res://scripts/prototype/core/move_rules.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const Projector = preload("res://scripts/prototype/view/player_view_projector.gd")


static func run_suite() -> bool:
	var failures: Array[String] = []
	_test_exact_vision_union_and_block_field(failures)
	_test_special_move_reveals_hidden_horse(failures)
	_test_source_refresh_and_clear(failures)
	_test_hidden_equivalence_outside_zone(failures)
	for failure: String in failures:
		push_error("ELEPHANT_REVEAL_FAIL: %s" % failure)
	return failures.is_empty()


static func _test_exact_vision_union_and_block_field(failures: Array[String]) -> void:
	var vision: Array = MoveRules.reveal_cells_for_elephant_move(Vector2i(5, 10), Vector2i(7, 12))
	var field: Array = MoveRules.elephant_block_cells_for_move(Vector2i(5, 10), Vector2i(7, 12))
	_expect(vision.size() == 19, "起点3x3、路径田字格、终点3x3并集应为19格", failures)
	_expect(field == [
		[5, 10], [6, 10], [7, 10], [5, 11], [6, 11], [7, 11],
		[5, 12], [6, 12], [7, 12],
	], "田字格阻挡源保持稳定九点排序", failures)
	_expect(vision.front() == [4, 9] and vision.back() == [8, 13], "完整视野按行列稳定排序且不提前裁切", failures)


static func _test_special_move_reveals_hidden_horse(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(501)
	_place(state, "red-elephant-1", Vector2i(5, 10))
	_place(state, "black-horse-1", Vector2i(4, 9))
	_place(state, "black-horse-2", Vector2i(9, 10))
	state["pieces"]["black-horse-1"]["hidden"] = true
	state["pieces"]["black-horse-2"]["hidden"] = true
	var result: Dictionary = RuleEngine.submit_action(state, _move("red-elephant-1", Vector2i(7, 12)))
	_expect(result.get("event", {}).get("outcome", {}).get("move_kind", "") == "elephant_special",
			"完整敌墙下特殊区相移动建立视野和阻挡源", failures)
	var view: Dictionary = Projector.project(state, MatchState.RED)
	_expect(_view_has_piece(view, "black-horse-1"), "完整相视野并集内隐藏马显形", failures)
	_expect(not _view_has_piece(view, "black-horse-2"), "完整相视野并集外隐藏马保持隐匿", failures)
	for cell: Array in MoveRules.reveal_cells_for_elephant_move(Vector2i(5, 10), Vector2i(7, 12)):
		if MatchState.is_inside_board(Canonical.coordinate(cell)):
			_expect(cell in view["visible_cells"], "相视野格应进入普通可见格投影", failures)


static func _test_source_refresh_and_clear(failures: Array[String]) -> void:
	var state: Dictionary = _empty_state(502)
	_place(state, "red-elephant-1", Vector2i(3, 10))
	RuleEngine.submit_action(state, _move("red-elephant-1", Vector2i(5, 12)))
	_expect(state["vision_sources"][MatchState.RED]["elephant_reveal_zones"].has("red-elephant-1") \
			and state["vision_sources"][MatchState.RED]["elephant_block_fields"].has("red-elephant-1"),
			"特殊移动同时建立视野源和敌车阻挡源", failures)
	state["active_side"] = MatchState.RED
	RuleEngine.submit_action(state, _move("red-elephant-1", Vector2i(7, 14)))
	_expect(state["vision_sources"][MatchState.RED]["elephant_reveal_zones"]["red-elephant-1"] \
			== MoveRules.reveal_cells_for_elephant_move(Vector2i(5, 12), Vector2i(7, 14)),
			"相再次移动刷新为最新视野源", failures)
	RuleEngine.return_pieces_to_base(state, MatchState.RED, ["red-elephant-1"], "elephant_test")
	_expect(not state["vision_sources"][MatchState.RED]["elephant_reveal_zones"].has("red-elephant-1") \
			and not state["vision_sources"][MatchState.RED]["elephant_block_fields"].has("red-elephant-1"),
			"相回营同时清除视野与阻挡源", failures)


static func _test_hidden_equivalence_outside_zone(failures: Array[String]) -> void:
	var state_a: Dictionary = _empty_state(503)
	var state_b: Dictionary = MatchState.clone(state_a)
	_place(state_a, "red-elephant-1", Vector2i(5, 10))
	_place(state_b, "red-elephant-1", Vector2i(5, 10))
	_place(state_a, "black-horse-1", Vector2i(9, 18))
	_place(state_b, "black-horse-1", Vector2i(8, 18))
	state_a["pieces"]["black-horse-1"]["hidden"] = true
	state_b["pieces"]["black-horse-1"]["hidden"] = true
	RuleEngine.submit_action(state_a, _move("red-elephant-1", Vector2i(7, 12)))
	RuleEngine.submit_action(state_b, _move("red-elephant-1", Vector2i(7, 12)))
	_expect(Canonical.digest(Projector.project(state_a, MatchState.RED)) \
			== Canonical.digest(Projector.project(state_b, MatchState.RED)),
			"相视野外隐藏差异不改变PlayerView", failures)


static func _empty_state(seed_value: int) -> Dictionary:
	var state: Dictionary = MatchState.create(seed_value)
	for piece_value: Variant in state["pieces"].values():
		var piece: Dictionary = piece_value
		MatchState.remove_piece_from_board(state, piece["id"])
		piece["alive"] = false
		piece["in_reserve"] = false
	state["board"].clear()
	return state


static func _place(state: Dictionary, piece_id: String, cell: Vector2i) -> void:
	var occupant: Dictionary = MatchState.piece_at(state, cell)
	if not occupant.is_empty():
		MatchState.remove_piece_from_board(state, occupant["id"])
		occupant["alive"] = false
	MatchState.relocate_piece(state, piece_id, cell)


static func _move(piece_id: String, target: Vector2i) -> Dictionary:
	return {"piece_id": piece_id, "action_type": "move", "target_cell": [target.x, target.y], "skill_type": ""}


static func _view_has_piece(view: Dictionary, piece_id: String) -> bool:
	for piece: Dictionary in view["pieces"]:
		if piece["id"] == piece_id:
			return true
	return false


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)
