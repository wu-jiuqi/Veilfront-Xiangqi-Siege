extends SceneTree

const THEME_PATH := "res://resources/game/ui/themes/terracotta_ui_theme.tres"
const VECTOR_ROOT := "res://assets/art/ui/terracotta_metal"
const HUD_V2_ROOT := "res://assets/art/ui/terracotta_hud_v2"
const PANEL_TEXTURE_PATH := HUD_V2_ROOT + "/hud_panel_9slice_v1.png"
const MINIMAP_TEXTURE_PATH := HUD_V2_ROOT + "/minimap_frame_v1.png"
const TURN_STATUS_TEXTURE_PATH := HUD_V2_ROOT + "/turn_status_bar_v1.png"
const MATCH_THEME_PATH := "res://resources/game/ui/themes/match_hud_v3_theme.tres"

const BUTTON_VARIATIONS := [
	&"PrimaryButton", &"SecondaryButton", &"DangerButton",
	&"IconButton", &"TabButton", &"QuietButton",
]
const PANEL_VARIATIONS := [
	&"HUDPanel", &"ModalPanel", &"TooltipPanel", &"SidebarPanel",
	&"CardPanel", &"MinimapPanel", &"ResultPanel", &"SettingsPanel",
]
const FRAME_VARIATIONS := [
	&"PortraitFrame", &"PieceFrame", &"ObjectiveFrame", &"InfoFrame",
	&"FocusFrame", &"SelectedFrame", &"WarningFrame", &"MinimapFrame",
]

var _failures: Array[String] = []


func _init() -> void:
	var theme := load(THEME_PATH) as Theme
	_assert(theme != null, "兵马俑 Theme 无法加载")
	_assert(theme.default_font != null, "Theme 未接入统一中文字体")
	_assert_no_global_button_skin(theme, THEME_PATH)
	var match_theme := load(MATCH_THEME_PATH) as Theme
	_assert(match_theme != null, "正式战局 Theme 无法加载")
	_assert_no_global_button_skin(match_theme, MATCH_THEME_PATH)
	_assert(_style_texture_path(theme, &"panel", &"Panel") == PANEL_TEXTURE_PATH, "面板仍引用旧废案贴图")
	_assert(_style_texture_path(theme, &"panel", &"MinimapFrame") == MINIMAP_TEXTURE_PATH, "小地图框未接入 V2")
	_assert(_style_texture_path(theme, &"panel", &"TurnStatusPanel") == TURN_STATUS_TEXTURE_PATH, "回合状态条未接入 V2")
	for variation: StringName in BUTTON_VARIATIONS:
		_assert(theme.get_type_variation_base(variation) == &"Button", "按钮语义变体缺失：%s" % variation)
	for variation: StringName in PANEL_VARIATIONS:
		_assert(theme.get_type_variation_base(variation) == &"PanelContainer", "面板语义变体缺失：%s" % variation)
	for variation: StringName in FRAME_VARIATIONS:
		_assert(theme.get_type_variation_base(variation) == &"Panel", "框体语义变体缺失：%s" % variation)
	_assert(theme.get_type_variation_base(&"TurnStatusPanel") == &"PanelContainer", "回合状态条语义变体缺失")
	_assert(_count_svg_files(VECTOR_ROOT) == 49, "矢量源文件数量必须为 49")
	_assert(_count_top_level_png_files(HUD_V2_ROOT) == 9, "HUD V2 生产 PNG 数量必须为 9")
	if not _failures.is_empty():
		print("TERRACOTTA_UI_THEME_CONTRACT_FAIL failures=%d" % _failures.size())
		quit(1)
		return
	print("TERRACOTTA_UI_THEME_CONTRACT_PASS global_button_skin=false variations=6 panels=8 frames=8 vectors=49 hud_v2=9")
	quit(0)


func _assert_no_global_button_skin(theme: Theme, theme_path: String) -> void:
	if theme == null:
		return
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		_assert(
			not theme.has_stylebox(style_name, &"Button"),
			"基础 Button 不应从根 Theme 继承样式：%s %s" % [theme_path, style_name]
		)
	for color_name: StringName in [
		&"font_color", &"font_hover_color", &"font_pressed_color",
		&"font_disabled_color", &"font_focus_color",
	]:
		_assert(
			not theme.has_color(color_name, &"Button"),
			"基础 Button 不应从根 Theme 继承颜色：%s %s" % [theme_path, color_name]
		)


func _style_texture_path(theme: Theme, style_name: StringName, type_name: StringName) -> String:
	var style := theme.get_stylebox(style_name, type_name) as StyleBoxTexture
	_assert(style != null and style.texture != null, "样式缺少贴图：%s/%s" % [type_name, style_name])
	return style.texture.resource_path


func _count_top_level_png_files(path: String) -> int:
	var count := 0
	var directory := DirAccess.open(path)
	_assert(directory != null, "无法打开 HUD V2 美术目录")
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir() and entry.get_extension().to_lower() == "png":
			count += 1
		entry = directory.get_next()
	directory.list_dir_end()
	return count


func _count_svg_files(path: String) -> int:
	var count := 0
	var directory := DirAccess.open(path)
	_assert(directory != null, "无法打开 UI 美术目录")
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child_path := path.path_join(entry)
		if directory.current_is_dir() and not entry.begins_with("."):
			count += _count_svg_files(child_path)
		elif entry.get_extension().to_lower() == "svg":
			count += 1
		entry = directory.get_next()
	directory.list_dir_end()
	return count


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)
