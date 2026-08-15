extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const MoveRules = preload("res://scripts/prototype/core/move_rules.gd")
const SeededRandom = preload("res://scripts/prototype/core/seeded_random.gd")
const PlayerViewProjector = preload("res://scripts/prototype/view/player_view_projector.gd")


static func create_match(seed_value: int, configuration: Dictionary = {}) -> Dictionary:
	return MatchState.create(seed_value, configuration)


static func list_legal_actions(state: Dictionary, side: String = "") -> Array:
	var actor_side: String = str(state["active_side"]) if side.is_empty() else side
	return MoveRules.generate_legal_actions(
		state, actor_side, PlayerViewProjector.visibility_context(state, actor_side)
	)


static func prepare_action(state: Dictionary) -> Dictionary:
	if state["terminal"]:
		return _rejected("terminal", "match_already_terminal")
	var existing: Dictionary = state.get("prepared_action", {})
	if not existing.is_empty() and int(existing["action_index"]) == int(state["action_index"]) \
	and str(existing["actor_side"]) == str(state["active_side"]):
		return {"ok": true, "preparation": existing.duplicate(true)}
	var random_record_start: int = state["rng"]["records"].size()
	var deployments: Array = begin_action(state)
	var preparation: Dictionary = {
		"schema_version": "prepared-action-v1",
		"token": "prepared-%d-%s" % [state["action_index"], state["active_side"]],
		"action_index": state["action_index"],
		"actor_side": state["active_side"],
		"deployments": deployments.duplicate(true),
		"random_samples": state["rng"]["records"].slice(random_record_start).duplicate(true),
	}
	state["prepared_action"] = preparation
	return {"ok": true, "preparation": preparation.duplicate(true)}


static func submit_action(state: Dictionary, intent: Dictionary, options: Dictionary = {}) -> Dictionary:
	if state["terminal"]:
		return _rejected("terminal", "match_already_terminal")
	var actor_side: String = state["active_side"]
	var action_index: int = state["action_index"]
	var prepared_result: Dictionary = prepare_action(state)
	if not prepared_result.get("ok", false):
		return prepared_result
	var preparation: Dictionary = prepared_result["preparation"]
	var provided_token: String = str(options.get("preparation_token", ""))
	if not provided_token.is_empty() and provided_token != str(preparation["token"]):
		return _rejected("known_illegal", "stale_or_invalid_preparation_token")
	var deployments: Array = preparation["deployments"].duplicate(true)
	var random_record_start: int = state["rng"]["records"].size()
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
			outcome = _resolve_move(
				state, intent, actor_side, bool(options.get("trusted_generated_action", false))
			)
		"bombard":
			outcome = _resolve_bombardment(state, intent, actor_side)
		_:
			outcome = _rejected("known_illegal", "unsupported_action_type")
	if not outcome.get("consumed", false):
		return outcome
	state.erase("prepared_action")

	if not state["terminal"]:
		_update_walls_after_action(state, actor_side)
	if not state["terminal"]:
		_update_flags_after_action(state, actor_side)
	_complete_action_clock(state, actor_side)
	_publish_player_event(state, actor_side, action_index, outcome)

	var event: Dictionary = {
		"schema_version": "action-event-v1",
		"event_id": "action-%d" % action_index,
		"action_index": action_index,
		"actor_side": actor_side,
		"intent": _normalized_intent(intent),
		"deployments_before_action": deployments,
		"outcome": outcome.duplicate(true),
		"random_samples": preparation.get("random_samples", []).duplicate(true) \
			+ state["rng"]["records"].slice(random_record_start).duplicate(true),
	}
	state["events"].append(event)
	var response: Dictionary = {
		"ok": true,
		"consumed": true,
		"event": event.duplicate(true),
	}
	if bool(options.get("include_state_summary", true)):
		response["state_summary"] = MatchState.summary(state)
	return response


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
		_clear_piece_transient_sources(state, piece_id)
		MatchState.remove_piece_from_board(state, piece_id)
		var piece: Dictionary = state["pieces"][piece_id]
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
	var general_targets: Array = []
	for target: Dictionary in snapshot_targets:
		if target["piece_type"] == "general":
			general_targets.append(target)

	# Frozen bombardment ordering: a snapshot hit on either general ends the
	# simultaneous window before any non-general casualty or side effect.
	var resolved_targets: Array = general_targets if not general_targets.is_empty() else snapshot_targets
	for target: Dictionary in resolved_targets:
		if target["piece_id"].is_empty():
			continue
		var piece: Dictionary = state["pieces"][target["piece_id"]]
		impacted_piece_ids[piece["id"]] = true
		_cancel_flag_capture_for_piece(state, piece["id"])
		_clear_piece_transient_sources(state, piece["id"])
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
	if general_targets.is_empty():
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
			_clear_piece_transient_sources(state, advisor_id)
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


