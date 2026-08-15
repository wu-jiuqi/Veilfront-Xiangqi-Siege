extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const SeededRandom = preload("res://scripts/prototype/core/seeded_random.gd")
const PlayerViewProjector = preload("res://scripts/prototype/view/player_view_projector.gd")


static func create_match(seed_value: int) -> Dictionary:
	return MatchState.create(seed_value)


static func submit_action(state: Dictionary, intent: Dictionary) -> Dictionary:
	if state["terminal"]:
		return _rejected("terminal", "match_already_terminal")
	var actor_side: String = state["active_side"]
	var action_index: int = state["action_index"]
	var random_record_start: int = state["rng"]["records"].size()
	var deployments: Array = begin_action(state)
	var action_type: String = str(intent.get("action_type", ""))
	var outcome: Dictionary
	match action_type:
		"pass", "skip", "timeout":
			outcome = {
				"ok": true,
				"consumed": true,
				"result_code": action_type,
				"position": [],
			}
		"move":
			outcome = _resolve_move(state, intent, actor_side)
		"bombard":
			outcome = _resolve_bombardment(state, intent, actor_side)
		_:
			outcome = _rejected("known_illegal", "unsupported_action_type")
	if not outcome.get("consumed", false):
		return outcome

	if not state["terminal"]:
		_update_walls_after_action(state, actor_side)
	if not state["terminal"]:
		_update_flags_after_action(state, actor_side)
	_publish_player_event(state, actor_side, action_index, outcome)
	if not state["terminal"]:
		_advance_turn(state, actor_side)

	var event: Dictionary = {
		"schema_version": "action-event-v1",
		"event_id": "action-%d" % action_index,
		"action_index": action_index,
		"actor_side": actor_side,
		"intent": _normalized_intent(intent),
		"deployments_before_action": deployments,
		"outcome": outcome.duplicate(true),
		"random_samples": state["rng"]["records"].slice(random_record_start).duplicate(true),
	}
	state["events"].append(event)
	return {
		"ok": true,
		"consumed": true,
		"event": event.duplicate(true),
		"state_summary": MatchState.summary(state),
	}


static func can_bombard(state: Dictionary, cannon_id: String) -> bool:
	if not state["pieces"].has(cannon_id):
		return false
	var cannon: Dictionary = state["pieces"][cannon_id]
	if not cannon["alive"] or cannon["in_reserve"] or cannon["piece_type"] != "cannon":
		return false
	var side: String = cannon["side"]
	var enemy_side: String = MatchState.opponent(side)
	var position := Canonical.coordinate(cannon["position"])
	return MatchState.is_in_base(position, side) \
		and state["walls"][enemy_side]["status"] == "INTACT" \
		and int(cannon["bombard_ammo"]) > 0


static func begin_action(state: Dictionary) -> Array:
	var side: String = state["active_side"]
	var queue: Array = state["reserve_queues"][side]
	var deployments: Array = []
	while not queue.is_empty():
		var empty_cells: Array = MatchState.base_empty_cells(state, side)
		if empty_cells.is_empty():
			break
		var piece_id: String = str(queue.pop_front())
		var selected: Array = SeededRandom.draw_unique(state["rng"], empty_cells, 1, "reserve_deploy:%s" % piece_id)
		var cell: Vector2i = selected[0]
		var piece: Dictionary = state["pieces"][piece_id]
		piece["in_reserve"] = false
		piece["reserve_queue_index"] = -1
		MatchState.relocate_piece(state, piece_id, cell)
		deployments.append({"piece_id": piece_id, "position": [cell.x, cell.y]})
	_update_reserve_indexes(state, side)
	return deployments


