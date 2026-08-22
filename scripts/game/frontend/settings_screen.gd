extends Control

const FrontendRoutes = preload("res://scripts/integration/frontend_routes.gd")
const SettingsManagerScript = preload("res://scripts/game/settings/settings_manager.gd")
const MOTION_PROFILE = preload("res://resources/game/ui/motion/terracotta_ui_motion_profile.tres")
const DISPLAY_CONFIRM_SECONDS := 10

@onready var _settings_frame: PanelContainer = %SettingsFrame
@onready var _settings_tabs: TabContainer = %SettingsTabs
@onready var _back_button: Button = %BackButton
@onready var _window_mode_option: OptionButton = %WindowModeOption
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _vsync_toggle: CheckButton = %VsyncToggle
@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
@onready var _music_volume_slider: HSlider = %MusicVolumeSlider
@onready var _sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var _master_volume_value: Label = %MasterVolumeValue
@onready var _music_volume_value: Label = %MusicVolumeValue
@onready var _sfx_volume_value: Label = %SfxVolumeValue
@onready var _skip_opening_toggle: CheckButton = %SkipOpeningToggle
@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var _reset_progress_button: Button = %ResetProgressButton
@onready var _restore_defaults_button: Button = %RestoreDefaultsButton
@onready var _cancel_button: Button = %CancelButton
@onready var _apply_button: Button = %ApplyButton
@onready var _status_label: Label = %StatusLabel
@onready var _display_confirm_dialog: ConfirmationDialog = %DisplayConfirmDialog
@onready var _display_confirm_timer: Timer = %DisplayConfirmTimer
@onready var _reset_progress_dialog: ConfirmationDialog = %ResetProgressDialog
@onready var _error_dialog: AcceptDialog = %ErrorDialog

var _display_seconds_remaining := 0
var _transitioning := false
var _settings_manager: SettingsManagerScript
var _entry_tween: Tween
var _tab_tween: Tween
var _exit_tween: Tween


func _ready() -> void:
	_settings_manager = get_node("/root/SettingsManager") as SettingsManagerScript
	_back_button.pressed.connect(_return_to_menu)
	_restore_defaults_button.pressed.connect(_restore_default_draft)
	_cancel_button.pressed.connect(_return_to_menu)
	_apply_button.pressed.connect(_apply_draft)
	_reset_progress_button.pressed.connect(_reset_progress_dialog.popup_centered)
	_reset_progress_dialog.confirmed.connect(_reset_level_progress)
	_window_mode_option.item_selected.connect(func(_index: int) -> void: _update_resolution_availability())
	_master_volume_slider.value_changed.connect(
		func(value: float) -> void: _update_volume_label(_master_volume_value, value)
	)
	_music_volume_slider.value_changed.connect(
		func(value: float) -> void: _update_volume_label(_music_volume_value, value)
	)
	_sfx_volume_slider.value_changed.connect(
		func(value: float) -> void: _update_volume_label(_sfx_volume_value, value)
	)
	_settings_tabs.tab_changed.connect(_on_settings_tab_changed)
	_reduce_motion_toggle.toggled.connect(_on_reduce_motion_toggled)
	_display_confirm_dialog.confirmed.connect(_confirm_display_preview)
	_display_confirm_dialog.canceled.connect(_revert_display_preview)
	_display_confirm_dialog.close_requested.connect(_revert_display_preview)
	_display_confirm_timer.timeout.connect(_on_display_confirm_tick)
	_display_confirm_dialog.get_ok_button().text = "保留设置"
	_display_confirm_dialog.get_cancel_button().text = "恢复原设置"
	_populate_controls(_settings_manager.get_settings())
	_set_reduced_motion(_reduce_motion_toggle.button_pressed)
	_back_button.grab_focus()
	_play_entrance.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not _display_confirm_dialog.visible:
		get_viewport().set_input_as_handled()
		_return_to_menu()


func _populate_controls(settings: Dictionary) -> void:
	_window_mode_option.select(1 if settings["window_mode"] == "fullscreen" else 0)
	var resolution_index := SettingsManagerScript.SUPPORTED_RESOLUTIONS.find(settings["resolution"])
	_resolution_option.select(maxi(resolution_index, 0))
	_vsync_toggle.button_pressed = bool(settings["vsync"])
	_master_volume_slider.value = float(settings["master_volume"]) * 100.0
	_music_volume_slider.value = float(settings["music_volume"]) * 100.0
	_sfx_volume_slider.value = float(settings["sfx_volume"]) * 100.0
	_skip_opening_toggle.button_pressed = bool(settings["skip_opening"])
	_reduce_motion_toggle.button_pressed = bool(settings["reduce_motion"])
	_update_volume_label(_master_volume_value, _master_volume_slider.value)
	_update_volume_label(_music_volume_value, _music_volume_slider.value)
	_update_volume_label(_sfx_volume_value, _sfx_volume_slider.value)
	_update_resolution_availability()


