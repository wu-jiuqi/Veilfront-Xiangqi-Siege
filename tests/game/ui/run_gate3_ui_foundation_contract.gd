extends SceneTree

const LAB_SCENE_PATH := "res://scenes/dev/ui/gate3_ui_foundation_lab.tscn"
const THEME_PATH := "res://resources/game/ui/themes/veilfront_ui_theme_v2.tres"
const PROFILE_PATH := "res://resources/game/ui/motion/terracotta_ui_motion_profile.tres"
const SCREENSHOT_PATH := "res://evidence/gate3/ui/gate3-ui-foundation-lab-1280x720.png"
const BUTTON_GRID_PATH := "SafeMargin/Center/FoundationPanel/PanelMargin/Content/ButtonGrid"

const VARIANTS := {
	&"primary": {
		"path": "res://scenes/game/ui/ui_motion_button_primary.tscn",
		"theme": &"PrimaryButton",
	},
	&"secondary": {
		"path": "res://scenes/game/ui/ui_motion_button_secondary.tscn",
		"theme": &"SecondaryButton",
	},
	&"danger": {
		"path": "res://scenes/game/ui/ui_motion_button_danger.tscn",
		"theme": &"DangerButton",
	},
	&"confirm": {
		"path": "res://scenes/game/ui/ui_motion_button_confirm.tscn",
		"theme": &"ConfirmButton",
	},
}

const TEXT_ROLES := {
	&"DisplayTitle": 38,
	&"ScreenTitle": 28,
	&"SectionTitle": 20,
	&"BodyText": 16,
	&"SecondaryText": 14,
	&"NumericText": 22,
}

const VIEWPORTS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var theme := load(THEME_PATH) as Theme
	_expect(theme != null, "GATE-3 UI Theme 无法加载")
	if theme != null:
		_check_theme(theme)
	_check_motion_profile()
	await _check_variant_scenes()
	await _check_lab()
	_finish()


func _check_theme(theme: Theme) -> void:
	for data: Dictionary in VARIANTS.values():
		var variation: StringName = data["theme"]
		_expect(theme.get_type_variation_base(variation) == &"Button", "按钮 Theme 角色缺失：%s" % variation)
		for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			_expect(theme.has_stylebox(style_name, variation), "按钮状态样式缺失：%s/%s" % [variation, style_name])
	for role: StringName in TEXT_ROLES:
		_expect(theme.get_type_variation_base(role) == &"Label", "文本 Theme 角色缺失：%s" % role)
		_expect(theme.get_font_size(&"font_size", role) == int(TEXT_ROLES[role]), "文本字号错误：%s" % role)


func _check_motion_profile() -> void:
	var profile := load(PROFILE_PATH)
	_expect(profile != null, "共享 motion profile 无法加载")
	if profile == null:
		return
	_expect(is_equal_approx(profile.duration_for(&"hover"), 0.14), "Hover 时序必须为 140 ms")
	_expect(is_equal_approx(profile.duration_for(&"press"), 0.08), "Press 时序必须为 80 ms")
	_expect(is_equal_approx(profile.duration_for(&"focus"), 0.16), "Focus 时序必须为 160 ms")


func _check_variant_scenes() -> void:
	for role: StringName in VARIANTS:
		var data: Dictionary = VARIANTS[role]
		var scene := load(str(data["path"])) as PackedScene
		_expect(scene != null, "独立按钮预置无法加载：%s" % role)
		if scene == null:
			continue
		var button := scene.instantiate() as Button
		_expect(button != null, "按钮预置根节点必须是 Button：%s" % role)
		if button == null:
			continue
		root.add_child(button)
		await process_frame
		_expect(button.scene_file_path == str(data["path"]), "按钮预置不是独立 PackedScene：%s" % role)
		_expect(button.focus_mode == Control.FOCUS_ALL, "按钮必须允许键盘/手柄焦点：%s" % role)
		_expect(button.custom_minimum_size.y >= 48.0, "按钮最小高度低于 48：%s" % role)
		_expect(button.get("motion_profile") != null, "按钮缺少共享 motion profile：%s" % role)
		_expect(button.get("semantic_role") == role, "按钮语义角色错误：%s" % role)
		_expect(button.theme_type_variation == data["theme"], "按钮 Theme 角色错误：%s" % role)
		_expect(is_equal_approx(float(button.call("_release_duration")), 0.12), "Release 时序必须为 120 ms：%s" % role)
		if role == &"primary" or role == &"confirm":
			_expect(button.custom_minimum_size.y >= 52.0, "高价值按钮常规高度低于 52：%s" % role)
		button.call("set_reduced_motion", false)
		button.call("preview_state", &"hover")
		button.disabled = true
		button.call("preview_state", &"disabled")
		_expect(button.offset_transform_scale.is_equal_approx(Vector2.ONE), "禁用态未立即复位缩放：%s" % role)
		_expect(button.offset_transform_position.is_equal_approx(Vector2.ZERO), "禁用态未立即复位位移：%s" % role)
		_expect(button.self_modulate.is_equal_approx(Color.WHITE), "禁用态未立即复位色变：%s" % role)
		button.disabled = false
		button.call("set_reduced_motion", true)
		button.call("preview_state", &"press")
		_expect(button.offset_transform_scale.is_equal_approx(Vector2.ONE), "减少动态仍改变缩放：%s" % role)
		_expect(button.offset_transform_position.is_equal_approx(Vector2.ZERO), "减少动态仍产生位移：%s" % role)
		await create_timer(0.06).timeout
		_expect(button.offset_transform_scale.is_equal_approx(Vector2.ONE), "减少动态 Tween 产生缩放：%s" % role)
		_expect(button.offset_transform_position.is_equal_approx(Vector2.ZERO), "减少动态 Tween 产生位移：%s" % role)
		button.queue_free()
		await process_frame


