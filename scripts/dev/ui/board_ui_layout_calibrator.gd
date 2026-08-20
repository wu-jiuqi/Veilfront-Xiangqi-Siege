class_name BoardUiLayoutCalibrator
extends Control

const BOARD_WORLD_SIZE := Vector2i(1152, 3072)
const SAVE_PATH := "user://veilfront_board_ui_layout.json"
const PROFILES: Array[Dictionary] = [
	{"name": "标准 16:9 · 1280×720", "canvas": Vector2i(1280, 720)},
	{"name": "宽屏 21:9 · 1680×720", "canvas": Vector2i(1680, 720)},
	{"name": "桌面 16:10 · 1280×800", "canvas": Vector2i(1280, 800)},
	{"name": "窄屏 4:3 · 1280×960", "canvas": Vector2i(1280, 960)},
]
const SNAP_STEPS: Array[int] = [1, 4, 8, 16]

@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _snap_option: OptionButton = %SnapOption
@onready var _x_spin: SpinBox = %XSpinBox
@onready var _y_spin: SpinBox = %YSpinBox
@onready var _width_spin: SpinBox = %WidthSpinBox
@onready var _height_spin: SpinBox = %HeightSpinBox
@onready var _show_hud_toggle: CheckButton = %ShowHudToggle
@onready var _show_safe_area_toggle: CheckButton = %ShowSafeAreaToggle
@onready var _readout: Label = %RectReadout
@onready var _status_label: Label = %StatusLabel
@onready var _preview_aspect: AspectRatioContainer = %PreviewAspect
@onready var _preview_viewport: SubViewport = %PreviewViewport
@onready var _preview_canvas: Control = %PreviewCanvas
@onready var _hud_overlay: Control = %HudOverlay
@onready var _safe_area_guide: Control = %SafeAreaGuide
@onready var _board_rect_editor: BoardVisibleRectEditor = %BoardVisibleRect

var _syncing_controls: bool = false
var _profile_index: int = 0
var _design_canvas_size := Vector2i(1280, 720)


func _ready() -> void:
	_populate_options()
	_connect_controls()
	_apply_profile(0, false)
	_board_rect_editor.set_snap_step(float(SNAP_STEPS[_snap_option.selected]))
	_board_rect_editor.set_calibration_rect(_default_board_rect(_design_canvas_size))
	_show_hud_toggle.set_pressed_no_signal(true)
	_show_safe_area_toggle.set_pressed_no_signal(true)
	_update_controls(_board_rect_editor.get_calibration_rect())
	_x_spin.get_line_edit().grab_focus.call_deferred()


func set_calibration_rect(rect: Rect2) -> void:
	_board_rect_editor.set_calibration_rect(rect)


func set_preview_profile(index: int) -> void:
	if index < 0 or index >= PROFILES.size():
		return
	_resolution_option.select(index)
	_apply_profile(index, true)


func get_calibration_snapshot() -> Dictionary:
	var payload := _build_payload()
	payload["hud_component_count"] = _hud_overlay.get_child_count()
	payload["resize_handle_count"] = _board_rect_editor.get_handle_count()
	payload["safe_area_visible"] = _safe_area_guide.visible
	return payload


func _populate_options() -> void:
	_resolution_option.clear()
	for profile: Dictionary in PROFILES:
		_resolution_option.add_item(str(profile["name"]))
	_snap_option.clear()
	for step: int in SNAP_STEPS:
		_snap_option.add_item("%d px" % step)
	_snap_option.select(2)


