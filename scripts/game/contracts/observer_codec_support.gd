class_name ObserverCodecSupport
extends RefCounted

const ERROR_INVALID_PAYLOAD: String = "invalid_payload"
const ERROR_NON_CANONICAL: String = "non_canonical_json"
const ERROR_UNSUPPORTED_SCHEMA: String = "unsupported_schema_version"
const MAX_SAFE_JSON_INTEGER: float = 9007199254740991.0


static func decode_canonical(
	encoded: String,
	schema_version: String,
	root_fields: Array[String]
) -> Dictionary:
	if encoded.is_empty() or encoded.begins_with("\ufeff"):
		return failure(ERROR_INVALID_PAYLOAD)
	var parser: JSON = JSON.new()
	if parser.parse(encoded) != OK or not parser.data is Dictionary:
		return failure(ERROR_INVALID_PAYLOAD)
	var value: Dictionary = _normalize_numbers(parser.data)
	if str(value.get("schema_version", "")) != schema_version:
		return failure(ERROR_UNSUPPORTED_SCHEMA)
	if not has_exact_fields(value, root_fields):
		return failure(ERROR_INVALID_PAYLOAD)
	if not is_json_value(value):
		return failure(ERROR_INVALID_PAYLOAD)
	var canonical: String = JSON.stringify(value, "", true, true)
	if canonical != encoded:
		return failure(ERROR_NON_CANONICAL)
	return success(value.duplicate(true), canonical)


static func encode_canonical(
	value: Dictionary,
	schema_version: String,
	root_fields: Array[String]
) -> Dictionary:
	if str(value.get("schema_version", "")) != schema_version:
		return failure(ERROR_UNSUPPORTED_SCHEMA)
	if not has_exact_fields(value, root_fields) or not is_json_value(value):
		return failure(ERROR_INVALID_PAYLOAD)
	var isolated: Dictionary = value.duplicate(true)
	var canonical: String = JSON.stringify(isolated, "", true, true)
	return success(isolated, canonical)


static func digest_bytes(canonical: String) -> String:
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(canonical.to_utf8_buffer())
	return context.finish().hex_encode()


static func has_exact_fields(
	value: Dictionary,
	required_fields: Array[String],
	optional_fields: Array[String] = []
) -> bool:
	if value.size() < required_fields.size() \
	or value.size() > required_fields.size() + optional_fields.size():
		return false
	for field_name: String in required_fields:
		if not value.has(field_name):
			return false
	for key_value: Variant in value.keys():
		if not key_value is String:
			return false
		var key: String = key_value
		if not required_fields.has(key) and not optional_fields.has(key):
			return false
	return true


static func is_json_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_ARRAY:
			for item: Variant in value:
				if not is_json_value(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key_value: Variant in value.keys():
				if not key_value is String or not is_json_value(value[key_value]):
					return false
			return true
		_:
			return false


static func _normalize_numbers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number: float = float(value)
			if is_finite(number) and number == floor(number) \
			and absf(number) <= MAX_SAFE_JSON_INTEGER:
				return int(number)
			return number
		TYPE_ARRAY:
			var normalized_array: Array = []
			for item: Variant in value:
				normalized_array.append(_normalize_numbers(item))
			return normalized_array
		TYPE_DICTIONARY:
			var normalized_dictionary: Dictionary = {}
			for key_value: Variant in value.keys():
				normalized_dictionary[key_value] = _normalize_numbers(value[key_value])
			return normalized_dictionary
		_:
			return value


static func is_integer(value: Variant, minimum: int = -2147483648) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= minimum


static func is_string(value: Variant, allow_empty: bool = true) -> bool:
	return value is String and (allow_empty or not str(value).is_empty())


static func is_side(value: Variant, allow_empty: bool = false) -> bool:
	if not value is String:
		return false
	return str(value) in (["", "red", "black"] if allow_empty else ["red", "black"])


static func is_coordinate(value: Variant, allow_empty: bool = false) -> bool:
	if not value is Array:
		return false
	var coordinate: Array = value
	if allow_empty and coordinate.is_empty():
		return true
	return coordinate.size() == 2 \
		and typeof(coordinate[0]) == TYPE_INT \
		and typeof(coordinate[1]) == TYPE_INT \
		and int(coordinate[0]) >= 1 and int(coordinate[0]) <= 9 \
		and int(coordinate[1]) >= 1 and int(coordinate[1]) <= 24


static func is_coordinate_array(value: Variant) -> bool:
	if not value is Array:
		return false
	var previous_y: int = 0
	var previous_x: int = 0
	var first: bool = true
	for item: Variant in value:
		if not is_coordinate(item):
			return false
		var coordinate: Array = item
		var x: int = int(coordinate[0])
		var y: int = int(coordinate[1])
		if not first and (y < previous_y or (y == previous_y and x <= previous_x)):
			return false
		first = false
		previous_x = x
		previous_y = y
	return true


static func is_string_array(value: Variant) -> bool:
	if not value is Array:
		return false
	for item: Variant in value:
		if not item is String:
			return false
	return true


static func success(value: Dictionary, canonical: String) -> Dictionary:
	return {
		"ok": true,
		"value": value,
		"bytes": canonical,
		"digest": digest_bytes(canonical),
		"error_code": "",
	}


static func failure(error_code: String) -> Dictionary:
	return {
		"ok": false,
		"value": {},
		"bytes": "",
		"digest": "",
		"error_code": error_code,
	}
