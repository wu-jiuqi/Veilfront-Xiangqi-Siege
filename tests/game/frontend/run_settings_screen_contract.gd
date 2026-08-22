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
	assert(
		settings_screen.get_node("SafeMargin/SettingsFrame/ContentMargin/ContentColumn/SettingsTabsCenter")
		is HBoxContainer
	)
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
	assert(settings_screen.get_node("%ResetProgressButton").theme_type_variation == &"SettingsPngDangerButton")
	assert(settings_screen.get_node("%DisplayConfirmTimer").wait_time == 1.0)
	assert(settings_screen.get_node("%DisplayConfirmDialog").dialog_text.contains("10"))
	for button_name: String in ["BackButton", "RestoreDefaultsButton", "CancelButton", "ApplyButton", "ResetProgressButton"]:
		var button := settings_screen.get_node("%%%s" % button_name) as Button
		assert(button.custom_minimum_size.y >= 44.0, "%s must remain keyboard/touch accessible" % button_name)
		assert(button.alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s text must stay centered in its PNG surface" % button_name)
		assert(button.has_method("set_reduced_motion"), "%s must use the reusable motion-button preset" % button_name)
		assert(button.offset_transform_enabled, "%s must use visual-only offset transforms" % button_name)
		var normal_style := button.get_theme_stylebox(&"normal") as StyleBoxTexture
		assert(is_equal_approx(normal_style.content_margin_left, normal_style.content_margin_right))
		assert(is_equal_approx(normal_style.content_margin_top, normal_style.content_margin_bottom))
		for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
			_assert_texture_style_fits_control(button, button.get_theme_stylebox(style_name) as StyleBoxTexture)
	assert(settings_screen.get_node("%BackButton").theme_type_variation == &"SettingsPngSecondaryButton")
	assert(settings_screen.get_node("%ApplyButton").theme_type_variation == &"SettingsPngPrimaryButton")
	var settings_panel_style := (settings_screen.get_node("%SettingsFrame") as PanelContainer).get_theme_stylebox(&"panel") as StyleBoxTexture
	assert(settings_panel_style.texture.resource_path == "res://assets/art/ui/settings/png_v2/settings_frame_v2.png")
	var secondary_style := (settings_screen.get_node("%BackButton") as Button).get_theme_stylebox(&"normal") as StyleBoxTexture
	assert(secondary_style.texture.resource_path == "res://assets/art/ui/settings/png_v2/settings_button_secondary_v2.png")
	var primary_style := (settings_screen.get_node("%ApplyButton") as Button).get_theme_stylebox(&"normal") as StyleBoxTexture
	assert(primary_style.texture.resource_path == "res://assets/art/ui/settings/png_v2/settings_button_secondary_v2.png")
	var tabs := settings_screen.get_node("%SettingsTabs") as TabContainer
	var active_tab_style := tabs.get_theme_stylebox(&"tab_selected") as StyleBoxTexture
	var inactive_tab_style := tabs.get_theme_stylebox(&"tab_unselected") as StyleBoxTexture
	assert(active_tab_style.texture.resource_path == "res://assets/art/ui/settings/png_v2/settings_tab_active_v2.png")
	assert(inactive_tab_style.texture.resource_path == "res://assets/art/ui/settings/png_v2/settings_tab_inactive_v2.png")
	var option_style := (settings_screen.get_node("%WindowModeOption") as OptionButton).get_theme_stylebox(&"normal") as StyleBoxTexture
	assert(option_style.texture.resource_path == "res://assets/art/ui/settings/png_v2/settings_option_field_v2.png")
	for option_name: String in ["WindowModeOption", "ResolutionOption"]:
		var option := settings_screen.get_node("%%%s" % option_name) as OptionButton
		for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
			_assert_texture_style_fits_control(option, option.get_theme_stylebox(style_name) as StyleBoxTexture)
	var slider := settings_screen.get_node("%MasterVolumeSlider") as HSlider
	var slider_style := slider.get_theme_stylebox(&"slider") as StyleBoxTexture
	assert(slider_style.texture.resource_path == "res://assets/art/ui/settings/png_v2/settings_slider_track_v2.png")
	assert(slider.get_theme_icon(&"grabber").resource_path == "res://assets/art/ui/settings/png_v2/settings_slider_knob_v2.png")
	var toggle := settings_screen.get_node("%VsyncToggle") as CheckButton
	assert(toggle.get_theme_icon(&"checked").resource_path == "res://assets/art/ui/settings/png_v2/settings_checkbox_checked_v2.png")
	assert(toggle.get_theme_icon(&"unchecked").resource_path == "res://assets/art/ui/settings/png_v2/settings_checkbox_empty_v2.png")
	for texture_path: String in [
		"res://assets/art/ui/settings/png_v2/settings_frame_v2.png",
		"res://assets/art/ui/settings/png_v2/settings_button_secondary_v2.png",
		"res://assets/art/ui/settings/png_v2/settings_tab_active_v2.png",
		"res://assets/art/ui/settings/png_v2/settings_tab_inactive_v2.png",
		"res://assets/art/ui/settings/png_v2/settings_option_field_v2.png",
		"res://assets/art/ui/settings/png_v2/settings_slider_track_v2.png",
		"res://assets/art/ui/settings/png_v2/settings_slider_knob_v2.png",
		"res://assets/art/ui/settings/png_v2/settings_checkbox_checked_v2.png",
		"res://assets/art/ui/settings/png_v2/settings_checkbox_empty_v2.png",
		"res://assets/art/ui/settings/png_v2/settings_dropdown_arrow_v2.png",
		"res://assets/art/ui/settings/png_v2/settings_title_crest_v2.png",
	]:
		_assert_true_alpha(texture_path)
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
		var responsive_tabs := responsive_screen.get_node("%SettingsTabs") as Control
		var tabs_host := responsive_screen.get_node(
			"SafeMargin/SettingsFrame/ContentMargin/ContentColumn/SettingsTabsCenter"
		) as Control
		var tabs_rect := responsive_tabs.get_global_rect()
		var tabs_host_rect := tabs_host.get_global_rect()
		assert(
			absf(tabs_rect.get_center().x - tabs_host_rect.get_center().x) <= 1.0,
			"%s settings tabs must stay horizontally centered: tabs=%s host=%s"
			% [viewport_size, tabs_rect, tabs_host_rect]
		)
		assert(tabs_rect.size.x <= 900.0, "%s settings tabs width must respect the desktop cap" % viewport_size)
		assert(
			tabs_rect.size.x >= minf(900.0, tabs_host_rect.size.x * 0.95),
			"%s settings tabs must remain usable on narrow viewports: tabs=%s host=%s"
			% [viewport_size, tabs_rect, tabs_host_rect]
		)
		viewport.queue_free()
		await process_frame

	var menu_script := FileAccess.get_file_as_string("res://scripts/game/frontend/start_menu_overlay.gd")
	assert(menu_script.contains("FrontendRoutes.settings_scene()"))
	assert(not menu_script.contains("设置功能尚未开放"))
	print("SETTINGS_SCREEN_CONTRACT_PASS tabs=3 controls=12 buttons=motion-preset png=chroma-keyed background=shared resolutions=3 route=connected")
	quit()


func _assert_true_alpha(texture_path: String) -> void:
	var texture := load(texture_path) as Texture2D
	assert(texture != null, "%s must import as Texture2D" % texture_path)
	var image := texture.get_image()
	assert(image != null and not image.is_empty(), "%s must expose imported pixels" % texture_path)
	assert(image.detect_alpha() != Image.ALPHA_NONE, "%s must retain a real alpha channel" % texture_path)
	var has_transparent_border_pixel := false
	for x: int in image.get_width():
		if image.get_pixel(x, 0).a < 0.05 or image.get_pixel(x, image.get_height() - 1).a < 0.05:
			has_transparent_border_pixel = true
			break
	if not has_transparent_border_pixel:
		for y: int in image.get_height():
			if image.get_pixel(0, y).a < 0.05 or image.get_pixel(image.get_width() - 1, y).a < 0.05:
				has_transparent_border_pixel = true
				break
	assert(has_transparent_border_pixel, "%s must retain chroma-key transparency around its silhouette" % texture_path)


func _assert_texture_style_fits_control(control: Control, style: StyleBoxTexture) -> void:
	assert(style != null, "%s must use a StyleBoxTexture" % control.name)
	var horizontal_margins := style.texture_margin_left + style.texture_margin_right
	var vertical_margins := style.texture_margin_top + style.texture_margin_bottom
	assert(
		horizontal_margins <= control.size.x,
		"%s PNG margins %.1f exceed control width %.1f" % [control.name, horizontal_margins, control.size.x]
	)
	assert(
		vertical_margins <= control.size.y,
		"%s PNG margins %.1f exceed control height %.1f" % [control.name, vertical_margins, control.size.y]
	)