static func return_pieces_to_base(state: Dictionary, side: String, piece_ids: Array, reason: String) -> Dictionary:
	var ordered_ids: Array = piece_ids.duplicate()
	var placements: Array = []
	var queued: Array = []
	for piece_id_value: Variant in ordered_ids:
		var piece_id: String = str(piece_id_value)
		_cancel_flag_capture_for_piece(state, piece_id)
		MatchState.remove_piece_from_board(state, piece_id)
		var piece: Dictionary = state["pieces"][piece_id]
		piece["hidden"] = false
		piece["temporary_effects"] = []
		piece["in_reserve"] = false
	var empty_cells: Array = MatchState.base_empty_cells(state, side)
	for piece_id_value: Variant in ordered_ids:
		var piece_id: String = str(piece_id_value)
		if empty_cells.is_empty():
			var piece: Dictionary = state["pieces"][piece_id]
			piece["in_reserve"] = true
			piece["position"] = []
			if not state["reserve_queues"][side].has(piece_id):
				state["reserve_queues"][side].append(piece_id)
			queued.append(piece_id)
			continue
		var selected: Array = SeededRandom.draw_unique(state["rng"], empty_cells, 1, "%s:%s" % [reason, piece_id])
		var cell: Vector2i = selected[0]
		empty_cells.erase(cell)
		MatchState.relocate_piece(state, piece_id, cell)
		placements.append({"piece_id": piece_id, "position": [cell.x, cell.y]})
	_update_reserve_indexes(state, side)
	return {
		"schema_version": "base-return-v1",
		"side": side,
		"reason": reason,
		"placements": placements,
		"queued_piece_ids": queued,
	}


static func resolve_bombardment_window(
	state: Dictionary,
	cannon_id: String,
	target_center: Vector2i,
	impact_cells: Array
) -> Dictionary:
	assert(impact_cells.size() == 3)
	var unique: Dictionary = {}
	var snapshot_targets: Array = []
	for index: int in impact_cells.size():
		var cell := Canonical.coordinate(impact_cells[index])
		assert(MatchState.is_inside_board(cell))
		unique[Canonical.cell_key(cell)] = true
		var target: Dictionary = MatchState.piece_at(state, cell)
		snapshot_targets.append({
			"impact_number": index + 1,
			"position": [cell.x, cell.y],
			"piece_id": str(target.get("id", "")),
			"piece_type": str(target.get("piece_type", "")),
			"side": str(target.get("side", "")),
		})
	assert(unique.size() == 3)

	var dead_generals: Dictionary = {}
	var impacted_piece_ids: Dictionary = {}
	var casualties: Array = []
	for target: Dictionary in snapshot_targets:
		if target["piece_id"].is_empty():
			continue
		var piece: Dictionary = state["pieces"][target["piece_id"]]
		impacted_piece_ids[piece["id"]] = true
		_cancel_flag_capture_for_piece(state, piece["id"])
		MatchState.remove_piece_from_board(state, piece["id"])
		piece["alive"] = false
		var casualty: Dictionary = target.duplicate(true)
		casualty["rescued"] = false
		casualties.append(casualty)
		if piece["piece_type"] == "general":
			dead_generals[piece["side"]] = true

	if dead_generals.has(MatchState.RED) and dead_generals.has(MatchState.BLACK):
		_set_terminal(state, "draw", "simultaneous_generals_destroyed")
	elif dead_generals.has(MatchState.RED):
		_set_terminal(state, MatchState.BLACK, "general_destroyed")
	elif dead_generals.has(MatchState.BLACK):
		_set_terminal(state, MatchState.RED, "general_destroyed")

	var rescue_records: Array = []
	if dead_generals.is_empty():
		for casualty: Dictionary in casualties:
			if casualty["piece_type"] == "general" or casualty["piece_type"] == "advisor":
				continue
			var side: String = casualty["side"]
			if int(state["rescue_eligible_events"][side]) >= 2:
				continue
			state["rescue_eligible_events"][side] = int(state["rescue_eligible_events"][side]) + 1
			var advisors: Array = _available_rescue_advisors(state, side, impacted_piece_ids)
			if advisors.is_empty():
				continue
			var selected: Array = SeededRandom.draw_unique(
				state["rng"], advisors, 1, "advisor_rescue:%s" % casualty["piece_id"]
			)
			var advisor_id: String = str(selected[0])
			var advisor: Dictionary = state["pieces"][advisor_id]
			_cancel_flag_capture_for_piece(state, advisor_id)
			MatchState.remove_piece_from_board(state, advisor_id)
			advisor["alive"] = false
			advisor["rescue_available"] = false
			var rescued_piece: Dictionary = state["pieces"][casualty["piece_id"]]
			rescued_piece["alive"] = true
			var base_return: Dictionary = return_pieces_to_base(
				state, side, [casualty["piece_id"]], "advisor_rescue_return"
			)
			casualty["rescued"] = true
			rescue_records.append({
				"impact_number": casualty["impact_number"],
				"rescued_piece_id": casualty["piece_id"],
				"sacrificed_advisor_id": advisor_id,
				"base_return": base_return,
			})

	var normalized_cells: Array = []
	for cell_value: Variant in impact_cells:
		var cell := Canonical.coordinate(cell_value)
		normalized_cells.append([cell.x, cell.y])
	return {
		"schema_version": "bombardment-result-v1",
		"random_seed": state["rng"]["seed"],
		"target_center": [target_center.x, target_center.y],
		"impact_cells": normalized_cells,
		"impact_order": [1, 2, 3],
		"simultaneous_resolution_id": "bombard-window-%d-%s" % [state["action_index"], cannon_id],
		"casualties": casualties,
		"rescue_records": rescue_records,
		"general_resolution": {
			"red_destroyed": dead_generals.has(MatchState.RED),
			"black_destroyed": dead_generals.has(MatchState.BLACK),
			"winner": state["winner"],
			"win_reason": state["win_reason"],
		},
	}


