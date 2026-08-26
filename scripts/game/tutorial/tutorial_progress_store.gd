class_name TutorialProgressStore
extends RefCounted

const SCHEMA_VERSION: int = 2
const SECTION: String = "tutorial_progress_v2"
const LEGACY_SECTION: String = "progress"
const DEFAULT_PATH: String = "user://level_progress.cfg"

const UNSEEN: String = "UNSEEN"
const ASSUMED: String = "ASSUMED"
const COMPLETED: String = "COMPLETED"
const SKIPPED: String = "SKIPPED"
const NEEDS_REVIEW: String = "NEEDS_REVIEW"
const VALID_STATES: Array[String] = [UNSEEN, ASSUMED, COMPLETED, SKIPPED, NEEDS_REVIEW]

var _path: String = DEFAULT_PATH
var _catalog: TutorialModuleCatalog
var _selected_route_id: String = ""
var _capability_states: Dictionary = {}
var _completed_module_ids: Array[String] = []
var _skipped_module_ids: Array[String] = []
var _current_module_id: String = ""
var _loaded: bool = false


func _init(path: String = DEFAULT_PATH, catalog: TutorialModuleCatalog = null) -> void:
	_path = path
	_catalog = catalog


func load_progress() -> bool:
	_reset_memory()
	var config := ConfigFile.new()
	var load_error := config.load(_path)
	if load_error not in [OK, ERR_FILE_NOT_FOUND]:
		push_error("TutorialProgressStore could not load progress: %s" % error_string(load_error))
		return false
	if load_error == ERR_FILE_NOT_FOUND:
		_loaded = true
		return true
	var version := int(config.get_value(SECTION, "schema_version", 0))
	if version <= 0:
		_migrate_legacy(config)
	else:
		_selected_route_id = str(config.get_value(SECTION, "selected_route_id", ""))
		_capability_states = _sanitize_capability_states(
			config.get_value(SECTION, "capability_states", {})
		)
		_completed_module_ids = _sanitize_module_ids(
			config.get_value(SECTION, "completed_module_ids", [])
		)
		_skipped_module_ids = _sanitize_module_ids(
			config.get_value(SECTION, "skipped_module_ids", [])
		)
		_current_module_id = str(config.get_value(SECTION, "current_module_id", ""))
		if _catalog != null and _catalog.find_module(_current_module_id) == null:
			_current_module_id = ""
		if _catalog != null and _catalog.find_route(_selected_route_id) == null:
			_selected_route_id = ""
	_loaded = true
	if version < SCHEMA_VERSION:
		return save_progress()
	return true


func save_progress() -> bool:
	if not _loaded:
		_loaded = true
	var config := ConfigFile.new()
	var load_error := config.load(_path)
	if load_error not in [OK, ERR_FILE_NOT_FOUND]:
		push_error("TutorialProgressStore could not reload progress: %s" % error_string(load_error))
		return false
	config.set_value(SECTION, "schema_version", SCHEMA_VERSION)
	config.set_value(SECTION, "selected_route_id", _selected_route_id)
	config.set_value(SECTION, "capability_states", _capability_states.duplicate(true))
	config.set_value(SECTION, "completed_module_ids", _completed_module_ids.duplicate())
	config.set_value(SECTION, "skipped_module_ids", _skipped_module_ids.duplicate())
	config.set_value(SECTION, "current_module_id", _current_module_id)
	var legacy_completed := _legacy_completed_ids(config)
	for module_id: String in _completed_module_ids:
		if module_id not in legacy_completed:
			legacy_completed.append(module_id)
	legacy_completed.sort()
	config.set_value(LEGACY_SECTION, "completed_ids", legacy_completed)
	var save_error := config.save(_path)
	if save_error != OK:
		push_error("TutorialProgressStore could not save progress: %s" % error_string(save_error))
		return false
	return true


func select_route(route_id: String) -> bool:
	if _catalog == null:
		return false
	var route := _catalog.find_route(route_id)
	if route == null:
		return false
	_selected_route_id = route_id
	for capability_id: String in route.assumed_capability_ids:
		if capability_state(capability_id) == UNSEEN:
			_capability_states[capability_id] = ASSUMED
	return save_progress()


func record_module_completed(module_id: String) -> bool:
	var module := _module(module_id)
	if module == null:
		return false
	if module_id not in _completed_module_ids:
		_completed_module_ids.append(module_id)
	_completed_module_ids.sort()
	_skipped_module_ids.erase(module_id)
	for capability_id: String in module.capability_ids:
		_capability_states[capability_id] = COMPLETED
	_current_module_id = module_id
	return save_progress()


func record_module_skipped(module_id: String) -> bool:
	var module := _module(module_id)
	if module == null or module_id in _completed_module_ids:
		return false
	if module_id not in _skipped_module_ids:
		_skipped_module_ids.append(module_id)
	_skipped_module_ids.sort()
	for capability_id: String in module.capability_ids:
		if capability_state(capability_id) in [UNSEEN, ASSUMED]:
			_capability_states[capability_id] = SKIPPED
	_current_module_id = module_id
	return save_progress()


