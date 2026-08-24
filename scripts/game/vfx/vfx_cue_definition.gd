class_name VfxCueDefinition
extends Resource

@export var family: String = ""
@export var cue_prefix: String = ""
@export var display_name: String = ""
@export var base_color: Color = Color.WHITE
@export var accent_color: Color = Color.WHITE
@export_range(0.05, 2.0, 0.01) var duration_standard: float = 0.5
@export_range(0.05, 1.0, 0.01) var duration_reduced: float = 0.22
@export_range(8.0, 640.0, 1.0) var radius: float = 48.0
@export_range(0, 64, 1) var particles_standard: int = 8
@export_range(0, 12, 1) var particles_reduced: int = 0
@export_range(0, 100, 1) var overdraw_points_standard: int = 10
@export_range(0, 60, 1) var overdraw_points_reduced: int = 4
@export_range(1, 8, 1) var max_instances: int = 2
@export_range(0.0, 3.0, 0.1) var flash_hz_max: float = 0.0
@export_range(0.0, 0.25, 0.01) var flash_area_ratio_max: float = 0.02
@export var particle_texture: Texture2D


func matches(cue_key: String) -> bool:
	return not cue_prefix.is_empty() \
		and (cue_key == cue_prefix or cue_key.begins_with("%s." % cue_prefix))


func is_valid_definition() -> bool:
	return family in [
		"selection", "move", "capture", "callout", "bombardment", "resurrection",
		"wall", "flag", "terminal",
	] and cue_prefix == "vfx.%s" % family \
		and not display_name.is_empty() \
		and duration_reduced <= duration_standard \
		and particles_reduced <= particles_standard \
		and overdraw_points_reduced <= overdraw_points_standard \
		and max_instances >= 1 \
		and flash_hz_max <= 3.0 \
		and flash_area_ratio_max <= 0.25
