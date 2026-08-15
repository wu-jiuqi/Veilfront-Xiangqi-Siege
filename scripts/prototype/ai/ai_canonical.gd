extends RefCounted


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


static func has_only_keys(data: Dictionary, allowed: Array[String]) -> bool:
	for key: Variant in data.keys():
		if not allowed.has(str(key)):
			return false
	return true


static func is_coordinate(value_to_check: Variant) -> bool:
	if not value_to_check is Array:
		return false
	var coordinate: Array = value_to_check
	return coordinate.size() == 2 and coordinate[0] is int and coordinate[1] is int