func mark_capabilities_for_review(capability_ids: PackedStringArray) -> bool:
	for capability_id: String in capability_ids:
		if capability_state(capability_id) != UNSEEN:
			_capability_states[capability_id] = NEEDS_REVIEW
	return save_progress()


func set_current_module(module_id: String) -> bool:
	if _module(module_id) == null:
		return false
	_current_module_id = module_id
	return save_progress()


func reset_tutorial_progress() -> bool:
	var config := ConfigFile.new()
	var load_error := config.load(_path)
	if load_error not in [OK, ERR_FILE_NOT_FOUND]:
		push_error("TutorialProgressStore could not load progress for reset: %s" % error_string(load_error))
		return false
	config.erase_section(SECTION)
	var preserved_ids: Array[String] = []
	for level_id: String in _legacy_completed_ids(config):
		if _catalog == null or _catalog.find_module(level_id) == null:
			preserved_ids.append(level_id)
	config.set_value(LEGACY_SECTION, "completed_ids", preserved_ids)
	var save_error := config.save(_path)
	if save_error != OK:
		push_error("TutorialProgressStore could not reset progress: %s" % error_string(save_error))
		return false
	_reset_memory()
	_loaded = true
	return true


func selected_route_id() -> String:
	return _selected_route_id


func selected_route() -> TutorialRouteDefinition:
	return _catalog.find_route(_selected_route_id) if _catalog != null else null


func capability_state(capability_id: String) -> String:
	return str(_capability_states.get(capability_id, UNSEEN))


func capability_states() -> Dictionary:
	return _capability_states.duplicate(true)


func completed_module_ids() -> Array[String]:
	return _completed_module_ids.duplicate()


func skipped_module_ids() -> Array[String]:
	return _skipped_module_ids.duplicate()


func current_module_id() -> String:
	return _current_module_id


func module_is_resolved(module_id: String) -> bool:
	return module_id in _completed_module_ids or module_id in _skipped_module_ids


func is_core_ready() -> bool:
	return _requirements_ready(true)


func is_complete_ready() -> bool:
	return _requirements_ready(false)


func route_completion_ratio(route: TutorialRouteDefinition) -> float:
	if route == null:
		return 0.0
	var module_ids := route.module_ids()
	if module_ids.is_empty():
		return 0.0
	var resolved := 0
	for module_id: String in module_ids:
		if module_is_resolved(module_id):
			resolved += 1
	return float(resolved) / float(module_ids.size())


func _requirements_ready(core_only: bool) -> bool:
	if _catalog == null:
		return false
	var route := selected_route()
	var assumed_capability_ids: PackedStringArray = route.assumed_capability_ids \
		if route != null else PackedStringArray()
	for module: TutorialModuleDefinition in _catalog.modules:
		var required := module.core_required if core_only else module.complete_required
		if not required:
			continue
		for capability_id: String in module.capability_ids:
			var state := capability_state(capability_id)
			var accepted_assumption := state == ASSUMED \
				and capability_id in assumed_capability_ids
			if core_only and state != COMPLETED and not accepted_assumption:
				return false
			if not core_only and state != COMPLETED and not accepted_assumption:
				return false
	return true


func _migrate_legacy(config: ConfigFile) -> void:
	for module_id: String in _legacy_completed_ids(config):
		var module := _module(module_id)
		if module == null:
			continue
		_completed_module_ids.append(module_id)
		for capability_id: String in module.capability_ids:
			_capability_states[capability_id] = COMPLETED
	_completed_module_ids.sort()


func _legacy_completed_ids(config: ConfigFile) -> Array[String]:
	var result: Array[String] = []
	var saved_ids: Variant = config.get_value(LEGACY_SECTION, "completed_ids", [])
	if saved_ids is Array:
		for value: Variant in saved_ids:
			var level_id := str(value)
			if not level_id.is_empty() and level_id not in result:
				result.append(level_id)
	return result


func _sanitize_module_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value:
		var module_id := str(item)
		if _module(module_id) != null and module_id not in result:
			result.append(module_id)
	result.sort()
	return result


func _sanitize_capability_states(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	var allowed: Array[String] = _catalog.capability_ids() if _catalog != null else []
	for capability_value: Variant in value:
		var capability_id := str(capability_value)
		var state := str((value as Dictionary).get(capability_value, UNSEEN))
		if state in VALID_STATES and (_catalog == null or capability_id in allowed):
			result[capability_id] = state
	return result


func _module(module_id: String) -> TutorialModuleDefinition:
	return _catalog.find_module(module_id) if _catalog != null else null


func _reset_memory() -> void:
	_selected_route_id = ""
	_capability_states.clear()
	_completed_module_ids.clear()
	_skipped_module_ids.clear()
	_current_module_id = ""
	_loaded = false