static func _available_rescue_advisors(
	state: Dictionary,
	side: String,
	impacted_piece_ids: Dictionary
) -> Array:
	var result: Array = []
	for piece_value: Variant in state["pieces"].values():
		var piece: Dictionary = piece_value
		if piece["side"] == side and piece["piece_type"] == "advisor" \
		and piece["alive"] and piece["rescue_available"] \
		and not impacted_piece_ids.has(piece["id"]):
			result.append(piece["id"])
	result.sort()
	return result


static func _resolve_move(state: Dictionary, intent: Dictionary, actor_side: String) -> Dictionary:
	var player_view: Dictionary = PlayerViewProjector.project(state, actor_side)
	var preview: Dictionary = PlayerViewProjector.preview_intent(player_view, intent)
	if preview["classification"] == PlayerViewProjector.KNOWN_ILLEGAL:
		return _rejected("known_illegal", "visible_rule_rejection")
	var piece_id: String = str(intent.get("piece_id", ""))
	if not state["pieces"].has(piece_id):
		return _rejected("known_illegal", "unknown_piece")
	var piece: Dictionary = state["pieces"][piece_id]
	if piece["side"] != actor_side or not piece["alive"] or piece["in_reserve"]:
		return _rejected("known_illegal", "piece_unavailable")
	var origin := Canonical.coordinate(piece["position"])
	var target := Canonical.coordinate(intent.get("target_cell", []))
	if not MatchState.is_inside_board(target):
		return _rejected("known_illegal", "target_out_of_bounds")
	var path: Array = _orthogonal_path(origin, target)
	if path.is_empty():
		return _rejected("known_illegal", "prototype_move_geometry")
	for index: int in path.size() - 1:
		if not MatchState.piece_at(state, path[index]).is_empty():
			state["contact_intel"][actor_side].append({
				"schema_version": "contact-intel-v1",
				"kind": "route_unknown_blocked",
				"cell": [],
				"revealed_identity": "",
				"created_at_action_index": state["action_index"],
				"persistent_tracking": false,
			})
			return {
				"ok": true,
				"consumed": true,
				"result_code": "route_unknown_blocked",
				"position": [origin.x, origin.y],
			}
	var target_piece: Dictionary = MatchState.piece_at(state, target)
	if not target_piece.is_empty() and target_piece["side"] == actor_side:
		return _rejected("known_illegal", "known_own_piece_target")
	_cancel_flag_capture_for_piece(state, piece_id)
	var captured_piece_id: String = ""
	if not target_piece.is_empty():
		captured_piece_id = target_piece["id"]
		_cancel_flag_capture_for_piece(state, captured_piece_id)
		MatchState.remove_piece_from_board(state, captured_piece_id)
		target_piece["alive"] = false
		if target_piece["piece_type"] == "general":
			_set_terminal(state, actor_side, "general_destroyed")
	MatchState.relocate_piece(state, piece_id, target)
	if not state["terminal"]:
		_start_flag_capture(state, piece_id)
	return {
		"ok": true,
		"consumed": true,
		"result_code": "move_resolved",
		"position": [target.x, target.y],
		"captured_piece_id": captured_piece_id,
	}


