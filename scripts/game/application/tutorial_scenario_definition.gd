class_name TutorialScenarioDefinition
extends Resource

@export var scenario_id: String = ""
@export var fixture_key: String = ""
@export var bound_seat: String = "red"
@export var allowed_preview_ids: PackedStringArray = []
@export var restart_allowed: bool = true
@export var skip_allowed: bool = true


func is_valid_definition() -> bool:
	return not scenario_id.is_empty() \
		and not fixture_key.is_empty() \
		and bound_seat in ["red", "black"]
