extends SceneTree

const SettingsManagerScript := preload("res://scripts/game/settings/settings_manager.gd")
const TEST_SETTINGS_PATH := "user://settings_manager_contract.cfg"
const TEST_PROGRESS_PATH := "user://settings_manager_progress_contract.cfg"


func _init() -> void:
	_remove_test_file(TEST_SETTINGS_PATH)
	_remove_test_file(TEST_PROGRESS_PATH)

	var manager := SettingsManagerScript.new(TEST_SETTINGS_PATH, false, TEST_PROGRESS_PATH)
	root.add_child(manager)
	await process_frame

	var defaults: Dictionary = manager.default_settings()
	assert(defaults["window_mode"] == "fullscreen")
	assert(defaults["resolution"] == Vector2i(1920, 1080))
	assert(defaults["vsync"])
	assert(is_equal_approx(defaults["master_volume"], 1.0))
	assert(not defaults["skip_opening"])
	assert(not defaults["reduce_motion"])

	var candidate := defaults.duplicate(true)
	candidate["window_mode"] = "windowed"
	candidate["resolution"] = Vector2i(1600, 900)
	candidate["vsync"] = false
	candidate["master_volume"] = 0.72
	candidate["music_volume"] = 0.48
	candidate["sfx_volume"] = 0.31
	candidate["skip_opening"] = true
	candidate["reduce_motion"] = true
	assert(manager.begin_preview(candidate), "display changes must require confirmation")
	assert(manager.is_preview_active())
	assert(manager.commit_preview() == OK)
	assert(not manager.is_preview_active())
	var saved_config := ConfigFile.new()
	assert(saved_config.load(TEST_SETTINGS_PATH) == OK)
	assert(saved_config.get_value("meta", "version", 0) == 1)

	var loaded_manager := SettingsManagerScript.new(TEST_SETTINGS_PATH, false, TEST_PROGRESS_PATH)
	root.add_child(loaded_manager)
	await process_frame
	var loaded: Dictionary = loaded_manager.get_settings()
	assert(loaded["window_mode"] == "windowed")
	assert(loaded["resolution"] == Vector2i(1600, 900))
	assert(not loaded["vsync"])
	assert(is_equal_approx(loaded["master_volume"], 0.72))
	assert(is_equal_approx(loaded["music_volume"], 0.48))
	assert(is_equal_approx(loaded["sfx_volume"], 0.31))
	assert(loaded["skip_opening"])
	assert(loaded["reduce_motion"])

	var invalid := loaded.duplicate(true)
	invalid["window_mode"] = "exclusive"
	invalid["resolution"] = Vector2i(111, 222)
	invalid["master_volume"] = 5.0
	invalid["music_volume"] = -2.0
	assert(loaded_manager.begin_preview(invalid))
	var sanitized: Dictionary = loaded_manager.get_settings()
	assert(sanitized["window_mode"] == "fullscreen")
	assert(sanitized["resolution"] == Vector2i(1920, 1080))
	assert(is_equal_approx(sanitized["master_volume"], 1.0))
	assert(is_equal_approx(sanitized["music_volume"], 0.0))
	loaded_manager.revert_preview()
	assert(loaded_manager.get_settings() == loaded, "revert must restore the previous committed values")

	var progress := ConfigFile.new()
	progress.set_value("progress", "completed_ids", ["T0", "T1"])
	assert(progress.save(TEST_PROGRESS_PATH) == OK)
	assert(loaded_manager.reset_level_progress() == OK)
	var reset_progress := ConfigFile.new()
	assert(reset_progress.load(TEST_PROGRESS_PATH) == OK)
	assert(reset_progress.get_value("progress", "completed_ids", ["unexpected"]).is_empty())
	assert(AudioServer.get_bus_index(&"Music") >= 0)
	assert(AudioServer.get_bus_index(&"SFX") >= 0)
	var runtime_manager := SettingsManagerScript.new(TEST_SETTINGS_PATH, true, TEST_PROGRESS_PATH)
	root.add_child(runtime_manager)
	await process_frame
	var audio_candidate: Dictionary = runtime_manager.get_settings()
	audio_candidate["master_volume"] = 0.25
	audio_candidate["music_volume"] = 0.0
	audio_candidate["sfx_volume"] = 0.5
	runtime_manager.begin_preview(audio_candidate)
	var master_bus := AudioServer.get_bus_index(&"Master")
	var music_bus := AudioServer.get_bus_index(&"Music")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	assert(is_equal_approx(AudioServer.get_bus_volume_db(master_bus), linear_to_db(0.25)))
	assert(AudioServer.is_bus_mute(music_bus))
	assert(is_equal_approx(AudioServer.get_bus_volume_db(sfx_bus), linear_to_db(0.5)))
	runtime_manager.revert_preview()

	manager.queue_free()
	loaded_manager.queue_free()
	runtime_manager.queue_free()
	await process_frame
	_remove_test_file(TEST_SETTINGS_PATH)
	_remove_test_file(TEST_PROGRESS_PATH)
	print("SETTINGS_MANAGER_CONTRACT_PASS version=1 display_preview=revertable audio=3 experience=2 progress_reset=confirmed")
	quit()


func _remove_test_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