static func _resolve_move(
	state: Dictionary,
	intent: Dictionary,
	actor_side: String,
	trusted_generated_action: bool = false
) -> Dictionary:
	var visibility_context: Dictionary = PlayerViewProjector.visibility_context(state, actor_side)
	if not trusted_generated_action:
		var player_view: Dictionary = PlayerViewProjector.project(state, actor_side)
		var preview: Dictionary = PlayerViewProjector.preview_intent(player_view, intent)
		if preview["classification"] == PlayerViewProjector.KNOWN_ILLEGAL:
			return _rejected("known_illegal", "visible_rule_rejection")
	var piece_id: String = str(intent.get("piece_id", ""))
	if not state["pieces"].has(piece_id):
		return _rejected("known_illegal", "unknown_piece")
	var piece: Dictionary = state["pieces"][piece_id]
	var origin := Canonical.coordinate(piece["position"])
	var target := Canonical.coordinate(intent.get("target_cell", []))
	if piece["piece_type"] == "rook":
		state["vision_sources"][actor_side]["rook_paths"].erase(piece_id)
	var evaluation: Dictionary = MoveRules.evaluate_move(
		state, intent, actor_side, visibility_context
	)
	if not evaluation.get("legal", false):
		return _consumed_hidden_failure(state, actor_side, piece, origin, target, evaluation)
	_cancel_flag_capture_for_piece(state, piece_id)
	piece["revealed_to"] = []
	var casualties: Array = []
	var resolved_position: Vector2i = target
	for target_piece_id_value: Variant in evaluation["target_piece_ids"]:
		var target_piece_id: String = str(target_piece_id_value)
		if not state["pieces"].has(target_piece_id):
			continue
		var target_piece: Dictionary = state["pieces"][target_piece_id]
		if not target_piece["alive"] or target_piece["in_reserve"]:
			continue
		var casualty: Dictionary = _resolve_single_casualty(state, target_piece_id, actor_side)
		casualties.append(casualty)
		if state["terminal"]:
			break
	MatchState.relocate_piece(state, piece_id, resolved_position)
	if not state["terminal"]:
		_apply_move_vision_effects(state, piece_id, origin, target, evaluation)
	if not state["terminal"]:
		_start_flag_capture(state, piece_id)
	return {
		"ok": true,
		"consumed": true,
		"result_code": "move_resolved",
		"position": [resolved_position.x, resolved_position.y],
		"move_kind": evaluation["move_kind"],
		"path": evaluation["path"].duplicate(true),
		"casualties": casualties,
	}


static func _resolve_bombardment(state: Dictionary, intent: Dictionary, actor_side: String) -> Dictionary:
	var cannon_id: String = str(intent.get("piece_id", ""))
	var evaluation: Dictionary = MoveRules.evaluate_bombard(state, intent, actor_side)
	if not evaluation.get("legal", false):
		return _rejected("known_illegal", str(evaluation.get("reason", "bombardment_not_available")))
	var center := Canonical.coordinate(intent.get("target_cell", []))
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
			_disable_special_sources_against_wall(state, wall_side)
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
		"authorized_captures": _authorized_captures(state, outcome, actor_side, true),
	}
	state["player_events"][actor_side].append(event)
	var opponent_side: String = MatchState.opponent(actor_side)
	var public_to_opponent: bool = outcome["result_code"] in ["pass", "skip", "timeout", "bombardment_resolved"] \
		or state["terminal"]
	var position := Canonical.coordinate(outcome.get("position", []))
	if MatchState.is_inside_board(position):
		public_to_opponent = public_to_opponent or PlayerViewProjector.is_cell_visible(
			state, opponent_side, position
		)
	if public_to_opponent:
		var opponent_event: Dictionary = event.duplicate(true)
		opponent_event["authorized_captures"] = _authorized_captures(
			state, outcome, opponent_side, false
		)
		state["player_events"][opponent_side].append(opponent_event)


