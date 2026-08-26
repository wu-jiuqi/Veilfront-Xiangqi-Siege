class_name TutorialRouteChapterDefinition
extends Resource

@export var chapter_id: String = ""
@export var title: String = ""
@export_multiline var summary: String = ""
@export_range(1, 20, 1) var estimated_minutes: int = 3
@export var module_ids: PackedStringArray = []
@export var assessment: bool = false


func is_valid_definition() -> bool:
	if chapter_id.is_empty() or title.is_empty() or summary.is_empty():
		return false
	if estimated_minutes <= 0 or module_ids.is_empty():
		return false
	var seen: Dictionary = {}
	for module_id: String in module_ids:
		if module_id.is_empty() or seen.has(module_id):
			return false
		seen[module_id] = true
	return true
