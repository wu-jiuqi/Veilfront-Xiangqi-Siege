extends RefCounted

const Canonical = preload("res://scripts/prototype/ai/ai_canonical.gd")
const ROOT_KEYS: Array[String] = [
	"schema_version", "board_width", "board_height", "piece_values", "action_kind_bias",
]

var _data: Dictionary = {}
var _validation_errors: Array[String] = []


func _init(public_config: Dictionary = {}) -> void:
	_validate(public_config)


func is_valid() -> bool:
	return _validation_errors.is_empty()


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func digest() -> String:
	return Canonical.digest(_data)


func piece_value(piece_type: String) -> int:
	return int(_data.get("piece_values", {}).get(piece_type, 0))


func action_bias(action_kind: String) -> int:
	return int(_data.get("action_kind_bias", {}).get(action_kind, 0))


func board_contains(coordinate: Array) -> bool:
	return coordinate[0] >= 0 and coordinate[0] < _data.board_width \
		and coordinate[1] >= 0 and coordinate[1] < _data.board_height


func _validate(public_config: Dictionary) -> void:
	_validation_errors.clear()
	_data.clear()
	if not Canonical.has_only_keys(public_config, ROOT_KEYS):
		_validation_errors.append("public rules contain an unknown field")
	if not public_config.get("schema_version") is String:
		_validation_errors.append("public rules schema_version must be String")
	for key: String in ["board_width", "board_height"]:
		if not public_config.get(key) is int or int(public_config.get(key, 0)) <= 0:
			_validation_errors.append("public rules %s must be a positive int" % key)
	for key: String in ["piece_values", "action_kind_bias"]:
		if not public_config.get(key) is Dictionary:
			_validation_errors.append("public rules %s must be Dictionary[String, int]" % key)
			continue
		for entry_key: Variant in public_config[key].keys():
			if not entry_key is String or not public_config[key][entry_key] is int:
				_validation_errors.append("public rules %s must contain String to int entries" % key)
	if _validation_errors.is_empty():
		_data = Canonical.value(public_config)