static func _authorized_captures(
	state: Dictionary,
	outcome: Dictionary,
	viewer_side: String,
	allow_all: bool
) -> Array:
	var casualty_records: Array = outcome.get("casualties", [])
	if outcome.get("result_code", "") == "bombardment_resolved":
		casualty_records = outcome.get("bombardment_result", {}).get("casualties", [])
	var captures: Array = []
	var seen: Dictionary = {}
	for casualty: Dictionary in casualty_records:
		var piece_id: String = str(casualty.get("piece_id", ""))
		if piece_id.is_empty() or seen.has(piece_id) or not state["pieces"].has(piece_id):
			continue
		var piece: Dictionary = state["pieces"][piece_id]
		var allowed: bool = allow_all or piece["side"] == viewer_side
		var casualty_cell := Canonical.coordinate(casualty.get("position", outcome.get("position", [])))
		if not allowed and MatchState.is_inside_board(casualty_cell):
			allowed = PlayerViewProjector.is_cell_visible(state, viewer_side, casualty_cell)
		if not allowed:
			continue
		seen[piece_id] = true
		captures.append({
			"piece_id": piece_id,
			"piece_type": str(piece["piece_type"]),
			"rescued": bool(casualty.get("rescued", false)),
		})
	return captures


static func _set_terminal(state: Dictionary, winner: String, reason: String) -> void:
	state["terminal"] = true
	state["winner"] = winner
	state["win_reason"] = reason


static func _complete_action_clock(state: Dictionary, actor_side: String) -> void:
	state["action_index"] = int(state["action_index"]) + 1
	if actor_side == MatchState.BLACK:
		state["full_round_index"] = int(state["full_round_index"]) + 1
	if not state["terminal"] and actor_side == MatchState.BLACK:
		_check_round_limit(state)
	if not state["terminal"]:
		state["active_side"] = MatchState.opponent(actor_side)


static func _normalized_intent(intent: Dictionary) -> Dictionary:
	var target := Canonical.coordinate(intent.get("target_cell", []))
	return {
		"piece_id": str(intent.get("piece_id", "")),
		"action_type": str(intent.get("action_type", "")),
		"target_cell": [target.x, target.y] if MatchState.is_inside_board(target) else [],
		"skill_type": str(intent.get("skill_type", "")),
	}


static func _update_reserve_indexes(state: Dictionary, side: String) -> void:
	for index: int in state["reserve_queues"][side].size():
		state["pieces"][state["reserve_queues"][side][index]]["reserve_queue_index"] = index


static func _rejected(category: String, code: String) -> Dictionary:
	return {
		"ok": false,
		"consumed": false,
		"error": {"category": category, "code": code, "fields": []},
	}


static func _consumed_hidden_failure(
	state: Dictionary,
	actor_side: String,
	piece: Dictionary,
	origin: Vector2i,
	target: Vector2i,
	evaluation: Dictionary
) -> Dictionary:
	var reason: String = str(evaluation.get("reason", ""))
	var result_code: String = "route_unknown_blocked"
	var contact_cell: Array = []
	if bool(evaluation.get("contact_reached_target", false)):
		result_code = "target_unknown_occupied"
		contact_cell = [target.x, target.y]
	elif reason.begins_with("cannon_"):
		result_code = "cannon_path_invalid"
	elif reason == "pawn_special_blocked" or reason == "route_blocked" \
	or reason in ["horse_leg_blocked", "elephant_eye_blocked"]:
		result_code = "route_unknown_blocked"
	else:
		result_code = "target_unknown_occupied"
		contact_cell = [target.x, target.y]
	var revealed_identity: String = ""
	# Identity is only eligible when the evaluator explicitly proves the
	# mover reached the target contact. Route/leg/eye/cannon failures must
	# never inspect the target occupant as a side channel.
	var target_piece: Dictionary = {}
	if result_code == "target_unknown_occupied" \
	and bool(evaluation.get("contact_reached_target", false)):
		target_piece = MatchState.piece_at(state, target)
	if not target_piece.is_empty() and target_piece["side"] != actor_side \
	and target_piece["piece_type"] == "horse" and target_piece["hidden"]:
		target_piece["revealed_to"] = target_piece.get("revealed_to", [])
		if not target_piece["revealed_to"].has(actor_side):
			target_piece["revealed_to"].append(actor_side)
		revealed_identity = target_piece["id"]
	state["contact_intel"][actor_side].append({
		"schema_version": "contact-intel-v1",
		"kind": result_code,
		"cell": contact_cell,
		"revealed_identity": revealed_identity,
		"created_at_action_index": state["action_index"],
		"persistent_tracking": false,
	})
	return {
		"ok": true,
		"consumed": true,
		"result_code": result_code,
		"position": [origin.x, origin.y],
	}


