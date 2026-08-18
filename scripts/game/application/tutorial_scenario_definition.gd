class_name TutorialScenarioDefinition
extends Resource

@export var scenario_id: String = ""
@export var fixture_key: String = ""
@export var bound_seat: String = "red"
@export var allowed_preview_ids: PackedStringArray = []
@export var restart_allowed: bool = true
@export var skip_allowed: bool = true


func is_valid_definition() -> bool:
	if scenario_id.is_empty() \
	or fixture_key.is_empty() \
	or bound_seat not in ["red", "black"]:
		return false
	var unique_preview_ids: Dictionary = {}
	for preview_id: String in allowed_preview_ids:
		if preview_id.is_empty() or unique_preview_ids.has(preview_id):
			return false
		unique_preview_ids[preview_id] = true
	return true


func allows_preview(preview_id: String) -> bool:
	return is_valid_definition() \
		and not preview_id.is_empty() \
		and allowed_preview_ids.has(preview_id)


func allows_restart() -> bool:
	return is_valid_definition() and restart_allowed


func allows_skip() -> bool:
	return is_valid_definition() and skip_allowed
