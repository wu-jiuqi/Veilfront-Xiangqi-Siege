extends SceneTree

const SETTINGS_SCENE := preload("res://scenes/game/frontend/settings_screen.tscn")
const MATCH_SCENE := preload("res://scenes/game/match/match_screen.tscn")
const SettingsManagerScript := preload("res://scripts/game/settings/settings_manager.gd")
const TEST_SETTINGS_PATH := "user://settings_screen_contract.cfg"
const TEST_PROGRESS_PATH := "user://settings_screen_progress_contract.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
]


func _init() -> void:
	var settings_manager := SettingsManagerScript.new(TEST_SETTINGS_PATH, false, TEST_PROGRESS_PATH)
	settings_manager.name = "SettingsManager"
	root.add_child(settings_manager)
	await process_frame
	var settings_screen := SETTINGS_SCENE.instantiate() as Control
	root.add_child(settings_screen)
	await process_frame
	await process_frame

	assert(settings_screen.theme.resource_path == "res://resources/game/ui/themes/terracotta_ui_theme.tres")
	assert(
		settings_screen.get_node("Background/Environment").texture.resource_path
		== "res://assets/art/backgrounds/battle_command_tent_background_v1.png"
	)
	assert(settings_screen.get_node("%SettingsTabs") is TabContainer)
	assert(settings_screen.get_node("%SettingsTabs").get_tab_count() == 3)
	assert(settings_screen.get_node("%SettingsTabs").get_tab_title(0) == "画面")
	assert(settings_screen.get_node("%SettingsTabs").get_tab_title(1) == "音频")
	assert(settings_screen.get_node("%SettingsTabs").get_tab_title(2) == "体验")
	assert(settings_screen.get_node("%WindowModeOption").item_count == 2)
	assert(settings_screen.get_node("%ResolutionOption").item_count == 3)
	assert(settings_screen.get_node("%MasterVolumeSlider").max_value == 100.0)
	assert(settings_screen.get_node("%MusicVolumeSlider").max_value == 100.0)
	assert(settings_screen.get_node("%SfxVolumeSlider").max_value == 100.0)
	assert(settings_screen.get_node("%SkipOpeningToggle") is CheckButton)
	assert(settings_screen.get_node("%ReduceMotionToggle") is CheckButton)
	assert(settings_screen.get_node("%ResetProgressButton").theme_type_variation == &"DangerButton")
	assert(settings_screen.get_node("%DisplayConfirmTimer").wait_time == 1.0)
	assert(settings_screen.get_node("%DisplayConfirmDialog").dialog_text.contains("10"))
	for button_name: String in ["BackButton", "RestoreDefaultsButton", "CancelButton", "ApplyButton", "ResetProgressButton"]:
		var button := settings_screen.get_node("%%%s" % button_name) as Button
		assert(button.custom_minimum_size.y >= 44.0, "%s must remain keyboard/touch accessible" % button_name)
		assert(button.has_method("set_reduced_motion"), "%s must use the reusable motion-button preset" % button_name)
		assert(button.offset_transform_enabled, "%s must use visual-only offset transforms" % button_name)
	assert(settings_screen.get_node("%BackButton").theme_type_variation == &"SettingsSecondaryButton")
	assert(settings_screen.get_node("%ApplyButton").theme_type_variation == &"SettingsPrimaryButton")
	var settings_panel_style := (settings_screen.get_node("%SettingsFrame") as PanelContainer).get_theme_stylebox(&"panel") as StyleBoxTexture
	assert(settings_panel_style.texture.resource_path == "res://assets/art/ui/settings/settings_panel_9slice_v1.png")
	var secondary_style := (settings_screen.get_node("%BackButton") as Button).get_theme_stylebox(&"normal") as StyleBoxTexture
	assert(secondary_style.texture.resource_path == "res://assets/art/ui/settings/settings_button_secondary_v1.png")
	var primary_style := (settings_screen.get_node("%ApplyButton") as Button).get_theme_stylebox(&"normal") as StyleBoxTexture
	assert(primary_style.texture.resource_path == "res://assets/art/ui/settings/settings_button_primary_v1.png")
	(settings_screen.get_node("%MasterVolumeSlider") as HSlider).value = 17.0
	(settings_screen.get_node("%RestoreDefaultsButton") as Button).pressed.emit()
	assert(is_equal_approx((settings_screen.get_node("%MasterVolumeSlider") as HSlider).value, 100.0))
	var window_mode_option := settings_screen.get_node("%WindowModeOption") as OptionButton
	var resolution_option := settings_screen.get_node("%ResolutionOption") as OptionButton
	window_mode_option.select(0)
	window_mode_option.item_selected.emit(0)
	resolution_option.select(1)
	(settings_screen.get_node("%ApplyButton") as Button).pressed.emit()
	await process_frame
	var display_dialog := settings_screen.get_node("%DisplayConfirmDialog") as ConfirmationDialog
	assert(display_dialog.visible, "display changes must open the ten-second confirmation")
	assert(settings_manager.is_preview_active())
	display_dialog.canceled.emit()
	await process_frame
	assert(not settings_manager.is_preview_active())
	assert(settings_manager.get_settings()["window_mode"] == "fullscreen")

	settings_screen.queue_free()
	await process_frame
	var match_screen := MATCH_SCENE.instantiate()
	assert(
		match_screen.get_node("Backdrop/Environment").texture.resource_path
		== "res://assets/art/backgrounds/battle_command_tent_background_v1.png"
	)
	match_screen.free()

	for viewport_size: Vector2i in RESOLUTIONS:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		root.add_child(viewport)
		var responsive_screen := SETTINGS_SCENE.instantiate() as Control
		viewport.add_child(responsive_screen)
		await process_frame
		await process_frame
		assert(responsive_screen.size.round() == Vector2(viewport_size))
		var frame := responsive_screen.get_node("%SettingsFrame") as Control
		var frame_rect := frame.get_global_rect()
		assert(frame_rect.position.x >= 0.0, "%s frame left=%s" % [viewport_size, frame_rect])
		assert(frame_rect.position.y >= 0.0, "%s frame top=%s min=%s" % [viewport_size, frame_rect, frame.get_combined_minimum_size()])
		assert(frame_rect.end.x <= viewport_size.x, "%s frame right=%s" % [viewport_size, frame_rect])
		assert(frame_rect.end.y <= viewport_size.y, "%s frame bottom=%s" % [viewport_size, frame_rect])
		viewport.queue_free()
		await process_frame

	var menu_script := FileAccess.get_file_as_string("res://scripts/game/frontend/start_menu_overlay.gd")
	assert(menu_script.contains("FrontendRoutes.settings_scene()"))
	assert(not menu_script.contains("设置功能尚未开放"))
	print("SETTINGS_SCREEN_CONTRACT_PASS tabs=3 controls=12 buttons=motion-preset background=shared resolutions=3 route=connected")
	quit()
