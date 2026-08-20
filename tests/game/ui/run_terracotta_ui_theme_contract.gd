extends SceneTree

const THEME_PATH := "res://resources/game/ui/themes/terracotta_ui_theme.tres"
const VECTOR_ROOT := "res://assets/art/ui/terracotta_metal"

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


func _init() -> void:
	var theme := load(THEME_PATH) as Theme
	_assert(theme != null, "兵马俑 Theme 无法加载")
	_assert(theme.default_font != null, "Theme 未接入统一中文字体")
	_assert(theme.get_stylebox(&"normal", &"Button") is StyleBoxTexture, "普通按钮未使用金属贴图")
	_assert(theme.get_stylebox(&"hover", &"Button") is StyleBoxTexture, "悬停按钮未使用金属贴图")
	_assert(theme.get_stylebox(&"pressed", &"Button") is StyleBoxTexture, "按下按钮未使用金属贴图")
	_assert(theme.get_stylebox(&"disabled", &"Button") is StyleBoxTexture, "禁用按钮未使用金属贴图")
	_assert(theme.get_stylebox(&"focus", &"Button") is StyleBoxTexture, "焦点框未使用金属贴图")
	for variation: StringName in BUTTON_VARIATIONS:
		_assert(theme.get_type_variation_base(variation) == &"Button", "按钮语义变体缺失：%s" % variation)
	for variation: StringName in PANEL_VARIATIONS:
		_assert(theme.get_type_variation_base(variation) == &"PanelContainer", "面板语义变体缺失：%s" % variation)
	for variation: StringName in FRAME_VARIATIONS:
		_assert(theme.get_type_variation_base(variation) == &"Panel", "框体语义变体缺失：%s" % variation)
	_assert(_count_svg_files(VECTOR_ROOT) == 46, "矢量源文件数量必须为 46")
	print("TERRACOTTA_UI_THEME_CONTRACT_PASS buttons=6 panels=8 frames=8 vectors=46")
	quit(0)


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
	push_error(message)
	quit(1)
