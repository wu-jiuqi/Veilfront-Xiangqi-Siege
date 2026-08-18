extends RefCounted

var _bound_side: String = ""


static func create_trusted(side: String) -> RefCounted:
	assert(side in ["red", "black"])
	var context: RefCounted = new()
	context._bound_side = side
	return context


func side() -> String:
	return _bound_side


func is_valid() -> bool:
	return _bound_side in ["red", "black"]
