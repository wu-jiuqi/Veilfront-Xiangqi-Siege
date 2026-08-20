class_name BoardMapCatalog
extends Resource

const MAP_OPTION := preload("res://scripts/game/presentation/board/board_map_option.gd")

@export var maps: Array[MAP_OPTION] = []


func get_selectable_maps() -> Array[MAP_OPTION]:
	var result: Array[MAP_OPTION] = []
	for option: MAP_OPTION in maps:
		if option != null and option.selectable and option.is_valid_definition():
			result.append(option)
	result.sort_custom(func(left: MAP_OPTION, right: MAP_OPTION) -> bool:
		return left.recommended_order < right.recommended_order
	)
	return result


func find_map(map_id: StringName) -> MAP_OPTION:
	for option: MAP_OPTION in maps:
		if option != null and option.map_id == map_id:
			return option
	return null
