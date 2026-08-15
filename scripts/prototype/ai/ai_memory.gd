extends RefCounted

const Canonical = preload("res://scripts/prototype/ai/ai_canonical.gd")
const ROOT_KEYS: Array[String] = [
	"schema_version", "recent_action_ids", "action_visit_counts", "last_visible_piece_turns",
]

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
		+ _data.get("last_visible_piece_turns", {}).size()


func action_visit_count(action_id: String) -> int:
	return int(_data.get("action_visit_counts", {}).get(action_id, 0))


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
	for key: String in ["action_visit_counts", "last_visible_piece_turns"]:
		if not memory_data.get(key) is Dictionary:
			_validation_errors.append("AI memory %s must be Dictionary[String, int]" % key)
			continue
		for entry_key: Variant in memory_data[key].keys():
			if not entry_key is String or not memory_data[key][entry_key] is int:
				_validation_errors.append("AI memory %s must contain String to int entries" % key)
	if _validation_errors.is_empty():
		_data = Canonical.value(memory_data)
		_data.recent_action_ids.sort()
