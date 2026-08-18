extends RefCounted

const SeededRandom = preload("res://scripts/prototype/core/seeded_random.gd")
const VisibleTacticalEvaluator = preload("res://scripts/prototype/ai/ai_visible_tactical_evaluator.gd")

const PLAYABLE_MAX_ZERO_BASED_Y: int = 15


static func choose(
	projection: Dictionary,
	policy_rng: Dictionary,
	public_rules: RefCounted,
	safety_profile: Resource
) -> Dictionary:
	var movable: Array = []
	var action_attackers: Dictionary = {}
	var safe_move_count: int = 0
	var unsafe_action_ids: Array[String] = []
	var movable_actor_ids: Dictionary = {}
	for action: Dictionary in projection.get("legal_actions", []):
		if str(action.get("kind", "")) != "move":
			continue
		var target: Array = action.get("target", [])
		if target.size() != 2 or int(target[1]) < 0 \
		or int(target[1]) > PLAYABLE_MAX_ZERO_BASED_Y:
			continue
		movable.append(action)
		movable_actor_ids[str(action.get("actor_id", ""))] = true
		var attackers: int = _visible_attacker_count(
			action, projection, public_rules, safety_profile
		)
		action_attackers[str(action.get("id", ""))] = attackers
		if attackers == 0:
			safe_move_count += 1
		else:
			unsafe_action_ids.append(str(action.get("id", "")))

	var threatened_piece_ids: Array[String] = _threatened_piece_ids(
		projection, public_rules, safety_profile
	)
	var movable_threatened_piece_ids: Array[String] = []
	for piece_id: String in threatened_piece_ids:
		if movable_actor_ids.has(piece_id):
			movable_threatened_piece_ids.append(piece_id)

	var selected_threatened_piece_id: String = ""
	var eligible: Array = movable
	if not movable_threatened_piece_ids.is_empty():
		selected_threatened_piece_id = _choose_random_string(
			movable_threatened_piece_ids,
			policy_rng,
			"level_threatened_actor"
		)
		eligible = []
		for action: Dictionary in movable:
			if str(action.get("actor_id", "")) == selected_threatened_piece_id:
				eligible.append(action)

	var safe_captures: Array = []
	var safe_non_captures: Array = []
	var unsafe_eligible: Array = []
	for action: Dictionary in eligible:
		var attackers: int = int(action_attackers.get(str(action.get("id", "")), 0))
		if attackers > 0:
			unsafe_eligible.append(action)
		elif not action.get("visible_captures", []).is_empty():
			safe_captures.append(action)
		else:
			safe_non_captures.append(action)

	var candidate_pool: Array = []
	var selected_priority_tier: String = ""
	var random_label: String = ""
	if not safe_captures.is_empty():
		candidate_pool = safe_captures
		selected_priority_tier = "safe_capture"
		random_label = "level_safe_capture_action"
	elif not safe_non_captures.is_empty():
		candidate_pool = safe_non_captures
		selected_priority_tier = "safe_non_capture"
		random_label = "level_safe_non_capture_action"
	else:
		candidate_pool = unsafe_eligible
		selected_priority_tier = "unsafe_fallback"
		random_label = "level_unsafe_fallback_action"

	if candidate_pool.is_empty():
		for action: Dictionary in projection.get("legal_actions", []):
			if str(action.get("kind", "")) == "pass":
				return {
					"ok": true,
					"action": action.duplicate(true),
					"audit": _audit(
						movable,
						safe_move_count,
						unsafe_action_ids,
						threatened_piece_ids,
						movable_threatened_piece_ids,
						selected_threatened_piece_id,
						safe_captures,
						safe_non_captures,
						unsafe_eligible,
						"pass",
						true
					),
				}
		return {"ok": false, "error": "no_legal_action"}

	var selected_index: int = 0
	if candidate_pool.size() > 1:
		selected_index = SeededRandom.draw_range(
			policy_rng,
			0,
			candidate_pool.size() - 1,
			random_label
		)
	return {
		"ok": true,
		"action": candidate_pool[selected_index].duplicate(true),
		"audit": _audit(
			movable,
			safe_move_count,
			unsafe_action_ids,
			threatened_piece_ids,
			movable_threatened_piece_ids,
			selected_threatened_piece_id,
			safe_captures,
			safe_non_captures,
			unsafe_eligible,
			selected_priority_tier,
			false
		),
	}


static func _audit(
	movable: Array,
	safe_move_count: int,
	unsafe_action_ids: Array[String],
	threatened_piece_ids: Array[String],
	movable_threatened_piece_ids: Array[String],
	selected_threatened_piece_id: String,
	safe_captures: Array,
	safe_non_captures: Array,
	unsafe_eligible: Array,
	selected_priority_tier: String,
	used_pass: bool
) -> Dictionary:
	unsafe_action_ids.sort()
	return {
		"schema_version": "level-threat-safe-random-ai-audit-v2",
		"visible_move_count": movable.size(),
		"safe_move_count": safe_move_count,
		"unsafe_move_count": unsafe_action_ids.size(),
		"unsafe_action_ids": unsafe_action_ids,
		"threatened_piece_ids": threatened_piece_ids,
		"movable_threatened_piece_ids": movable_threatened_piece_ids,
		"selected_threatened_piece_id": selected_threatened_piece_id,
		"threat_priority_applied": not selected_threatened_piece_id.is_empty(),
		"eligible_move_count": safe_captures.size() + safe_non_captures.size() \
			+ unsafe_eligible.size(),
		"safe_capture_count": safe_captures.size(),
		"safe_non_capture_count": safe_non_captures.size(),
		"unsafe_eligible_count": unsafe_eligible.size(),
		"safe_pool_preferred": not safe_captures.is_empty() \
			or not safe_non_captures.is_empty(),
		"selected_priority_tier": selected_priority_tier,
		"uses_visible_information_only": true,
		"used_pass": used_pass,
	}


static func _threatened_piece_ids(
	projection: Dictionary,
	public_rules: RefCounted,
	safety_profile: Resource
) -> Array[String]:
	var result: Array[String] = []
	var viewer_side: String = str(projection.get("viewer_side", ""))
	for piece: Dictionary in projection.get("visible_pieces", []):
		if str(piece.get("side", "")) != viewer_side:
			continue
		var position: Array = piece.get("position", [])
		if position.size() != 2:
			continue
		var piece_id: String = str(piece.get("id", ""))
		var stay_action: Dictionary = {
			"id": "threat-check:%s" % piece_id,
			"kind": "move",
			"actor_id": piece_id,
			"origin": position.duplicate(),
			"target": position.duplicate(),
			"visible_captures": [],
		}
		if _visible_attacker_count(
			stay_action, projection, public_rules, safety_profile
		) > 0:
			result.append(piece_id)
	result.sort()
	return result


static func _visible_attacker_count(
	action: Dictionary,
	projection: Dictionary,
	public_rules: RefCounted,
	safety_profile: Resource
) -> int:
	var tactical_result: Dictionary = VisibleTacticalEvaluator.evaluate(
		action,
		projection,
		public_rules,
		safety_profile
	)
	return int(tactical_result.get("breakdown", {}).get("visible_attackers", 0))


static func _choose_random_string(
	values: Array[String],
	policy_rng: Dictionary,
	label: String
) -> String:
	if values.size() == 1:
		return values[0]
	var selected_index: int = SeededRandom.draw_range(
		policy_rng,
		0,
		values.size() - 1,
		label
	)
	return values[selected_index]
