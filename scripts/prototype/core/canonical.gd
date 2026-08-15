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


static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func coordinate(value_to_convert: Variant) -> Vector2i:
	if value_to_convert is Vector2i:
		return value_to_convert
	if value_to_convert is Array and value_to_convert.size() == 2:
		return Vector2i(int(value_to_convert[0]), int(value_to_convert[1]))
	return Vector2i(-1, -1)
