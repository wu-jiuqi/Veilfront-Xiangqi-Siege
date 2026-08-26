class_name TutorialModuleCatalog
extends Resource

@export var modules: Array[TutorialModuleDefinition] = []
@export var routes: Array[TutorialRouteDefinition] = []


func is_valid_catalog() -> bool:
	if modules.is_empty() or routes.size() != 2:
		return false
	var module_ids: Dictionary = {}
	var capability_evidence: Dictionary = {}
	for module: TutorialModuleDefinition in modules:
		if module == null or not module.is_valid_definition() or module_ids.has(module.module_id):
			return false
		module_ids[module.module_id] = true
		for capability_id: String in module.capability_ids:
			capability_evidence[capability_id] = true
	var route_ids: Dictionary = {}
	for route: TutorialRouteDefinition in routes:
		if route == null or not route.is_valid_definition() or route_ids.has(route.route_id):
			return false
		route_ids[route.route_id] = true
		for module_id: String in route.module_ids():
			if not module_ids.has(module_id):
				return false
		for capability_id: String in route.assumed_capability_ids:
			if not capability_evidence.has(capability_id):
				return false
	return route_ids.has("foundation") and route_ids.has("xiangqi_experienced")


func find_module(module_id: String) -> TutorialModuleDefinition:
	for module: TutorialModuleDefinition in modules:
		if module != null and module.module_id == module_id:
			return module
	return null


func find_route(route_id: String) -> TutorialRouteDefinition:
	for route: TutorialRouteDefinition in routes:
		if route != null and route.route_id == route_id:
			return route
	return null


func module_ids() -> Array[String]:
	var result: Array[String] = []
	for module: TutorialModuleDefinition in modules:
		if module != null:
			result.append(module.module_id)
	return result


func capability_ids() -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	for module: TutorialModuleDefinition in modules:
		if module == null:
			continue
		for capability_id: String in module.capability_ids:
			if not seen.has(capability_id):
				seen[capability_id] = true
				result.append(capability_id)
	result.sort()
	return result
