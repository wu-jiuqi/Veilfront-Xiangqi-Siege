extends SceneTree

const THEME_PATH := "res://resources/game/ui/themes/veilfront_ui_theme_v2.tres"
const GALLERY_PATH := "res://scenes/dev/ui/ui_complete_rebuild_gallery.tscn"
const SURFACES: Array[StringName] = [
	&"PageSurface", &"PrimarySurface", &"SecondarySurface",
	&"InsetSurface", &"OverlaySurface", &"DangerSurface",
	&"CalloutSurface", &"WarningSurface", &"PauseOverlaySurface",
]
const BUTTONS: Array[StringName] = [
	&"PrimaryButton", &"ConfirmButton", &"SecondaryButton",
	&"GhostButton", &"DangerButton", &"CompactButton",
]
const LABELS := {
	&"DisplayTitle": 42,
	&"ScreenTitle": 32,
	&"SectionTitle": 19,
	&"BodyText": 16,
	&"SecondaryText": 14,
	&"NumericText": 20,
}
const VIEWPORTS: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1280, 720),
	Vector2i(1920, 1080), Vector2i(2560, 1080),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var theme := load(THEME_PATH) as Theme
	_expect(theme != null, "统一 Theme 无法加载")
	if theme != null:
		for surface: StringName in SURFACES:
			_expect(theme.get_type_variation_base(surface) == &"PanelContainer", "表面变体缺失：%s" % surface)
			_expect(theme.has_stylebox(&"panel", surface), "表面样式缺失：%s" % surface)
		_expect(theme.get_stylebox(&"panel", &"PageSurface") is StyleBoxTexture, "页面必须使用风格化可缩放材质框")
		_expect(theme.get_stylebox(&"panel", &"OverlaySurface") is StyleBoxTexture, "模态必须使用风格化可缩放材质框")
		_expect(theme.get_stylebox(&"panel", &"PrimarySurface") is StyleBoxFlat, "任务区必须使用克制的平面承载层")
		_expect(theme.get_stylebox(&"panel", &"SecondarySurface") is StyleBoxFlat, "普通栏目不得与页面外框争夺装饰层级")
		for button: StringName in BUTTONS:
			_expect(theme.get_type_variation_base(button) == &"Button", "按钮变体缺失：%s" % button)
			for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
				_expect(theme.has_stylebox(state, button), "按钮状态缺失：%s/%s" % [button, state])
		for label: StringName in LABELS:
			_expect(theme.get_type_variation_base(label) == &"Label", "文字变体缺失：%s" % label)
			_expect(theme.get_font_size(&"font_size", label) == int(LABELS[label]), "字号不匹配：%s" % label)
		_expect(
			theme.get_font(&"font", &"ScreenTitle").resource_path.contains("ramega_zhang_qingping"),
			"页面题签必须使用受控的书法字体",
		)
		_expect(
			theme.get_font(&"font", &"SectionTitle").resource_path.ends_with("noto_sans_sc_semibold.tres"),
			"栏目标题必须回到高可读黑体",
		)
		var reading_surface := theme.get_stylebox(&"panel", &"SecondarySurface") as StyleBoxFlat
		_expect(
			_contrast_ratio(theme.get_color(&"font_color", &"BodyText"), reading_surface.bg_color) >= 4.5,
			"正文与普通承载面的对比度低于 4.5:1",
		)
		_expect(
			_contrast_ratio(theme.get_color(&"font_color", &"SecondaryText"), reading_surface.bg_color) >= 4.5,
			"辅助文字与普通承载面的对比度低于 4.5:1",
		)
	await _check_gallery()
	_finish()


func _check_gallery() -> void:
	var packed := load(GALLERY_PATH) as PackedScene
	_expect(packed != null, "设计系统样片无法加载")
	if packed == null:
		return
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var gallery := packed.instantiate() as Control
	viewport.add_child(gallery)
	for viewport_size: Vector2i in VIEWPORTS:
		viewport.size = viewport_size
		for _frame: int in 3:
			await process_frame
		var bounds := Rect2(Vector2.ZERO, Vector2(viewport_size)).grow(0.5)
		_expect(bounds.encloses(gallery.get_node("Background").get_global_rect()), "背景未填满：%s" % viewport_size)
		_expect(bounds.encloses(gallery.get_node("SafeMargin/Page").get_global_rect()), "页面表面被裁切：%s" % viewport_size)
		for node: Node in gallery.get_tree().get_nodes_in_group("ui_motion_buttons"):
			if not gallery.is_ancestor_of(node):
				continue
			var button := node as Button
			_expect(button.size.y >= 44.0, "按钮低于 44 px：%s @ %s" % [button.name, viewport_size])
			_expect(bounds.encloses(button.get_global_rect()), "按钮被裁切：%s @ %s" % [button.name, viewport_size])
	gallery.queue_free()
	viewport.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("UI_COMPLETE_REBUILD_FOUNDATION_PASS surfaces=9 buttons=6 labels=6 viewports=4 hierarchy=v3")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("UI_COMPLETE_REBUILD_FOUNDATION_FAIL failures=%d" % _failures.size())
	quit(1)


func _contrast_ratio(foreground: Color, background: Color) -> float:
	var foreground_luminance := _relative_luminance(foreground)
	var background_luminance := _relative_luminance(background)
	return (maxf(foreground_luminance, background_luminance) + 0.05) \
		/ (minf(foreground_luminance, background_luminance) + 0.05)


func _relative_luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
