extends SceneTree

const CATALOG: TutorialModuleCatalog = preload(
	"res://resources/game/tutorials/tutorial_module_catalog.tres"
)
const PROGRESS_PATH: String = "user://tutorial-curriculum-contract.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(CATALOG.is_valid_catalog(), "tutorial module catalog is invalid")
	_expect(CATALOG.modules.size() == 18, "tutorial catalog must contain 18 modules")
	var foundation := CATALOG.find_route("foundation")
	var experienced := CATALOG.find_route("xiangqi_experienced")
	_expect(foundation != null and foundation.module_ids().size() == 18, "foundation route must contain 18 modules")
	_expect(experienced != null and experienced.module_ids().size() == 15, "experienced route must contain 15 modules")
	for capability_id: String in ["B-01", "B-02", "B-03", "B-04", "B-05", "B-06", "B-07", "B-08"]:
		_expect(capability_id in experienced.assumed_capability_ids, "experienced route missed assumed %s" % capability_id)
	for module_id: String in ["P0", "B1", "B2", "B3", "T8-R", "T9-C", "T10-E"]:
		var module := CATALOG.find_module(module_id)
		_expect(module != null, "%s module is missing" % module_id)
		if module != null:
			_expect(module.authority.step_effects.is_empty(), "%s must not add direct tutorial effects" % module_id)

	_remove_progress()
	var legacy := ConfigFile.new()
	legacy.set_value("progress", "completed_ids", ["T0", "C1"])
	legacy.save(PROGRESS_PATH)
	var store := TutorialProgressStore.new(PROGRESS_PATH, CATALOG)
	_expect(store.load_progress(), "legacy progress migration failed")
	_expect("T0" in store.completed_module_ids(), "legacy T0 completion was not migrated")
	_expect(store.select_route("xiangqi_experienced"), "experienced route could not be selected")
	_expect(store.capability_state("B-01") == TutorialProgressStore.ASSUMED, "experienced basics must be ASSUMED")
	_expect(store.record_module_skipped("P0"), "P0 skip was not saved")
	_expect("P0" in store.skipped_module_ids(), "P0 skip state is missing")
	_expect(store.record_module_completed("P0"), "P0 completion was not saved")
	_expect("P0" not in store.skipped_module_ids(), "completion must replace skipped state")
	for module_id: String in experienced.module_ids():
		store.record_module_completed(module_id)
	_expect(store.is_core_ready(), "experienced route did not reach core ready")
	_expect(store.is_complete_ready(), "experienced route assumptions were not accepted for graduation")
	store.select_route("foundation")
	_expect(not store.is_complete_ready(), "foundation route incorrectly accepted experienced assumptions")
	for module_id: String in ["B1", "B2", "B3"]:
		store.record_module_completed(module_id)
	_expect(store.is_complete_ready(), "foundation route did not graduate after basic modules")
	_expect(store.reset_tutorial_progress(), "tutorial reset failed")
	var reset_config := ConfigFile.new()
	_expect(reset_config.load(PROGRESS_PATH) == OK, "reset progress file is missing")
	var preserved: Variant = reset_config.get_value("progress", "completed_ids", [])
	_expect(preserved is Array and "C1" in preserved, "reset must preserve challenge progress")
	_expect(preserved is Array and "T0" not in preserved, "reset must remove tutorial progress")
	_remove_progress()

	if _failures.is_empty():
		print("TUTORIAL_CURRICULUM_CONTRACT_PASS modules=18 routes=2 migration=v2")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _remove_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