static func _resolve_bombardment(state: Dictionary, intent: Dictionary, actor_side: String) -> Dictionary:
	var cannon_id: String = str(intent.get("piece_id", ""))
	if not can_bombard(state, cannon_id) or state["pieces"][cannon_id]["side"] != actor_side:
		return _rejected("known_illegal", "bombardment_not_available")
	var center := Canonical.coordinate(intent.get("target_cell", []))
	if center.x < 2 or center.x > 8 or center.y < 7 or center.y > 18:
		return _rejected("known_illegal", "bombardment_area_out_of_bounds")
	var candidates: Array = []
	for y: int in range(center.y - 1, center.y + 2):
		for x: int in range(center.x - 1, center.x + 2):
			candidates.append(Vector2i(x, y))
	state["pieces"][cannon_id]["bombard_ammo"] = int(state["pieces"][cannon_id]["bombard_ammo"]) - 1
	var impacts: Array = SeededRandom.draw_unique(state["rng"], candidates, 3, "bombardment_impact")
	var result: Dictionary = resolve_bombardment_window(state, cannon_id, center, impacts)
	return {
		"ok": true,
		"consumed": true,
		"result_code": "bombardment_resolved",
		"position": [center.x, center.y],
		"bombardment_result": result,
	}


static func _update_walls_after_action(state: Dictionary, actor_side: String) -> void:
	for wall_side: String in [MatchState.RED, MatchState.BLACK]:
		var wall: Dictionary = state["walls"][wall_side]
		var buffer_invaders: int = _count_invaders(state, wall_side, true)
		var region_invaders: int = _count_invaders(state, wall_side, false)
		wall["invading_piece_count"] = region_invaders
		if wall["status"] == "INTACT" and buffer_invaders >= 3:
			wall["status"] = "BREACHED"
			wall["repair_start_action_index"] = -1
			wall["sides_acted_since_repair_start"] = []
			continue
		if wall["status"] == "BREACHED" and region_invaders < 3:
			wall["status"] = "REPAIRING"
			wall["repair_start_action_index"] = state["action_index"]
			wall["sides_acted_since_repair_start"] = []
			continue
		if wall["status"] != "REPAIRING":
			continue
		if region_invaders >= 3:
			wall["status"] = "BREACHED"
			wall["repair_start_action_index"] = -1
			wall["sides_acted_since_repair_start"] = []
			continue
		if not wall["sides_acted_since_repair_start"].has(actor_side):
			wall["sides_acted_since_repair_start"].append(actor_side)
		if wall["sides_acted_since_repair_start"].has(MatchState.RED) \
		and wall["sides_acted_since_repair_start"].has(MatchState.BLACK):
			wall["status"] = "INTACT"
			wall["repair_start_action_index"] = -1
			wall["sides_acted_since_repair_start"] = []
			_withdraw_base_invaders(state, wall_side)


static func _update_flags_after_action(state: Dictionary, actor_side: String) -> void:
	for flag: Dictionary in state["flags"]:
		var occupier_id: String = flag["occupier_piece_id"]
		if occupier_id.is_empty():
			continue
		var piece: Dictionary = state["pieces"].get(occupier_id, {})
		if piece.is_empty() or not piece["alive"] or piece["in_reserve"] \
		or Canonical.coordinate(piece["position"]) != Canonical.coordinate(flag["position"]):
			_clear_capture(flag)
			continue
		if flag["capturing_side"] == MatchState.opponent(actor_side):
			flag["capture_progress"] = int(flag["capture_progress"]) + 1
			if flag["capture_progress"] >= 3:
				flag["owner"] = flag["capturing_side"]
				_clear_capture(flag)
	var winner_side: String = ""
	for side: String in [MatchState.RED, MatchState.BLACK]:
		var owned_count: int = 0
		for flag: Dictionary in state["flags"]:
			if flag["owner"] == side and not flag["contested"]:
				owned_count += 1
		if owned_count == 3:
			winner_side = side
	if not winner_side.is_empty():
		_set_terminal(state, winner_side, "three_flags")


