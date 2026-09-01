extends SceneTree

const VARIANTS := {
	&"primary": "res://scenes/game/ui/ui_motion_button_primary.tscn",
	&"secondary": "res://scenes/game/ui/ui_motion_button_secondary.tscn",
	&"danger": "res://scenes/game/ui/ui_motion_button_danger.tscn",
	&"confirm": "res://scenes/game/ui/ui_motion_button_confirm.tscn",
}

const REQUIRED_VISUAL_NODES: Array[StringName] = [
	&"VisualRoot",
	&"Shadow",
	&"Surface",
	&"ArtLayer",
	&"FocusFrame",
	&"ContentMargin",
	&"ContentRow",
	&"Icon",
	&"ButtonLabel",
	&"SemanticMark",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for role: StringName in VARIANTS:
		await _check_variant(role, VARIANTS[role])
	_finish()


func _check_variant(role: StringName, scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, "无法加载按钮预置：%s" % role)
	if packed == null:
		return
	var button := packed.instantiate() as Button
	_expect(button != null, "按钮预置根节点必须是原生 Button：%s" % role)
	if button == null:
		return
	root.add_child(button)
	await process_frame
	for node_name: StringName in REQUIRED_VISUAL_NODES:
		_expect(button.get_node_or_null("%%%s" % node_name) != null, "缺少预置视觉节点：%s/%s" % [role, node_name])
	var visual_root := button.get_node_or_null("%VisualRoot") as Control
	var label := button.get_node_or_null("%ButtonLabel") as Label
	var surface := button.get_node_or_null("%Surface") as NinePatchRect
	var art_layer := button.get_node_or_null("%ArtLayer") as TextureRect
	var focus_frame := button.get_node_or_null("%FocusFrame") as Panel
	_expect(visual_root != null and visual_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "视觉根必须忽略输入：%s" % role)
	_expect(surface != null and surface.mouse_filter == Control.MOUSE_FILTER_IGNORE, "按钮表面必须独立且忽略输入：%s" % role)
	_expect(art_layer != null and art_layer.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "插画层必须保持比例：%s" % role)
	_expect(focus_frame != null and focus_frame.mouse_filter == Control.MOUSE_FILTER_IGNORE, "焦点框必须独立且忽略输入：%s" % role)
	_expect(button.has_method("sync_visual_state"), "按钮缺少显式视觉同步接口：%s" % role)
	button.text = "测试%s" % role
	button.call("sync_visual_state")
	_expect(label != null and label.text == button.text, "语义文本未同步到独立视觉层：%s" % role)
	_expect(not button.accessibility_name.is_empty(), "按钮缺少无障碍名称：%s" % role)
	_expect(button.get("semantic_role") == role, "按钮语义角色错误：%s" % role)
	button.call("set_reduced_motion", true)
	button.call("preview_state", &"focus")
	_expect(button.offset_transform_scale.is_equal_approx(Vector2.ONE), "减少动态仍改变布局壳缩放：%s" % role)
	_expect(button.offset_transform_position.is_equal_approx(Vector2.ZERO), "减少动态仍改变布局壳位移：%s" % role)
	button.disabled = true
	button.call("sync_visual_state")
	_expect(bool(button.call("is_visual_disabled")), "禁用态未同步到视觉层：%s" % role)
	button.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("UI_WORKFLOW_COMPONENT_CONTRACT_PASS variants=%d visual_layers=%d semantic_root=Button" % [VARIANTS.size(), REQUIRED_VISUAL_NODES.size()])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("UI_WORKFLOW_COMPONENT_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