static func _resolve_single_casualty(
	state: Dictionary,
	piece_id: String,
	attacker_side: String
) -> Dictionary:
	var piece: Dictionary = state["pieces"][piece_id]
	var record: Dictionary = {
		"piece_id": piece_id,
		"piece_type": piece["piece_type"],
		"side": piece["side"],
		"rescued": false,
		"sacrificed_advisor_id": "",
	}
	_cancel_flag_capture_for_piece(state, piece_id)
	_clear_piece_transient_sources(state, piece_id)
	MatchState.remove_piece_from_board(state, piece_id)
	piece["alive"] = false
	if piece["piece_type"] == "general":
		_set_terminal(state, attacker_side, "general_destroyed")
		return record
	if piece["piece_type"] == "advisor":
		return record
	var side: String = piece["side"]
	if int(state["rescue_eligible_events"][side]) >= 2:
		return record
	state["rescue_eligible_events"][side] = int(state["rescue_eligible_events"][side]) + 1
	var advisors: Array = _available_rescue_advisors(state, side, {piece_id: true})
	if advisors.is_empty():
		return record
	var selected: Array = SeededRandom.draw_unique(state["rng"], advisors, 1, "advisor_rescue:%s" % piece_id)
	var advisor_id: String = str(selected[0])
	var advisor: Dictionary = state["pieces"][advisor_id]
	_cancel_flag_capture_for_piece(state, advisor_id)
	_clear_piece_transient_sources(state, advisor_id)
	MatchState.remove_piece_from_board(state, advisor_id)
	advisor["alive"] = false
	advisor["rescue_available"] = false
	piece["alive"] = true
	record["rescued"] = true
	record["sacrificed_advisor_id"] = advisor_id
	record["base_return"] = return_pieces_to_base(state, side, [piece_id], "advisor_rescue_return")
	return record


static func _apply_move_vision_effects(
	state: Dictionary,
	piece_id: String,
	origin: Vector2i,
	target: Vector2i,
	evaluation: Dictionary
) -> void:
	var piece: Dictionary = state["pieces"][piece_id]
	var side: String = piece["side"]
	var move_kind: String = str(evaluation["move_kind"])
	if piece["piece_type"] == "rook":
		state["vision_sources"][side]["rook_paths"].erase(piece_id)
		if move_kind == "rook_special":
			state["vision_sources"][side]["rook_paths"][piece_id] = evaluation["path"].duplicate(true)
	if piece["piece_type"] == "elephant":
		state["vision_sources"][side]["elephant_reveal_zones"].erase(piece_id)
		if move_kind == "elephant_special":
			state["vision_sources"][side]["elephant_reveal_zones"][piece_id] = \
				MoveRules.reveal_cells_for_elephant_move(origin, target)
	if piece["piece_type"] == "horse" and move_kind == "horse_special":
		piece["hidden"] = true


static func _disable_special_sources_against_wall(state: Dictionary, wall_side: String) -> void:
	var attacker_side: String = MatchState.opponent(wall_side)
	state["vision_sources"][attacker_side]["rook_paths"].clear()
	state["vision_sources"][attacker_side]["elephant_reveal_zones"].clear()
	for piece_value: Variant in state["pieces"].values():
		var piece: Dictionary = piece_value
		if piece["side"] == attacker_side and piece["piece_type"] == "horse":
			piece["hidden"] = false
			piece["revealed_to"] = []


static func _clear_piece_transient_sources(state: Dictionary, piece_id: String) -> void:
	if not state["pieces"].has(piece_id):
		return
	var piece: Dictionary = state["pieces"][piece_id]
	piece["hidden"] = false
	piece["revealed_to"] = []
	piece["temporary_effects"] = []
	for vision_side: String in [MatchState.RED, MatchState.BLACK]:
		state["vision_sources"][vision_side]["rook_paths"].erase(piece_id)
		state["vision_sources"][vision_side]["elephant_reveal_zones"].erase(piece_id)


static func _check_round_limit(state: Dictionary) -> void:
	var limit: int = int(state["configuration"]["full_round_limit_hypothesis"])
	if int(state["full_round_index"]) < limit:
		return
	var counts: Dictionary = {MatchState.RED: 0, MatchState.BLACK: 0}
	for flag: Dictionary in state["flags"]:
		if counts.has(flag["owner"]):
			counts[flag["owner"]] = int(counts[flag["owner"]]) + 1
	if counts[MatchState.RED] > counts[MatchState.BLACK]:
		_set_terminal(state, MatchState.RED, "round_limit_flags")
	elif counts[MatchState.BLACK] > counts[MatchState.RED]:
		_set_terminal(state, MatchState.BLACK, "round_limit_flags")
	else:
		_set_terminal(state, "draw", "round_limit_draw")


static func _cell_array_has(cells: Array, target: Vector2i) -> bool:
	for cell_value: Variant in cells:
		if Canonical.coordinate(cell_value) == target:
			return true
	return false