func _collect_draft() -> Dictionary:
	return {
		"window_mode": "fullscreen" if _window_mode_option.selected == 1 else "windowed",
		"resolution": SettingsManagerScript.SUPPORTED_RESOLUTIONS[_resolution_option.selected],
		"vsync": _vsync_toggle.button_pressed,
		"master_volume": _master_volume_slider.value / 100.0,
		"music_volume": _music_volume_slider.value / 100.0,
		"sfx_volume": _sfx_volume_slider.value / 100.0,
		"skip_opening": _skip_opening_toggle.button_pressed,
		"reduce_motion": _reduce_motion_toggle.button_pressed,
	}


func _restore_default_draft() -> void:
	_populate_controls(SettingsManagerScript.default_settings())
	_status_label.text = "已载入默认值，点击“应用”后生效"


func _apply_draft() -> void:
	var display_changed := _settings_manager.begin_preview(_collect_draft())
	if display_changed:
		_display_seconds_remaining = DISPLAY_CONFIRM_SECONDS
		_update_display_confirm_text()
		_display_confirm_timer.start()
		_display_confirm_dialog.popup_centered()
		return
	_commit_preview()


func _confirm_display_preview() -> void:
	_display_confirm_timer.stop()
	_commit_preview()


func _commit_preview() -> void:
	var save_error := _settings_manager.commit_preview()
	if save_error != OK:
		_show_error("设置保存失败：%s" % error_string(save_error))
		_populate_controls(_settings_manager.get_settings())
		return
	_status_label.text = "设置已保存并生效"


func _revert_display_preview() -> void:
	_display_confirm_timer.stop()
	if _display_confirm_dialog.visible:
		_display_confirm_dialog.hide()
	_settings_manager.revert_preview()
	_populate_controls(_settings_manager.get_settings())
	_status_label.text = "显示设置未确认，已恢复原设置"


func _on_display_confirm_tick() -> void:
	_display_seconds_remaining -= 1
	if _display_seconds_remaining <= 0:
		_revert_display_preview()
		return
	_update_display_confirm_text()


func _update_display_confirm_text() -> void:
	_display_confirm_dialog.dialog_text = (
		"新的显示设置是否正常？\n%d 秒后将自动恢复原设置。" % _display_seconds_remaining
	)


func _reset_level_progress() -> void:
	var reset_error := _settings_manager.reset_level_progress()
	if reset_error != OK:
		_show_error("关卡进度重置失败：%s" % error_string(reset_error))
		return
	_status_label.text = "教学与挑战关卡进度已重置"


func _update_resolution_availability() -> void:
	var is_windowed := _window_mode_option.selected == 0
	_resolution_option.disabled = not is_windowed
	_resolution_option.tooltip_text = "仅窗口模式可选择分辨率" if not is_windowed else "窗口模式分辨率"


func _update_volume_label(label: Label, value: float) -> void:
	label.text = "%d%%" % int(round(value))


func _on_settings_tab_changed(tab_index: int) -> void:
	var tab_control := _settings_tabs.get_tab_control(tab_index)
	if tab_control == null:
		return
	_reset_control_motion(tab_control)
	if _reduce_motion_toggle.button_pressed:
		return
	_kill_tween(_tab_tween)
	tab_control.offset_transform_enabled = true
	tab_control.offset_transform_visual_only = true
	tab_control.offset_transform_position = Vector2(12.0, 0.0)
	tab_control.modulate = Color(1, 1, 1, 0.42)
	_tab_tween = _new_motion_tween()
	_tab_tween.set_parallel(true)
	_tab_tween.tween_property(
		tab_control, "offset_transform_position", Vector2.ZERO, _motion_duration(&"tab")
	)
	_tab_tween.tween_property(tab_control, "modulate", Color.WHITE, _motion_duration(&"tab"))


func _on_reduce_motion_toggled(enabled: bool) -> void:
	_set_reduced_motion(enabled)


