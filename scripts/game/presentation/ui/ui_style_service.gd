extends Node

const UiStyleDefinition = preload("res://scripts/game/presentation/ui/ui_style_definition.gd")

signal style_changed(style: UiStyleDefinition)

const DEFAULT_STYLE_ID: StringName = &"terracotta"
const STYLE_DEFINITIONS: Array[UiStyleDefinition] = [
	preload("res://resources/game/ui/styles/graybox_ui_style.tres"),
	preload("res://resources/game/ui/styles/terracotta_ui_style.tres"),
]

var _styles_by_id: Dictionary[StringName, UiStyleDefinition] = {}
var _current_style: UiStyleDefinition


func _ready() -> void:
	for style: UiStyleDefinition in STYLE_DEFINITIONS:
		if not style.is_valid():
			push_error("UI 样式定义无效，已跳过。")
			continue
		if _styles_by_id.has(style.style_id):
			push_error("UI 样式 ID 重复：%s" % style.style_id)
			continue
		_styles_by_id[style.style_id] = style

	if not select_style(DEFAULT_STYLE_ID):
		push_error("默认 UI 样式不存在：%s" % DEFAULT_STYLE_ID)


func select_style(style_id: StringName) -> bool:
	var next_style: UiStyleDefinition = _styles_by_id.get(style_id)
	if next_style == null:
		push_warning("拒绝切换到未登记的 UI 样式：%s" % style_id)
		return false
	if next_style == _current_style:
		return true

	_current_style = next_style
	style_changed.emit(_current_style)
	return true


func get_current_style() -> UiStyleDefinition:
	return _current_style


func get_available_style_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_styles_by_id.keys())
	result.sort()
	return result
