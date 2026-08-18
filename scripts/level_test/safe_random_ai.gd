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
	var safe: Array = []
	var unsafe_action_ids: Array[String] = []
	for action: Dictionary in projection.get("legal_actions", []):
		if str(action.get("kind", "")) != "move":
			continue
		var target: Array = action.get("target", [])
		if target.size() != 2 or int(target[1]) < 0 \
		or int(target[1]) > PLAYABLE_MAX_ZERO_BASED_Y:
			continue
		movable.append(action)
		var safety: Dictionary = VisibleTacticalEvaluator.evaluate(
			action,
			projection,
			public_rules,
			safety_profile
		)
		var attackers: int = int(safety.get("breakdown", {}).get("visible_attackers", 0))
		if attackers == 0:
			safe.append(action)
		else:
			unsafe_action_ids.append(str(action.get("id", "")))

	var candidate_pool: Array = safe if not safe.is_empty() else movable
	if candidate_pool.is_empty():
		for action: Dictionary in projection.get("legal_actions", []):
			if str(action.get("kind", "")) == "pass":
				return {
					"ok": true,
					"action": action.duplicate(true),
					"audit": _audit(movable, safe, unsafe_action_ids, true),
				}
		return {"ok": false, "error": "no_legal_action"}

	var selected_index: int = SeededRandom.draw_range(
		policy_rng,
		0,
		candidate_pool.size() - 1,
		"level_safe_random_action"
	)
	return {
		"ok": true,
		"action": candidate_pool[selected_index].duplicate(true),
		"audit": _audit(movable, safe, unsafe_action_ids, false),
	}


static func _audit(
	movable: Array,
	safe: Array,
	unsafe_action_ids: Array[String],
	used_pass: bool
) -> Dictionary:
	unsafe_action_ids.sort()
	return {
		"schema_version": "level-safe-random-ai-audit-v1",
		"visible_move_count": movable.size(),
		"safe_move_count": safe.size(),
		"unsafe_move_count": unsafe_action_ids.size(),
		"unsafe_action_ids": unsafe_action_ids,
		"safe_pool_preferred": not safe.is_empty(),
		"used_pass": used_pass,
	}