func _set_reduced_motion(enabled: bool) -> void:
	for candidate: Node in get_tree().get_nodes_in_group(&"ui_motion_buttons"):
		if is_ancestor_of(candidate) and candidate.has_method("set_reduced_motion"):
			candidate.call("set_reduced_motion", enabled)
	if not enabled:
		return
	_kill_tween(_entry_tween)
	_kill_tween(_tab_tween)
	_kill_tween(_exit_tween)
	_reset_control_motion(_settings_frame)
	for tab_index: int in _settings_tabs.get_tab_count():
		_reset_control_motion(_settings_tabs.get_tab_control(tab_index))


func _play_entrance() -> void:
	_reset_control_motion(_settings_frame)
	if _reduce_motion_toggle.button_pressed:
		return
	_kill_tween(_entry_tween)
	_settings_frame.offset_transform_enabled = true
	_settings_frame.offset_transform_visual_only = true
	_settings_frame.offset_transform_position = Vector2(0.0, 18.0)
	_settings_frame.offset_transform_scale = Vector2(0.992, 0.992)
	_settings_frame.modulate = Color(1, 1, 1, 0)
	_entry_tween = _new_motion_tween()
	_entry_tween.set_parallel(true)
	_entry_tween.tween_property(
		_settings_frame, "offset_transform_position", Vector2.ZERO, _motion_duration(&"entrance")
	)
	_entry_tween.tween_property(
		_settings_frame, "offset_transform_scale", Vector2.ONE, _motion_duration(&"entrance")
	)
	_entry_tween.tween_property(
		_settings_frame, "modulate", Color.WHITE, _motion_duration(&"entrance")
	)


func _play_exit_transition() -> void:
	if _reduce_motion_toggle.button_pressed:
		return
	_kill_tween(_exit_tween)
	_exit_tween = _new_motion_tween()
	_exit_tween.set_parallel(true)
	_exit_tween.tween_property(
		_settings_frame, "offset_transform_position", Vector2(0.0, 12.0), 0.16
	)
	_exit_tween.tween_property(_settings_frame, "modulate", Color(1, 1, 1, 0), 0.16)
	await _exit_tween.finished


func _new_motion_tween() -> Tween:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	return tween


func _motion_duration(group: StringName) -> float:
	return MOTION_PROFILE.duration_for(group, _reduce_motion_toggle.button_pressed)


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _reset_control_motion(control: Control) -> void:
	if not is_instance_valid(control):
		return
	control.offset_transform_enabled = true
	control.offset_transform_visual_only = true
	control.offset_transform_position = Vector2.ZERO
	control.offset_transform_scale = Vector2.ONE
	control.modulate = Color.WHITE


func _set_interactions_enabled(enabled: bool) -> void:
	for candidate: Node in find_children("*", "BaseButton", true, false):
		(candidate as BaseButton).disabled = not enabled
	for slider: HSlider in [
		_master_volume_slider, _music_volume_slider, _sfx_volume_slider,
	]:
		slider.editable = enabled
	_settings_tabs.tab_focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	_settings_tabs.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if enabled:
		_update_resolution_availability()


func _show_error(message: String) -> void:
	_error_dialog.dialog_text = message
	_error_dialog.popup_centered()


func _return_to_menu() -> void:
	if _transitioning:
		return
	if _settings_manager.is_preview_active():
		_settings_manager.revert_preview()
	_transitioning = true
	_set_interactions_enabled(false)
	await _play_exit_transition()
	var transition := FrontendRoutes.transition_service(get_tree())
	if transition != null:
		transition.connect(
			&"transition_cancelled",
			_on_return_transition_cancelled,
			CONNECT_ONE_SHOT
		)
	var error := FrontendRoutes.navigate(
		get_tree(),
		FrontendRoutes.request_start_menu_ready(),
		"正在返回烽火关城…"
	)
	if error != OK:
		if (
			transition != null
			and transition.is_connected(&"transition_cancelled", _on_return_transition_cancelled)
		):
			transition.disconnect(&"transition_cancelled", _on_return_transition_cancelled)
		_transitioning = false
		_set_interactions_enabled(true)
		_reset_control_motion(_settings_frame)
		_show_error("无法返回主菜单：%s" % error_string(error))


func _on_return_transition_cancelled(_scene_path: String) -> void:
	_transitioning = false
	_set_interactions_enabled(true)
	_reset_control_motion(_settings_frame)
	_play_entrance()