func _connect_controls() -> void:
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_snap_option.item_selected.connect(_on_snap_selected)
	_x_spin.value_changed.connect(_on_numeric_value_changed)
	_y_spin.value_changed.connect(_on_numeric_value_changed)
	_width_spin.value_changed.connect(_on_numeric_value_changed)
	_height_spin.value_changed.connect(_on_numeric_value_changed)
	%ResetButton.pressed.connect(_on_reset_pressed)
	%CenterButton.pressed.connect(_on_center_pressed)
	%SafeAreaButton.pressed.connect(_on_safe_area_pressed)
	%CopyButton.pressed.connect(_on_copy_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%LoadButton.pressed.connect(_on_load_pressed)
	_show_hud_toggle.toggled.connect(_on_show_hud_toggled)
	_show_safe_area_toggle.toggled.connect(_on_show_safe_area_toggled)
	_board_rect_editor.calibration_rect_changed.connect(_update_controls)
	_preview_viewport.size_changed.connect(_sync_preview_transform)


func _apply_profile(index: int, preserve_normalized: bool) -> void:
	var previous_rect := _board_rect_editor.get_calibration_rect() if is_instance_valid(_board_rect_editor) else Rect2()
	var previous_size := Vector2(_design_canvas_size)
	var normalized := _normalize_rect(previous_rect, previous_size)
	_profile_index = index
	var canvas: Vector2i = PROFILES[index]["canvas"]
	_design_canvas_size = canvas
	_preview_canvas.size = Vector2(canvas)
	_preview_aspect.ratio = float(canvas.x) / float(canvas.y)
	_update_numeric_ranges(canvas)
	var next_rect := _denormalize_rect(normalized, Vector2(canvas)) if preserve_normalized else _default_board_rect(canvas)
	_board_rect_editor.set_calibration_rect(next_rect)
	_sync_preview_transform.call_deferred()
	_status_label.text = "已切换预览画布：%s" % PROFILES[index]["name"]


func _update_numeric_ranges(canvas: Vector2i) -> void:
	_x_spin.max_value = canvas.x
	_y_spin.max_value = canvas.y
	_width_spin.max_value = canvas.x
	_height_spin.max_value = canvas.y


func _update_controls(rect: Rect2) -> void:
	_syncing_controls = true
	_x_spin.set_value_no_signal(rect.position.x)
	_y_spin.set_value_no_signal(rect.position.y)
	_width_spin.set_value_no_signal(rect.size.x)
	_height_spin.set_value_no_signal(rect.size.y)
	_syncing_controls = false
	var canvas := Vector2(_design_canvas_size)
	var normalized := _normalize_rect(rect, canvas)
	_readout.text = (
		"屏幕坐标：x=%d  y=%d\n"
		+ "默认可视尺寸：%d × %d px\n"
		+ "占屏比例：left=%.4f  top=%.4f\n"
		+ "　　　　　width=%.4f  height=%.4f\n"
		+ "提示：这是屏幕中的默认棋盘窗口，不是 %d×%d 的完整棋盘世界。"
	) % [
		roundi(rect.position.x), roundi(rect.position.y),
		roundi(rect.size.x), roundi(rect.size.y),
		normalized.position.x, normalized.position.y,
		normalized.size.x, normalized.size.y,
		BOARD_WORLD_SIZE.x, BOARD_WORLD_SIZE.y,
	]


func _on_numeric_value_changed(_value: float) -> void:
	if _syncing_controls:
		return
	_board_rect_editor.set_calibration_rect(Rect2(
		Vector2(float(_x_spin.value), float(_y_spin.value)),
		Vector2(float(_width_spin.value), float(_height_spin.value))
	))


func _on_resolution_selected(index: int) -> void:
	_apply_profile(index, true)


func _on_snap_selected(index: int) -> void:
	_board_rect_editor.set_snap_step(float(SNAP_STEPS[index]))
	_status_label.text = "吸附步长：%d px" % SNAP_STEPS[index]


func _on_reset_pressed() -> void:
	_board_rect_editor.set_calibration_rect(_default_board_rect(_design_canvas_size))
	_status_label.text = "已恢复推荐的 HUD 中央可用区域"


func _on_center_pressed() -> void:
	var rect := _board_rect_editor.get_calibration_rect()
	rect.position = (Vector2(_design_canvas_size) - rect.size) * 0.5
	_board_rect_editor.set_calibration_rect(rect)
	_status_label.text = "已保持尺寸并居中"


func _on_safe_area_pressed() -> void:
	var canvas := Vector2(_design_canvas_size)
	_board_rect_editor.set_calibration_rect(Rect2(Vector2(16.0, 16.0), canvas - Vector2(32.0, 32.0)))
	_status_label.text = "已扩展至 16 px 屏幕安全区；可用于检查与 HUD 的重叠"


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(JSON.stringify(_build_payload(), "\t"))
	_status_label.text = "已复制布局 JSON，可直接交给正式棋盘接入任务"


func _on_save_pressed() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_status_label.text = "保存失败：无法写入 %s" % SAVE_PATH
		return
	file.store_string(JSON.stringify(_build_payload(), "\t") + "\n")
	_status_label.text = "已保存：%s" % OS.get_user_data_dir().path_join("veilfront_board_ui_layout.json")


func _on_load_pressed() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_status_label.text = "尚无已保存的布局文件"
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_status_label.text = "读取失败：%s" % SAVE_PATH
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_status_label.text = "读取失败：布局 JSON 格式无效"
		return
	var data := parsed as Dictionary
	var canvas_values: Array = data.get("design_canvas_size", [])
	if canvas_values.size() == 2:
		var wanted_canvas := Vector2i(int(canvas_values[0]), int(canvas_values[1]))
		for index: int in range(PROFILES.size()):
			if Vector2i(PROFILES[index]["canvas"]) == wanted_canvas:
				set_preview_profile(index)
				break
	var rect_data: Dictionary = data.get("default_visible_board_rect_px", {})
	if rect_data.has_all(["x", "y", "width", "height"]):
		set_calibration_rect(Rect2(
			Vector2(float(rect_data["x"]), float(rect_data["y"])),
			Vector2(float(rect_data["width"]), float(rect_data["height"]))
		))
		_status_label.text = "已载入保存的默认棋盘可视区域"


func _on_show_hud_toggled(enabled: bool) -> void:
	_hud_overlay.visible = enabled
	_status_label.text = "HUD 显示：%s" % ("开启" if enabled else "关闭")


func _on_show_safe_area_toggled(enabled: bool) -> void:
	_safe_area_guide.visible = enabled
	_status_label.text = "16 px 安全区：%s" % ("开启" if enabled else "关闭")


func _build_payload() -> Dictionary:
	var rect := _board_rect_editor.get_calibration_rect()
	var canvas := Vector2(_design_canvas_size)
	var normalized := _normalize_rect(rect, canvas)
	return {
		"schema_version": "veilfront-board-ui-layout-v1",
		"coordinate_space": "design_canvas",
		"meaning": "default_visible_board_screen_rect",
		"explicitly_not": "full_board_world_size",
		"profile": str(PROFILES[_profile_index]["name"]),
		"design_canvas_size": [_design_canvas_size.x, _design_canvas_size.y],
		"full_board_world_size_reference": [BOARD_WORLD_SIZE.x, BOARD_WORLD_SIZE.y],
		"default_visible_board_rect_px": {
			"x": roundi(rect.position.x),
			"y": roundi(rect.position.y),
			"width": roundi(rect.size.x),
			"height": roundi(rect.size.y),
		},
		"default_visible_board_rect_normalized": {
			"left": normalized.position.x,
			"top": normalized.position.y,
			"width": normalized.size.x,
			"height": normalized.size.y,
		},
		"snap_step_px": SNAP_STEPS[_snap_option.selected],
	}


func _default_board_rect(canvas_value: Variant) -> Rect2:
	var canvas := Vector2(canvas_value)
	var left_gutter := 260.0
	var right_gutter := 260.0
	var top_gutter := 104.0
	var bottom_gutter := 166.0
	return Rect2(
		Vector2(left_gutter, top_gutter),
		Vector2(
			maxf(320.0, canvas.x - left_gutter - right_gutter),
			maxf(240.0, canvas.y - top_gutter - bottom_gutter)
		)
	)


func _normalize_rect(rect: Rect2, canvas: Vector2) -> Rect2:
	if canvas.x <= 0.0 or canvas.y <= 0.0:
		return Rect2()
	return Rect2(rect.position / canvas, rect.size / canvas)


func _denormalize_rect(rect: Rect2, canvas: Vector2) -> Rect2:
	return Rect2(rect.position * canvas, rect.size * canvas)


func _sync_preview_transform() -> void:
	if not is_instance_valid(_preview_canvas):
		return
	var physical_size := Vector2(_preview_viewport.size)
	var logical_size := Vector2(_design_canvas_size)
	if physical_size.x <= 0.0 or physical_size.y <= 0.0:
		return
	var scale_value := minf(physical_size.x / logical_size.x, physical_size.y / logical_size.y)
	_preview_canvas.scale = Vector2(scale_value, scale_value)
	_preview_canvas.position = (physical_size - logical_size * scale_value) * 0.5
