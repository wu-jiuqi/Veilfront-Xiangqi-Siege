class_name BoardMapOption
extends Resource

@export var map_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var background_texture: Texture2D
@export var preview_texture: Texture2D
@export var selectable: bool = false
@export_range(0, 1000, 1) var recommended_order: int = 0


func is_valid_definition() -> bool:
	return not map_id.is_empty() \
		and not display_name.is_empty() \
		and background_texture != null


func get_preview_texture() -> Texture2D:
	return preview_texture if preview_texture != null else background_texture
