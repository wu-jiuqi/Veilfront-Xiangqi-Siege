extends RefCounted


static func create_state(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return {
		"seed": seed_value,
		"state": rng.state,
		"draw_index": 0,
		"records": [],
	}


static func draw_range(random_state: Dictionary, minimum: int, maximum: int, reason: String) -> int:
	assert(minimum <= maximum)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(random_state["seed"])
	rng.state = int(random_state["state"])
	var result: int = rng.randi_range(minimum, maximum)
	var draw_index: int = int(random_state["draw_index"])
	random_state["state"] = rng.state
	random_state["draw_index"] = draw_index + 1
	random_state["records"].append({
		"schema_version": "random-sample-v1",
		"draw_index": draw_index,
		"reason": reason,
		"range_min": minimum,
		"range_max": maximum,
		"result": result,
	})
	return result


static func draw_unique(random_state: Dictionary, candidates: Array, count: int, reason: String) -> Array:
	assert(count >= 0 and count <= candidates.size())
	var pool: Array = candidates.duplicate(true)
	var selected: Array = []
	for pick_index: int in count:
		var selected_index: int = draw_range(
			random_state,
			0,
			pool.size() - 1,
			"%s[%d]" % [reason, pick_index]
		)
		selected.append(pool.pop_at(selected_index))
	return selected