func _check_lab() -> void:
	var lab_scene := load(LAB_SCENE_PATH) as PackedScene
	_expect(lab_scene != null, "GATE-3 UI 实验场无法加载")
	if lab_scene == null:
		return
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lab := lab_scene.instantiate() as Control
	_expect(lab != null, "GATE-3 UI 实验场根节点必须是 Control")
	if lab == null:
		viewport.queue_free()
		return
	viewport.add_child(lab)
	for viewport_size: Vector2i in VIEWPORTS:
		viewport.size = viewport_size
		for _frame: int in 4:
			await process_frame
		_check_layout_at(lab, viewport_size)
		if viewport_size == Vector2i(1280, 720):
			await _save_screenshot(viewport)
	_check_focus_ring(lab)
	lab.call("set_reduced_motion", true)
	_expect(bool(lab.call("is_reduced_motion_enabled")), "实验场未同步减少动态状态")
	for button: Button in _lab_buttons(lab):
		_expect(bool(button.call("is_reduced_motion_enabled")), "实验场按钮未同步减少动态：%s" % button.name)
	lab.queue_free()
	viewport.queue_free()
	await process_frame


func _check_layout_at(lab: Control, viewport_size: Vector2i) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size)).grow(0.5)
	var background := lab.get_node("Background") as Control
	var safe_margin := lab.get_node("SafeMargin") as Control
	var panel := lab.get_node("SafeMargin/Center/FoundationPanel") as Control
	_expect(viewport_rect.encloses(background.get_global_rect()), "背景未填满 %dx%d" % [viewport_size.x, viewport_size.y])
	_expect(viewport_rect.encloses(safe_margin.get_global_rect()), "安全区溢出 %dx%d" % [viewport_size.x, viewport_size.y])
	_expect(viewport_rect.encloses(panel.get_global_rect()), "核心面板裁切 %dx%d" % [viewport_size.x, viewport_size.y])
	_expect(panel.size.x <= 1120.5, "超宽屏核心功能区被横向拉伸：%dx%d" % [viewport_size.x, viewport_size.y])
	for button: Button in _lab_buttons(lab):
		_expect(viewport_rect.encloses(button.get_global_rect()), "按钮裁切：%s @ %dx%d" % [button.name, viewport_size.x, viewport_size.y])
		_expect(button.size.y >= 48.0, "按钮布局高度低于 48：%s @ %dx%d" % [button.name, viewport_size.x, viewport_size.y])
		_expect(button.size.x + 0.5 >= button.get_combined_minimum_size().x, "按钮文字横向裁切：%s @ %dx%d" % [button.name, viewport_size.x, viewport_size.y])


func _check_focus_ring(lab: Control) -> void:
	var buttons := _lab_buttons(lab)
	_expect(buttons.size() == 4, "焦点示范必须包含四个按钮")
	if buttons.size() != 4:
		return
	var current := buttons[0]
	for expected_index: int in range(1, 5):
		_expect(not current.focus_neighbor_right.is_empty(), "焦点右邻居未显式配置：%s" % current.name)
		var next := current.get_node_or_null(current.focus_neighbor_right) as Button
		_expect(next != null, "焦点右邻居无效：%s" % current.name)
		if next == null:
			return
		current = next
		_expect(current == buttons[expected_index % 4], "焦点闭环顺序错误：step=%d" % expected_index)
	_expect(current == buttons[0], "焦点链没有回到首按钮")
	for button: Button in buttons:
		_expect(not button.focus_neighbor_left.is_empty(), "焦点左邻居未显式配置：%s" % button.name)
		_expect(not button.focus_neighbor_top.is_empty(), "焦点上邻居未显式配置：%s" % button.name)
		_expect(not button.focus_neighbor_bottom.is_empty(), "焦点下邻居未显式配置：%s" % button.name)
		_expect(not button.focus_next.is_empty(), "Tab 下一焦点未显式配置：%s" % button.name)
		_expect(not button.focus_previous.is_empty(), "Tab 上一焦点未显式配置：%s" % button.name)


func _lab_buttons(lab: Control) -> Array[Button]:
	var grid := lab.get_node(BUTTON_GRID_PATH)
	var buttons: Array[Button] = []
	for child: Node in grid.get_children():
		if child is Button:
			buttons.append(child as Button)
	return buttons


func _save_screenshot(viewport: SubViewport) -> void:
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	for _frame: int in 3:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/gate3/ui"))
	var image := viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "无法读取 GATE-3 UI 实验场画面")
	if image == null or image.is_empty():
		return
	_expect(image.save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH)) == OK, "无法保存 GATE-3 UI 实验场截图")


func _finish() -> void:
	if _failures.is_empty():
		print("GATE3_UI_FOUNDATION_CONTRACT_PASS variants=4 roles=6 viewports=4 focus_loop=true reduced_motion=colour_only screenshot=%s" % SCREENSHOT_PATH)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("GATE3_UI_FOUNDATION_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
