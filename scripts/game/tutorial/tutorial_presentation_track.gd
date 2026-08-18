class_name TutorialPresentationTrack
extends Resource

@export var track_id: String = ""
@export var initial_step_id: String = "welcome"
@export var step_ids: PackedStringArray = []
@export var instruction_keys: PackedStringArray = []
@export var trigger_message_keys: PackedStringArray = []


func is_valid_track() -> bool:
	return not track_id.is_empty() \
		and step_ids.size() == instruction_keys.size() \
		and step_ids.size() == trigger_message_keys.size()


func step_for_message(message_key: String) -> Dictionary:
	var index: int = trigger_message_keys.find(message_key)
	if index < 0:
		return {}
	return {"step_id": step_ids[index], "instruction_key": instruction_keys[index]}
