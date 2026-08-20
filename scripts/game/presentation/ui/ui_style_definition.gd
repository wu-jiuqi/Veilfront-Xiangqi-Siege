class_name UiStyleDefinition
extends Resource

@export var style_id: StringName
@export var display_name: String
@export var ui_theme: Theme


func is_valid() -> bool:
	return not style_id.is_empty() and ui_theme != null
