extends Node

signal settings_changed(settings: Dictionary)

const SETTINGS_VERSION := 1
const DEFAULT_SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LEVEL_PROGRESS_PATH := "user://level_progress.cfg"
const SUPPORTED_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var _settings_path: String
var _level_progress_path: String
var _runtime_enabled: bool
var _settings: Dictionary = {}
var _preview_snapshot: Dictionary = {}


func _init(
	settings_path: String = DEFAULT_SETTINGS_PATH,
	runtime_enabled: bool = true,
	level_progress_path: String = DEFAULT_LEVEL_PROGRESS_PATH
) -> void:
	_settings_path = settings_path
	_runtime_enabled = runtime_enabled
	_level_progress_path = level_progress_path


func _ready() -> void:
	reload_settings()


static func default_settings() -> Dictionary:
	return {
		"window_mode": "fullscreen",
		"resolution": Vector2i(1920, 1080),
		"vsync": true,
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"skip_opening": false,
		"reduce_motion": false,
	}


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func reload_settings() -> Error:
	_preview_snapshot.clear()
	var config := ConfigFile.new()
	var load_error := config.load(_settings_path)
	if load_error == ERR_FILE_NOT_FOUND:
		_settings = default_settings()
	elif load_error != OK:
		push_warning("无法读取设置文件，将使用默认设置：%s" % error_string(load_error))
		_settings = default_settings()
	else:
		var defaults := default_settings()
		var candidate := {
			"window_mode": config.get_value("display", "window_mode", defaults["window_mode"]),
			"resolution": config.get_value("display", "resolution", defaults["resolution"]),
			"vsync": config.get_value("display", "vsync", defaults["vsync"]),
			"master_volume": config.get_value("audio", "master_volume", defaults["master_volume"]),
			"music_volume": config.get_value("audio", "music_volume", defaults["music_volume"]),
			"sfx_volume": config.get_value("audio", "sfx_volume", defaults["sfx_volume"]),
			"skip_opening": config.get_value("experience", "skip_opening", defaults["skip_opening"]),
			"reduce_motion": config.get_value("experience", "reduce_motion", defaults["reduce_motion"]),
		}
		_settings = _sanitize_settings(candidate)
	apply_runtime_settings()
	settings_changed.emit(get_settings())
	return load_error


func begin_preview(candidate: Dictionary) -> bool:
	if is_preview_active():
		revert_preview()
	_preview_snapshot = get_settings()
	_settings = _sanitize_settings(candidate)
	apply_runtime_settings()
	settings_changed.emit(get_settings())
	return _display_settings_differ(_preview_snapshot, _settings)


func commit_preview() -> Error:
	var save_error := save_settings()
	if save_error != OK:
		revert_preview()
		return save_error
	_preview_snapshot.clear()
	settings_changed.emit(get_settings())
	return OK


func revert_preview() -> void:
	if not is_preview_active():
		return
	_settings = _preview_snapshot.duplicate(true)
	_preview_snapshot.clear()
	apply_runtime_settings()
	settings_changed.emit(get_settings())


func is_preview_active() -> bool:
	return not _preview_snapshot.is_empty()


func save_settings() -> Error:
	var directory_error := _ensure_parent_directory(_settings_path)
	if directory_error != OK:
		push_error("无法创建设置目录：%s" % error_string(directory_error))
		return directory_error

	var config := ConfigFile.new()
	config.set_value("meta", "version", SETTINGS_VERSION)
	config.set_value("display", "window_mode", _settings["window_mode"])
	config.set_value("display", "resolution", _settings["resolution"])
	config.set_value("display", "vsync", _settings["vsync"])
	config.set_value("audio", "master_volume", _settings["master_volume"])
	config.set_value("audio", "music_volume", _settings["music_volume"])
	config.set_value("audio", "sfx_volume", _settings["sfx_volume"])
	config.set_value("experience", "skip_opening", _settings["skip_opening"])
	config.set_value("experience", "reduce_motion", _settings["reduce_motion"])
	var save_error := config.save(_settings_path)
	if save_error != OK:
		push_error("无法保存设置：%s" % error_string(save_error))
	return save_error


func reset_level_progress() -> Error:
	var directory_error := _ensure_parent_directory(_level_progress_path)
	if directory_error != OK:
		push_error("无法创建关卡进度目录：%s" % error_string(directory_error))
		return directory_error
	var config := ConfigFile.new()
	config.set_value("progress", "completed_ids", [])
	var save_error := config.save(_level_progress_path)
	if save_error != OK:
		push_error("无法重置关卡进度：%s" % error_string(save_error))
	return save_error


func should_skip_opening() -> bool:
	return bool(_settings.get("skip_opening", false))


func is_reduced_motion_enabled() -> bool:
	return bool(_settings.get("reduce_motion", false))


func apply_runtime_settings() -> void:
	if not _runtime_enabled:
		return
	_apply_audio_settings()
	_apply_display_settings()


func _sanitize_settings(candidate: Dictionary) -> Dictionary:
	var defaults := default_settings()
	var window_mode := str(candidate.get("window_mode", defaults["window_mode"]))
	if window_mode not in ["windowed", "fullscreen"]:
		window_mode = str(defaults["window_mode"])

	var resolution: Vector2i = defaults["resolution"]
	var resolution_value: Variant = candidate.get("resolution", resolution)
	if resolution_value is Vector2i:
		resolution = resolution_value
	elif resolution_value is Vector2:
		resolution = Vector2i(resolution_value)
	if not SUPPORTED_RESOLUTIONS.has(resolution):
		resolution = defaults["resolution"]

	return {
		"window_mode": window_mode,
		"resolution": resolution,
		"vsync": bool(candidate.get("vsync", defaults["vsync"])),
		"master_volume": clampf(float(candidate.get("master_volume", defaults["master_volume"])), 0.0, 1.0),
		"music_volume": clampf(float(candidate.get("music_volume", defaults["music_volume"])), 0.0, 1.0),
		"sfx_volume": clampf(float(candidate.get("sfx_volume", defaults["sfx_volume"])), 0.0, 1.0),
		"skip_opening": bool(candidate.get("skip_opening", defaults["skip_opening"])),
		"reduce_motion": bool(candidate.get("reduce_motion", defaults["reduce_motion"])),
	}


func _apply_audio_settings() -> void:
	_apply_bus_volume(&"Master", float(_settings["master_volume"]))
	_apply_bus_volume(&"Music", float(_settings["music_volume"]))
	_apply_bus_volume(&"SFX", float(_settings["sfx_volume"]))


func _apply_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("音频总线不存在：%s" % bus_name)
		return
	var muted := linear_volume <= 0.0001
	AudioServer.set_bus_mute(bus_index, muted)
	if not muted:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_volume))


func _apply_display_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if bool(_settings["vsync"]) else DisplayServer.VSYNC_DISABLED
	)
	if _settings["window_mode"] == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var resolution: Vector2i = _settings["resolution"]
	DisplayServer.window_set_size(resolution)
	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	var centered_position := usable_rect.position + (usable_rect.size - resolution) / 2
	DisplayServer.window_set_position(centered_position)


func _display_settings_differ(previous: Dictionary, current: Dictionary) -> bool:
	return (
		previous.get("window_mode") != current.get("window_mode")
		or previous.get("resolution") != current.get("resolution")
		or previous.get("vsync") != current.get("vsync")
	)


func _ensure_parent_directory(path: String) -> Error:
	var directory_path := ProjectSettings.globalize_path(path).get_base_dir()
	return DirAccess.make_dir_recursive_absolute(directory_path)
