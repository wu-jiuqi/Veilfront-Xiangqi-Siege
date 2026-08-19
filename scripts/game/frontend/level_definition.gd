class_name LevelDefinition
extends Resource

@export var level_id: String = ""
@export_enum("tutorial", "challenge") var category: String = "tutorial"
@export var title: String = ""
@export_multiline var summary: String = ""
@export_multiline var objective_text: String = ""
@export_file("*.tscn") var scene_path: String = ""
@export var unlock_after: String = ""
@export var recommended_order: int = 0
@export var available: bool = false


func is_valid_definition() -> bool:
	return not level_id.is_empty() \
		and not title.is_empty() \
		and (category == "tutorial" or category == "challenge") \
		and not scene_path.is_empty()

