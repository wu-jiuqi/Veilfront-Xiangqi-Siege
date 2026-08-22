class_name SceneTransitionController
extends CanvasLayer

signal transition_completed(scene_path: String)
signal transition_cancelled(scene_path: String)

const SettingsManagerScript = preload("res://scripts/game/settings/settings_manager.gd")

@export_range(0.0, 2.0, 0.05) var minimum_display_seconds := 0.35

@onready var _loading_overlay: Control = %LoadingOverlay

var _target_scene_path := ""
var _initial_status := ""
var _load_progress: Array = []
var _transition_started_msec := 0
var _busy := false
var _completing := false


func _ready() -> void:
	_loading_overlay.visible = false
	set_process(false)


func change_scene(
	scene_path: String,
	initial_status: String = "正在布设九路战场…"
) -> Error:
	if _busy:
		return ERR_BUSY
	if scene_path.is_empty():
		return ERR_INVALID_PARAMETER
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return ERR_FILE_NOT_FOUND

	_target_scene_path = scene_path
	_initial_status = initial_status
	_begin_threaded_load()
	return OK


func is_transitioning() -> bool:
	return _busy


func get_target_scene_path() -> String:
	return _target_scene_path


func _process(_delta: float) -> void:
	if not _busy or _completing or _target_scene_path.is_empty():
		return

	var status := ResourceLoader.load_threaded_get_status(
		_target_scene_path,
		_load_progress
	)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var ratio := float(_load_progress[0]) if not _load_progress.is_empty() else 0.0
			_loading_overlay.call(&"set_progress", clampf(ratio * 96.0, 0.0, 96.0))
		ResourceLoader.THREAD_LOAD_LOADED:
			_completing = true
			set_process(false)
			_complete_threaded_load.call_deferred()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			set_process(false)
			_show_load_failure("场景资源未能完成加载。")


func _input(event: InputEvent) -> void:
	if not _busy:
		return
	if (
		_loading_overlay.call(&"get_transition_state") == &"failure"
		and event.is_action_pressed(&"ui_cancel")
	):
		get_viewport().set_input_as_handled()
		_on_back_requested()
		return
	get_viewport().set_input_as_handled()


func _begin_threaded_load() -> void:
	_busy = true
	_completing = false
	_load_progress.clear()
	_transition_started_msec = Time.get_ticks_msec()
	_loading_overlay.call(&"set_reduced_motion", _is_reduced_motion_enabled())
	_loading_overlay.call(&"start_loading", _initial_status)
	var request_error := ResourceLoader.load_threaded_request(
		_target_scene_path,
		"PackedScene",
		true
	)
	if request_error != OK:
		_show_load_failure("无法发起场景加载：%s" % error_string(request_error))
		return
	set_process(true)


func _complete_threaded_load() -> void:
	var packed_scene := ResourceLoader.load_threaded_get(_target_scene_path) as PackedScene
	if packed_scene == null:
		_show_load_failure("加载结果不是可用的场景资源。")
		return

	_loading_overlay.call(&"set_progress", 100.0)
	_loading_overlay.call(&"set_status", "部署完成", true)
	var elapsed_seconds := float(Time.get_ticks_msec() - _transition_started_msec) / 1000.0
	var remaining_seconds := maxf(0.0, minimum_display_seconds - elapsed_seconds)
	if remaining_seconds > 0.0:
		await get_tree().create_timer(remaining_seconds, true, false, true).timeout

	var completed_path := _target_scene_path
	var change_error := get_tree().change_scene_to_packed(packed_scene)
	if change_error != OK:
		_show_load_failure("无法切换到目标场景：%s" % error_string(change_error))
		return

	await get_tree().scene_changed
	var exit_tween := _loading_overlay.call(&"play_exit") as Tween
	if exit_tween != null:
		await exit_tween.finished
	_reset_transition_state()
	transition_completed.emit(completed_path)


func _show_load_failure(detail: String) -> void:
	_completing = false
	set_process(false)
	_loading_overlay.call(
		&"show_failure",
		"加载失败",
		"未能抵达目标界面",
		detail
	)


func _on_retry_requested() -> void:
	if not _busy or _target_scene_path.is_empty():
		return
	_begin_threaded_load()


func _on_back_requested() -> void:
	if not _busy or _loading_overlay.call(&"get_transition_state") != &"failure":
		return
	_cancel_transition.call_deferred()


func _cancel_transition() -> void:
	var cancelled_path := _target_scene_path
	var exit_tween := _loading_overlay.call(&"play_exit") as Tween
	if exit_tween != null:
		await exit_tween.finished
	_reset_transition_state()
	transition_cancelled.emit(cancelled_path)


func _reset_transition_state() -> void:
	_busy = false
	_completing = false
	_target_scene_path = ""
	_initial_status = ""
	_load_progress.clear()
	set_process(false)


func _is_reduced_motion_enabled() -> bool:
	var settings_manager := get_node_or_null("/root/SettingsManager") as SettingsManagerScript
	return settings_manager != null and settings_manager.is_reduced_motion_enabled()
