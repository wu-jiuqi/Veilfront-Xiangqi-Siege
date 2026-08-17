extends RefCounted

const Canonical = preload("res://scripts/prototype/ai/ai_canonical.gd")

const ROOT_KEYS: Array[String] = [
	"schema_version", "decision_id", "viewer_side", "turn_index",
	"visible_cells", "visible_pieces", "public_flags", "public_walls", "legal_actions", "public_events",
]
const PIECE_KEYS: Array[String] = ["id", "side", "piece_type", "position", "status_tags"]
const FLAG_KEYS: Array[String] = [
	"id", "position", "owner", "capturing_side", "capture_progress", "contested",
]
const WALL_KEYS: Array[String] = ["side", "status"]
const ACTION_KEYS: Array[String] = [
	"id", "kind", "actor_id", "origin", "target", "visible_captures",
	"reveal_cell_count", "flag_vicinity_reveal_count", "occupies_flag", "attacks_wall", "path_length",
]
const CAPTURE_KEYS: Array[String] = ["piece_id", "piece_type"]
const EVENT_KEYS: Array[String] = ["id", "event_type", "actor_side", "position"]

var _data: Dictionary = {}
var _validation_errors: Array[String] = []


func _init(projection: Dictionary = {}) -> void:
	_validate_and_copy(projection)


func is_valid() -> bool:
	return _validation_errors.is_empty()


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func to_canonical_data() -> Dictionary:
	return _data.duplicate(true)


func get_legal_actions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action: Dictionary in _data.get("legal_actions", []):
		result.append(action.duplicate(true))
	return result


func input_summary() -> Dictionary:
	return {
		"schema_version": _data.get("schema_version", ""),
		"decision_id": _data.get("decision_id", ""),
		"viewer_side": _data.get("viewer_side", ""),
		"turn_index": _data.get("turn_index", -1),
		"visible_piece_count": _data.get("visible_pieces", []).size(),
		"public_flag_count": _data.get("public_flags", []).size(),
		"public_event_count": _data.get("public_events", []).size(),
		"legal_action_count": _data.get("legal_actions", []).size(),
		"projection_digest": Canonical.digest(_data),
	}


func _validate_and_copy(projection: Dictionary) -> void:
	_data.clear()
	_validation_errors.clear()
	if not Canonical.has_only_keys(projection, ROOT_KEYS):
		_validation_errors.append("PlayerView contains a non-public or unknown root field")
	_validate_scalar(projection, "schema_version", TYPE_STRING)
	_validate_scalar(projection, "decision_id", TYPE_STRING)
	_validate_scalar(projection, "viewer_side", TYPE_STRING)
	_validate_scalar(projection, "turn_index", TYPE_INT)
	if projection.has("visible_cells"):
		_validate_coordinate_array(projection, "visible_cells")
	_validate_record_array(projection, "visible_pieces", PIECE_KEYS, "id", Callable(self, "_validate_piece"))
	_validate_record_array(projection, "public_flags", FLAG_KEYS, "id", Callable(self, "_validate_flag"))
	_validate_record_array(projection, "public_walls", WALL_KEYS, "side", Callable(self, "_validate_wall"))
	_validate_record_array(projection, "legal_actions", ACTION_KEYS, "id", Callable(self, "_validate_action"))
	_validate_record_array(projection, "public_events", EVENT_KEYS, "id", Callable(self, "_validate_event"))
	if _validation_errors.is_empty():
		_data = Canonical.value(projection)
		_normalize_order()


func _validate_scalar(data: Dictionary, key: String, expected_type: int) -> void:
	if not data.has(key) or typeof(data[key]) != expected_type:
		_validation_errors.append("PlayerView.%s has the wrong type or is missing" % key)


func _validate_record_array(
	data: Dictionary,
	key: String,
	allowed_keys: Array[String],
	sort_key: String,
	validator: Callable
) -> void:
	if not data.has(key) or not data[key] is Array:
		_validation_errors.append("PlayerView.%s must be an Array" % key)
		return
	for record_value: Variant in data[key]:
		if not record_value is Dictionary:
			_validation_errors.append("PlayerView.%s contains a non-Dictionary record" % key)
			continue
		var record: Dictionary = record_value
		if not Canonical.has_only_keys(record, allowed_keys):
			_validation_errors.append("PlayerView.%s contains an unknown field" % key)
		if not record.has(sort_key) or not record[sort_key] is String:
			_validation_errors.append("PlayerView.%s record lacks String %s" % [key, sort_key])
		validator.call(record)


