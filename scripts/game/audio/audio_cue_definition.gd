class_name AudioCueDefinition
extends Resource

@export var cue_key: String = ""
@export var streams: Array[AudioStream] = []
@export var bus: StringName = &"SFX_System"
@export_range(-48.0, 6.0, 0.1) var volume_db_min: float = -6.0
@export_range(-48.0, 6.0, 0.1) var volume_db_max: float = -3.0
@export_range(0.5, 2.0, 0.01) var pitch_scale_min: float = 0.96
@export_range(0.5, 2.0, 0.01) var pitch_scale_max: float = 1.04
@export_enum("low", "normal", "high", "critical") var priority: String = "normal"
@export var concurrency_group: String = "system"
@export_range(1, 16, 1) var max_instances: int = 2
@export_range(0, 2000, 1) var cooldown_ms: int = 0
@export var spatial_modes_allowed: Array[String] = ["global"]


func is_valid_definition() -> bool:
	if cue_key.is_empty() or not cue_key.begins_with("sfx.") or streams.is_empty():
		return false
	if bus not in [&"SFX_UI", &"SFX_Board", &"SFX_System"]:
		return false
	if volume_db_min > volume_db_max or pitch_scale_min > pitch_scale_max:
		return false
	if priority not in ["low", "normal", "high", "critical"]:
		return false
	if concurrency_group.is_empty() or max_instances <= 0 or cooldown_ms < 0:
		return false
	if spatial_modes_allowed.is_empty():
		return false
	for stream: AudioStream in streams:
		if stream == null:
			return false
	for mode: String in spatial_modes_allowed:
		if mode not in ["global", "board_2d"]:
			return false
	return true
