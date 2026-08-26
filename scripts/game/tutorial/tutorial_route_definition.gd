class_name TutorialRouteDefinition
extends Resource

@export var route_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export_range(1, 60, 1) var target_minutes_min: int = 12
@export_range(1, 60, 1) var target_minutes_max: int = 18
@export_range(0, 3, 1) var default_hint_tier: int = 0
@export var chapters: Array[TutorialRouteChapterDefinition] = []
@export var assumed_capability_ids: PackedStringArray = []
@export var recommended_entry: String = "level_select"


func is_valid_definition() -> bool:
	if route_id.is_empty() or title.is_empty() or description.is_empty():
		return false
	if target_minutes_min <= 0 or target_minutes_max < target_minutes_min:
		return false
	if chapters.is_empty() or recommended_entry.is_empty():
		return false
	var chapter_ids: Dictionary = {}
	var module_ids_seen: Dictionary = {}
	for chapter: TutorialRouteChapterDefinition in chapters:
		if chapter == null or not chapter.is_valid_definition():
			return false
		if chapter_ids.has(chapter.chapter_id):
			return false
		chapter_ids[chapter.chapter_id] = true
		for module_id: String in chapter.module_ids:
			if module_ids_seen.has(module_id):
				return false
			module_ids_seen[module_id] = true
	var assumed_seen: Dictionary = {}
	for capability_id: String in assumed_capability_ids:
		if capability_id.is_empty() or assumed_seen.has(capability_id):
			return false
		assumed_seen[capability_id] = true
	return true


func module_ids() -> Array[String]:
	var result: Array[String] = []
	for chapter: TutorialRouteChapterDefinition in chapters:
		for module_id: String in chapter.module_ids:
			result.append(module_id)
	return result


func chapter_for_module(module_id: String) -> TutorialRouteChapterDefinition:
	for chapter: TutorialRouteChapterDefinition in chapters:
		if module_id in chapter.module_ids:
			return chapter
	return null
