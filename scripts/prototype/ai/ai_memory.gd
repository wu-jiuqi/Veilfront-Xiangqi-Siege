extends RefCounted

const Canonical = preload("res://scripts/prototype/ai/ai_canonical.gd")
const ROOT_KEYS: Array[String] = [
	"schema_version", "recent_action_ids", "action_visit_counts", "actor_visit_counts",
	"last_visible_piece_turns", "enemy_piece_observations", "known_captured_enemy_ids",
]
const OBSERVATION_KEYS: Array[String] = ["piece_type", "position", "turn_index"]

var _data: Dictionary = {}
var _validation_errors: Array[String] = []


func _init(memory_data: Dictionary = {}) -> void:
	_validate(memory_data)


func is_valid() -> bool:
	return _validation_errors.is_empty()


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func digest() -> String:
	return Canonical.digest(_data)


func entry_count() -> int:
	return _data.get("recent_action_ids", []).size() \
		+ _data.get("action_visit_counts", {}).size() \
		+ _data.get("actor_visit_counts", {}).size() \
		+ _data.get("last_visible_piece_turns", {}).size() \
		+ _data.get("enemy_piece_observations", {}).size() \
		+ _data.get("known_captured_enemy_ids", []).size()


func action_visit_count(action_id: String) -> int:
	return int(_data.get("action_visit_counts", {}).get(action_id, 0))


func actor_visit_count(actor_id: String) -> int:
	return int(_data.get("actor_visit_counts", {}).get(actor_id, 0))


func enemy_piece_observations() -> Dictionary:
	return _data.get("enemy_piece_observations", {}).duplicate(true)


func known_captured_enemy_ids() -> Array[String]:
	var result: Array[String] = []
	for piece_id: Variant in _data.get("known_captured_enemy_ids", []):
		result.append(str(piece_id))
	return result


func _validate(memory_data: Dictionary) -> void:
	_validation_errors.clear()
	_data.clear()
	if not Canonical.has_only_keys(memory_data, ROOT_KEYS):
		_validation_errors.append("AI memory contains an unknown field")
	if not memory_data.get("schema_version") is String:
		_validation_errors.append("AI memory schema_version must be String")
	if not memory_data.get("recent_action_ids") is Array:
		_validation_errors.append("AI memory recent_action_ids must be Array[String]")
	else:
		for action_id: Variant in memory_data.recent_action_ids:
			if not action_id is String:
				_validation_errors.append("AI memory recent_action_ids must contain only String")
	for key: String in ["action_visit_counts", "actor_visit_counts", "last_visible_piece_turns"]:
		if not memory_data.get(key) is Dictionary:
			_validation_errors.append("AI memory %s must be Dictionary[String, int]" % key)
			continue
		for entry_key: Variant in memory_data[key].keys():
			if not entry_key is String or not memory_data[key][entry_key] is int:
				_validation_errors.append("AI memory %s must contain String to int entries" % key)
	if memory_data.has("enemy_piece_observations"):
		_validate_observations(memory_data.enemy_piece_observations)
	if memory_data.has("known_captured_enemy_ids"):
		if not memory_data.known_captured_enemy_ids is Array:
			_validation_errors.append("AI memory known_captured_enemy_ids must be Array[String]")
		else:
			for piece_id: Variant in memory_data.known_captured_enemy_ids:
				if not piece_id is String:
					_validation_errors.append("AI memory known_captured_enemy_ids must contain String")
	if _validation_errors.is_empty():
		_data = Canonical.value(memory_data)
		_data.recent_action_ids.sort()
		if _data.has("known_captured_enemy_ids"):
			_data.known_captured_enemy_ids.sort()


func _validate_observations(observations: Variant) -> void:
	if not observations is Dictionary:
		_validation_errors.append("AI memory enemy_piece_observations must be Dictionary")
		return
	for piece_id: Variant in observations.keys():
		var record: Variant = observations[piece_id]
		if not piece_id is String or not record is Dictionary:
			_validation_errors.append("AI memory observation must map String to Dictionary")
			continue
		if not Canonical.has_only_keys(record, OBSERVATION_KEYS):
			_validation_errors.append("AI memory observation contains an unknown field")
		if not record.get("piece_type") is String \
		or not Canonical.is_coordinate(record.get("position")) \
		or not record.get("turn_index") is int:
			_validation_errors.append("AI memory observation has invalid fields")
