extends SceneTree

const SETTINGS_SCENE := preload("res://scenes/game/frontend/settings_screen.tscn")
const SettingsManagerScript := preload("res://scripts/game/settings/settings_manager.gd")
const TEST_SETTINGS_PATH := "user://settings_screen_contract.cfg"
const TEST_PROGRESS_PATH := "user://settings_screen_progress_contract.cfg"
const VIEWPORTS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_files()
	var settings_manager := SettingsManagerScript.new(TEST_SETTINGS_PATH, false, TEST_PROGRESS_PATH)
	settings_manager.name = "SettingsManager"
	root.add_child(settings_manager)
	await process_frame

	var screen := SETTINGS_SCENE.instantiate() as Control
	root.add_child(screen)
	await process_frame
	await process_frame
	_expect(screen != null, "settings screen did not instantiate")
	if screen == null:
		_finish()
		return

	var source := FileAccess.get_file_as_string("res://scenes/game/frontend/settings_screen.tscn")
	_expect(
		screen.theme.resource_path == "res://resources/game/ui/themes/veilfront_ui_theme_v2.tres",
		"settings screen must use the rebuilt unified theme",
	)
	_expect(not source.contains("settings/png_v2"), "settings screen still depends on layout-defining PNG controls")
	_expect(not source.contains("StyleBoxTexture"), "settings scene must inherit its scalable surfaces from the shared Theme")
	_expect(screen.get_node("Background") is TextureRect, "settings background is missing")
	_expect(_is_scalable_surface(screen.get_node("%SettingsFrame"), &"panel"), "settings frame must use a scalable themed surface")

	var tabs := screen.get_node("%SettingsTabs") as TabContainer
	_expect(tabs != null and tabs.get_tab_count() == 3, "settings must keep three preference groups")
	if tabs != null and tabs.get_tab_count() == 3:
		_expect(tabs.get_tab_title(0) == "画面", "first settings tab must be 画面")
		_expect(tabs.get_tab_title(1) == "音频", "second settings tab must be 音频")
		_expect(tabs.get_tab_title(2) == "体验", "third settings tab must be 体验")
	_expect((screen.get_node("%WindowModeOption") as OptionButton).item_count == 2, "window mode options changed")
	_expect(
		(screen.get_node("%ResolutionOption") as OptionButton).item_count
		== SettingsManagerScript.SUPPORTED_RESOLUTIONS.size(),
		"resolution options must mirror SettingsManager",
	)
	for slider_name: String in ["MasterVolumeSlider", "MusicVolumeSlider", "SfxVolumeSlider"]:
		var slider := screen.get_node("%%%s" % slider_name) as HSlider
		_expect(slider != null and slider.max_value == 100.0, "%s must keep the 0-100 range" % slider_name)
		_expect(slider != null and slider.custom_minimum_size.y >= 44.0, "%s is below the interaction target" % slider_name)

	var expected_variations := {
		"BackButton": &"SecondaryButton",
		"RestoreDefaultsButton": &"SecondaryButton",
		"CancelButton": &"SecondaryButton",
		"ApplyButton": &"PrimaryButton",
		"ResetProgressButton": &"DangerButton",
	}
	for button_name: String in expected_variations:
		var button := screen.get_node("%%%s" % button_name) as Button
		_expect(button != null, "%s is missing" % button_name)
		if button == null:
			continue
		_expect(button.custom_minimum_size.y >= 44.0, "%s is below the interaction target" % button_name)
		_expect(button.has_method("set_reduced_motion"), "%s must use the reusable motion button" % button_name)
		_expect(button.theme_type_variation == expected_variations[button_name], "%s uses the wrong button role" % button_name)
		_expect(_is_scalable_surface(button, &"normal"), "%s must inherit a scalable themed surface" % button_name)

	for viewport_size: Vector2i in VIEWPORTS:
		root.size = viewport_size
		await process_frame
		await process_frame
		var logical_size := Vector2i(screen.get_viewport_rect().size)
		_assert_inside_viewport(screen.get_node("%SettingsFrame") as Control, logical_size, "settings frame")
		_assert_inside_viewport(screen.get_node("%BackButton") as Control, logical_size, "back button")
		_assert_inside_viewport(screen.get_node("%ApplyButton") as Control, logical_size, "apply button")

	screen.call("_restore_default_draft")
	_expect(
		(screen.get_node("%StatusLabel") as Label).text.contains("默认值"),
		"restore-default feedback is missing",
	)
	var draft: Dictionary = screen.call("_collect_draft")
	_expect(draft == SettingsManagerScript.default_settings(), "default draft no longer matches SettingsManager")
	screen.call("_apply_draft")
	await process_frame
	_expect(
		(screen.get_node("%StatusLabel") as Label).text.contains("已保存"),
		"applying unchanged settings must complete without a display confirmation",
	)

	screen.queue_free()
	await process_frame
	_remove_test_files()
	_finish()


func _is_scalable_surface(control: Control, style_name: StringName) -> bool:
	if control == null:
		return false
	var style := control.get_theme_stylebox(style_name)
	if style is StyleBoxFlat:
		return true
	if style is StyleBoxTexture:
		var textured := style as StyleBoxTexture
		return textured.texture != null \
			and textured.texture_margin_left > 0.0 \
			and textured.texture_margin_top > 0.0 \
			and textured.texture_margin_right > 0.0 \
			and textured.texture_margin_bottom > 0.0
	return false


func _assert_inside_viewport(control: Control, viewport_size: Vector2i, label: String) -> void:
	if control == null:
		_expect(false, "%s is missing" % label)
		return
	var rect := control.get_global_rect()
	_expect(rect.position.x >= -0.5 and rect.position.y >= -0.5, "%s starts outside %s" % [label, viewport_size])
	_expect(rect.end.x <= viewport_size.x + 0.5, "%s overflows width at %s" % [label, viewport_size])
	_expect(rect.end.y <= viewport_size.y + 0.5, "%s overflows height at %s" % [label, viewport_size])


func _remove_test_files() -> void:
	for path: String in [TEST_SETTINGS_PATH, TEST_PROGRESS_PATH]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SETTINGS_SCREEN_CONTRACT_PASS theme=unified viewports=3 controls=accessible")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("SETTINGS_SCREEN_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)
