extends Node

const UiStyleDefinition = preload("res://scripts/game/presentation/ui/ui_style_definition.gd")

@export var target_path: NodePath = NodePath("..")

var _style_service: Node
var _target: Control


func _ready() -> void:
	_target = get_node_or_null(target_path) as Control
	_style_service = get_node_or_null("/root/UiStyleService")
	if _target == null:
		push_error("UiThemeBinder 的目标必须是 Control。")
		return
	if _style_service == null:
		push_error("UiThemeBinder 找不到 UiStyleService 自动加载节点。")
		return

	_style_service.style_changed.connect(_apply_style)
	_apply_style(_style_service.get_current_style())


func _exit_tree() -> void:
	if _style_service != null and _style_service.style_changed.is_connected(_apply_style):
		_style_service.style_changed.disconnect(_apply_style)


func _apply_style(style: UiStyleDefinition) -> void:
	if _target == null or style == null or style.ui_theme == null:
		return
	_target.theme = style.ui_theme
	_target.set_meta(&"veilfront_ui_style_id", style.style_id)
