class_name TutorialModuleDefinition
extends Resource

@export var module_id: String = ""
@export var authority: TutorialScenarioDefinition
@export var presentation: TutorialPresentationTrack
@export var capability_ids: PackedStringArray = []
@export_range(1, 20, 1) var estimated_minutes: int = 2
@export var core_required: bool = false
@export var complete_required: bool = true
@export var positive_evidence_tags: PackedStringArray = []
@export var negative_evidence_tags: PackedStringArray = []
@export var reset_evidence_tags: PackedStringArray = []


func is_valid_definition() -> bool:
	if module_id.is_empty() or authority == null or presentation == null:
		return false
	if authority.level_id != module_id or presentation.level_id != module_id:
		return false
	if not authority.is_valid_definition() or not presentation.is_valid_track():
		return false
	if capability_ids.is_empty() or estimated_minutes <= 0:
		return false
	return _values_are_unique(capability_ids) \
		and not positive_evidence_tags.is_empty() \
		and not reset_evidence_tags.is_empty()


func _values_are_unique(values: PackedStringArray) -> bool:
	var seen: Dictionary = {}
	for value: String in values:
		if value.is_empty() or seen.has(value):
			return false
		seen[value] = true
	return true
