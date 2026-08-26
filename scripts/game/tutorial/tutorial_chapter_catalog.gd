class_name TutorialChapterCatalog
extends RefCounted

const CATALOG: TutorialModuleCatalog = preload(
	"res://resources/game/tutorials/tutorial_module_catalog.tres"
)
const TUTORIAL_IDS: Array[String] = [
	"P0", "B1", "B2", "B3",
	"T0", "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10",
	"T8-R", "T9-C", "T10-E",
]


static func authority(level_id: String) -> TutorialScenarioDefinition:
	var module := CATALOG.find_module(level_id)
	return module.authority if module != null else null


static func presentation(level_id: String) -> TutorialPresentationTrack:
	var module := CATALOG.find_module(level_id)
	return module.presentation if module != null else null


static func module(level_id: String) -> TutorialModuleDefinition:
	return CATALOG.find_module(level_id)


static func route(route_id: String) -> TutorialRouteDefinition:
	return CATALOG.find_route(route_id)


static func route_module_ids(route_id: String) -> Array[String]:
	var definition := route(route_id)
	return definition.module_ids() if definition != null else []