static func _start_flag_capture(state: Dictionary, piece_id: String) -> void:
	var piece: Dictionary = state["pieces"][piece_id]
	var position := Canonical.coordinate(piece["position"])
	for flag: Dictionary in state["flags"]:
		if Canonical.coordinate(flag["position"]) != position or flag["owner"] == piece["side"]:
			continue
		flag["occupier_piece_id"] = piece_id
		flag["capturing_side"] = piece["side"]
		flag["capture_progress"] = 0
		flag["contested"] = flag["owner"] != MatchState.NEUTRAL


static func _cancel_flag_capture_for_piece(state: Dictionary, piece_id: String) -> void:
	for flag: Dictionary in state["flags"]:
		if flag["occupier_piece_id"] == piece_id:
			_clear_capture(flag)


static func _clear_capture(flag: Dictionary) -> void:
	flag["occupier_piece_id"] = ""
	flag["capturing_side"] = ""
	flag["capture_progress"] = 0
	flag["contested"] = false


static func _count_invaders(state: Dictionary, wall_side: String, buffer_only: bool) -> int:
	var count: int = 0
	for piece_value: Variant in state["pieces"].values():
		var piece: Dictionary = piece_value
		if not piece["alive"] or piece["in_reserve"] or piece["side"] == wall_side:
			continue
		var position := Canonical.coordinate(piece["position"])
		if (buffer_only and MatchState.is_in_buffer(position, wall_side)) \
		or (not buffer_only and MatchState.is_in_buffer_or_base(position, wall_side)):
			count += 1
	return count


static func _withdraw_base_invaders(state: Dictionary, wall_side: String) -> void:
	var invader_side: String = MatchState.opponent(wall_side)
	var piece_ids: Array = []
	for piece_value: Variant in state["pieces"].values():
		var piece: Dictionary = piece_value
		if piece["alive"] and not piece["in_reserve"] and piece["side"] == invader_side \
		and MatchState.is_in_base(Canonical.coordinate(piece["position"]), wall_side):
			piece_ids.append(piece["id"])
	piece_ids.sort()
	if not piece_ids.is_empty():
		return_pieces_to_base(state, invader_side, piece_ids, "wall_repair_withdrawal")


static func _publish_player_event(state: Dictionary, actor_side: String, action_index: int, outcome: Dictionary) -> void:
	var event: Dictionary = {
		"schema_version": "player-event-v1",
		"id": "player-event-%d-%s" % [action_index, actor_side],
		"event_type": outcome["result_code"],
		"actor_side": actor_side,
		"position": outcome.get("position", []).duplicate(),
		"public_code": outcome["result_code"],
	}
	state["player_events"][actor_side].append(event)


static func _set_terminal(state: Dictionary, winner: String, reason: String) -> void:
	state["terminal"] = true
	state["winner"] = winner
	state["win_reason"] = reason


static func _advance_turn(state: Dictionary, actor_side: String) -> void:
	state["action_index"] = int(state["action_index"]) + 1
	if actor_side == MatchState.BLACK:
		state["full_round_index"] = int(state["full_round_index"]) + 1
	state["active_side"] = MatchState.opponent(actor_side)


static func _normalized_intent(intent: Dictionary) -> Dictionary:
	var target := Canonical.coordinate(intent.get("target_cell", []))
	return {
		"piece_id": str(intent.get("piece_id", "")),
		"action_type": str(intent.get("action_type", "")),
		"target_cell": [target.x, target.y] if MatchState.is_inside_board(target) else [],
		"skill_type": str(intent.get("skill_type", "")),
	}


static func _orthogonal_path(origin: Vector2i, target: Vector2i) -> Array:
	if origin == target or (origin.x != target.x and origin.y != target.y):
		return []
	var direction := Vector2i(signi(target.x - origin.x), signi(target.y - origin.y))
	var path: Array = []
	var cursor: Vector2i = origin + direction
	while cursor != target + direction:
		path.append(cursor)
		cursor += direction
	return path


static func _update_reserve_indexes(state: Dictionary, side: String) -> void:
	for index: int in state["reserve_queues"][side].size():
		state["pieces"][state["reserve_queues"][side][index]]["reserve_queue_index"] = index


static func _rejected(category: String, code: String) -> Dictionary:
	return {
		"ok": false,
		"consumed": false,
		"error": {"category": category, "code": code, "fields": []},
	}
