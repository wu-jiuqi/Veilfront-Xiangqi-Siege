extends RefCounted

const BeliefModel = preload("res://scripts/prototype/ai/ai_belief_model.gd")
const VisibleStateEvaluator = preload("res://scripts/prototype/ai/ai_visible_state_evaluator.gd")


static func evaluate(
	action: Dictionary,
	player_data: Dictionary,
	memory: RefCounted,
	public_rules: RefCounted,
	config: Resource,
	ai_seed: int,
	belief_samples: Array = []
) -> Dictionary:
	var samples: Array = belief_samples if not belief_samples.is_empty() else BeliefModel.build_samples(
		player_data, memory, public_rules, ai_seed, int(config.belief_sample_count)
	)
	var sample_results: Array[Dictionary] = []
	var losses: Array[int] = []
	for sample_index: int in samples.size():
		var projected_pieces: Array = VisibleStateEvaluator.project_pieces(samples[sample_index], action)
		var responses: Array[Dictionary] = _enumerate_responses(
			projected_pieces, player_data, public_rules, config
		)
		responses.sort_custom(_response_before)
		if responses.size() > int(config.opponent_response_limit):
			responses.resize(int(config.opponent_response_limit))
		var worst: Dictionary = responses[0] if not responses.is_empty() else {
			"response_id": "none", "kind": "none", "score": 0,
		}
		var loss: int = int(worst.score)
		losses.append(loss)
		sample_results.append({
			"sample_index": sample_index,
			"response_count": responses.size(),
			"worst_response": worst.duplicate(true),
			"loss": loss,
		})
	var worst_loss: int = 0
	var total_loss: int = 0
	for loss: int in losses:
		worst_loss = maxi(worst_loss, loss)
		total_loss += loss
	var average_loss: int = total_loss / maxi(1, losses.size())
	var risk_percent: int = clampi(int(config.belief_risk_weight_percent), 0, 100)
	var aggregated_loss: int = (
		worst_loss * risk_percent + average_loss * (100 - risk_percent)
	) / 100
	return {
		"adjustment": -aggregated_loss,
		"breakdown": {
			"mode": "bounded-two-ply-belief-v1",
			"sample_count": samples.size(),
			"belief_hypotheses_enabled": int(config.belief_sample_count) > 0,
			"risk_weight_percent": risk_percent,
			"worst_loss": worst_loss,
			"average_loss": average_loss,
			"aggregated_loss": aggregated_loss,
			"samples": sample_results,
		},
	}


static func _enumerate_responses(
	pieces: Array,
	player_data: Dictionary,
	public_rules: RefCounted,
	config: Resource
) -> Array[Dictionary]:
	var responses: Array[Dictionary] = []
	var viewer_side: String = str(player_data.get("viewer_side", ""))
	var enemy_side: String = _opponent(viewer_side)
	var walls: Array = player_data.get("public_walls", [])
	var occupied: Dictionary = VisibleStateEvaluator.occupied_cells(pieces)
	for attacker: Dictionary in pieces:
		if str(attacker.get("side", "")) != enemy_side:
			continue
		for victim: Dictionary in pieces:
			if str(victim.get("side", "")) != viewer_side:
				continue
			var victim_cell := _coordinate(victim.get("position", [0, 0]))
			if not VisibleStateEvaluator.piece_attacks_cell_with_occupied(attacker, victim_cell, occupied, walls):
				continue
			var victim_type: String = str(victim.get("piece_type", ""))
			var loss: int = int(config.general_safety_penalty) \
				if victim_type == "general" else public_rules.piece_value(victim_type)
			responses.append({
				"response_id": "%s:capture:%s" % [str(attacker.id), str(victim.id)],
				"kind": "capture",
				"actor_id": str(attacker.id),
				"target_id": str(victim.id),
				"score": loss,
			})
	return responses


static func _response_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a.score) != int(b.score):
		return int(a.score) > int(b.score)
	return str(a.response_id) < str(b.response_id)


static func _coordinate(value: Variant) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))


static func _opponent(side: String) -> String:
	return "black" if side == "red" else "red"
