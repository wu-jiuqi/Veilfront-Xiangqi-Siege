extends RefCounted

const MAX_SAFE_JSON_INTEGER: float = 9007199254740991.0
const INT64_TAG: String = "__veilfront_i64__:"


static func value(input: Variant) -> Variant:
	match typeof(input):
		TYPE_DICTIONARY:
			var source: Dictionary = input
			var keys: Array = source.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var output: Dictionary = {}
			for key: Variant in keys:
				output[str(key)] = value(source[key])
			return output
		TYPE_ARRAY:
			var output: Array = []
			for item: Variant in input:
				output.append(value(item))
			return output
		TYPE_VECTOR2I:
			var coordinate: Vector2i = input
			return [coordinate.x, coordinate.y]
		_:
			return input


static func json(input: Variant) -> String:
	return JSON.stringify(value(input))


static func digest(input: Variant) -> String:
	return json(input).sha256_text()


static func parse(encoded: String) -> Dictionary:
	var parser: JSON = JSON.new()
	if encoded.is_empty() or encoded.begins_with("\ufeff") or parser.parse(encoded) != OK:
		return {"ok": false, "value": null}
	return {"ok": true, "value": normalize_json_numbers(parser.data)}


static func parse_lossless(encoded: String) -> Dictionary:
	var parsed: Dictionary = parse(_protect_unsafe_json_integers(encoded))
	if not bool(parsed.get("ok", false)):
		return parsed
	parsed["value"] = from_lossless_json_value(parsed.get("value"))
	return parsed


static func normalize_json_numbers(input: Variant) -> Variant:
	match typeof(input):
		TYPE_FLOAT:
			var number: float = float(input)
			if is_finite(number) and number == floor(number) \
			and absf(number) <= MAX_SAFE_JSON_INTEGER:
				return int(number)
			return number
		TYPE_ARRAY:
			var output: Array = []
			for item: Variant in input:
				output.append(normalize_json_numbers(item))
			return output
		TYPE_DICTIONARY:
			var output: Dictionary = {}
			for key_value: Variant in input.keys():
				output[key_value] = normalize_json_numbers(input[key_value])
			return output
		_:
			return input


static func from_lossless_json_value(input: Variant) -> Variant:
	match typeof(input):
		TYPE_STRING:
			var text: String = str(input)
			if text.begins_with(INT64_TAG):
				var integer_text: String = text.trim_prefix(INT64_TAG)
				if integer_text.is_valid_int():
					return int(integer_text)
			return text
		TYPE_ARRAY:
			var output: Array = []
			for item: Variant in input:
				output.append(from_lossless_json_value(item))
			return output
		TYPE_DICTIONARY:
			var output: Dictionary = {}
			for key_value: Variant in input.keys():
				output[key_value] = from_lossless_json_value(input[key_value])
			return output
		_:
			return input


static func _protect_unsafe_json_integers(encoded: String) -> String:
	var output: PackedStringArray = []
	var index: int = 0
	var in_string: bool = false
	var escaped: bool = false
	while index < encoded.length():
		var character: String = encoded[index]
		if in_string:
			output.append(character)
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == "\"":
				in_string = false
			index += 1
			continue
		if character == "\"":
			in_string = true
			output.append(character)
			index += 1
			continue
		var starts_number: bool = character >= "0" and character <= "9"
		if character == "-" and index + 1 < encoded.length():
			var next_character: String = encoded[index + 1]
			starts_number = next_character >= "0" and next_character <= "9"
		if not starts_number:
			output.append(character)
			index += 1
			continue
		var end_index: int = index + 1
		while end_index < encoded.length():
			var number_character: String = encoded[end_index]
			if not (
				(number_character >= "0" and number_character <= "9") \
				or number_character in [".", "e", "E", "+", "-"]
			):
				break
			end_index += 1
		var token: String = encoded.substr(index, end_index - index)
		if token.is_valid_int():
			var integer: int = int(token)
			if integer > int(MAX_SAFE_JSON_INTEGER) or integer < -int(MAX_SAFE_JSON_INTEGER):
				output.append("\"%s%s\"" % [INT64_TAG, token])
				index = end_index
				continue
		output.append(token)
		index = end_index
	return "".join(output)


static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func coordinate(value_to_convert: Variant) -> Vector2i:
	if value_to_convert is Vector2i:
		return value_to_convert
	if value_to_convert is Array and value_to_convert.size() == 2:
		return Vector2i(int(value_to_convert[0]), int(value_to_convert[1]))
	return Vector2i(-1, -1)
