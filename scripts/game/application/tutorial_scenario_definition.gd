class_name TutorialScenarioDefinition
extends Resource

@export var scenario_id: String = ""
@export var level_id: String = ""
@export var fixture_key: String = ""
@export var bound_seat: String = "red"
@export var seed_value: int = 471001
@export var initial_pieces: Array[Dictionary] = []
@export var initial_visible_cells: Array[Vector2i] = []
@export var initial_flags: Array[Dictionary] = []
@export var initial_casualties: Array[Dictionary] = []
@export_enum("INTACT", "BREACHED", "REPAIRING") var black_wall_status: String = "INTACT"
@export var allowed_preview_ids: PackedStringArray = []
@export var allow_any_public_preview: bool = false
@export var restart_allowed: bool = true
@export var skip_allowed: bool = true


func is_valid_definition() -> bool:
	if scenario_id.is_empty() \
	or fixture_key.is_empty() \
	or bound_seat not in ["red", "black"]:
		return false
	if not level_id.is_empty() and level_id not in _tutorial_level_ids():
		return false
	if seed_value <= 0 or black_wall_status not in ["INTACT", "BREACHED", "REPAIRING"]:
		return false
	var occupied: Dictionary = {}
	var piece_ids: Dictionary = {}
	for piece: Dictionary in initial_pieces:
		var piece_id := str(piece.get("id", ""))
		var side := str(piece.get("side", ""))
		var piece_type := str(piece.get("piece_type", ""))
		var position: Array = piece.get("position", [])
		if piece_id.is_empty() or piece_ids.has(piece_id) or side not in ["red", "black"] \
		or piece_type not in ["rook", "horse", "elephant", "advisor", "general", "cannon", "pawn"] \
		or not _is_coordinate(position):
			return false
		var key := "%d,%d" % [int(position[0]), int(position[1])]
		if occupied.has(key):
			return false
		piece_ids[piece_id] = true
		occupied[key] = true
	var unique_preview_ids: Dictionary = {}
	for preview_id: String in allowed_preview_ids:
		if preview_id.is_empty() or unique_preview_ids.has(preview_id):
			return false
		unique_preview_ids[preview_id] = true
	return true


func allows_preview(preview_id: String) -> bool:
	return is_valid_definition() \
		and not preview_id.is_empty() \
		and (allow_any_public_preview or allowed_preview_ids.has(preview_id))


func allows_restart() -> bool:
	return is_valid_definition() and restart_allowed


func allows_skip() -> bool:
	return is_valid_definition() and skip_allowed


func _is_coordinate(value: Variant) -> bool:
	return value is Array and value.size() == 2 \
		and typeof(value[0]) == TYPE_INT and typeof(value[1]) == TYPE_INT \
		and int(value[0]) >= 1 and int(value[0]) <= 9 \
		and int(value[1]) >= 1 and int(value[1]) <= 24


func _tutorial_level_ids() -> Array[String]:
	return ["T0", "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10"]
