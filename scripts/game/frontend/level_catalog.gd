class_name LevelCatalog
extends Resource

@export var levels: Array[LevelDefinition] = []


func get_levels_for_category(category: String) -> Array[LevelDefinition]:
	var result: Array[LevelDefinition] = []
	for level: LevelDefinition in levels:
		if level != null and level.category == category:
			result.append(level)
	result.sort_custom(func(left: LevelDefinition, right: LevelDefinition) -> bool:
		return left.recommended_order < right.recommended_order
	)
	return result


func find_level(level_id: String) -> LevelDefinition:
	for level: LevelDefinition in levels:
		if level != null and level.level_id == level_id:
			return level
	return null