func _validate_piece(piece: Dictionary) -> void:
	_require_strings(piece, ["id", "side", "piece_type"])
	_require_coordinate(piece, "position")
	_require_string_array(piece, "status_tags")


func _validate_flag(flag: Dictionary) -> void:
	_require_strings(flag, ["id", "owner"])
	if flag.has("capturing_side") and not flag.capturing_side is String:
		_validation_errors.append("public flag capturing_side must be String")
	_require_coordinate(flag, "position")
	if not flag.has("capture_progress") or not flag.capture_progress is int:
		_validation_errors.append("public flag capture_progress must be int")
	if flag.has("contested") and not flag.contested is bool:
		_validation_errors.append("public flag contested must be bool")


func _validate_wall(wall: Dictionary) -> void:
	_require_strings(wall, ["side", "status"])


func _validate_action(action: Dictionary) -> void:
	_require_strings(action, ["id", "kind", "actor_id"])
	_require_coordinate(action, "origin")
	_require_coordinate(action, "target")
	for key: String in ["reveal_cell_count", "path_length"]:
		if not action.has(key) or not action[key] is int:
			_validation_errors.append("legal action %s must be int" % key)
	if action.has("flag_vicinity_reveal_count") \
	and not action.flag_vicinity_reveal_count is int:
		_validation_errors.append("legal action flag_vicinity_reveal_count must be int")
	for key: String in ["occupies_flag", "attacks_wall"]:
		if not action.has(key) or not action[key] is bool:
			_validation_errors.append("legal action %s must be bool" % key)
	if not action.has("visible_captures") or not action.visible_captures is Array:
		_validation_errors.append("legal action visible_captures must be Array")
		return
	for capture_value: Variant in action.visible_captures:
		if not capture_value is Dictionary:
			_validation_errors.append("visible capture must be Dictionary")
			continue
		var capture: Dictionary = capture_value
		if not Canonical.has_only_keys(capture, CAPTURE_KEYS):
			_validation_errors.append("visible capture contains an unknown field")
		_require_strings(capture, ["piece_id", "piece_type"])


func _validate_event(event: Dictionary) -> void:
	_require_strings(event, ["id", "event_type", "actor_side"])
	_require_coordinate(event, "position")


func _require_strings(record: Dictionary, keys: Array[String]) -> void:
	for key: String in keys:
		if not record.has(key) or not record[key] is String:
			_validation_errors.append("public record %s must be String" % key)


func _require_coordinate(record: Dictionary, key: String) -> void:
	if not record.has(key) or not Canonical.is_coordinate(record[key]):
		_validation_errors.append("public record %s must be [int, int]" % key)


func _require_string_array(record: Dictionary, key: String) -> void:
	if not record.has(key) or not record[key] is Array:
		_validation_errors.append("public record %s must be Array[String]" % key)
		return
	for item: Variant in record[key]:
		if not item is String:
			_validation_errors.append("public record %s must contain only String" % key)


func _validate_coordinate_array(data: Dictionary, key: String) -> void:
	if not data.get(key) is Array:
		_validation_errors.append("PlayerView.%s must be Array[[int, int]]" % key)
		return
	for coordinate: Variant in data[key]:
		if not Canonical.is_coordinate(coordinate):
			_validation_errors.append("PlayerView.%s contains an invalid coordinate" % key)


func _normalize_order() -> void:
	if _data.has("visible_cells"):
		_data.visible_cells.sort_custom(
			func(a: Array, b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0])
		)
	for key: String in ["visible_pieces", "public_flags", "legal_actions", "public_events"]:
		_data[key].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	_data.public_walls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.side < b.side)
	for piece: Dictionary in _data.visible_pieces:
		piece.status_tags.sort()
	for action: Dictionary in _data.legal_actions:
		action.visible_captures.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool: return a.piece_id < b.piece_id
		)
