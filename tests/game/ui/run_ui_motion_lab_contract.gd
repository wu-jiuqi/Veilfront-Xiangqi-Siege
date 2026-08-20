extends SceneTree

const PROFILE_PATH := "res://resources/game/ui/motion/terracotta_ui_motion_profile.tres"
const BUTTON_SCENE_PATH := "res://scenes/game/ui/ui_motion_button.tscn"
const LAB_SCENE_PATH := "res://scenes/dev/ui/ui_button_motion_lab.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := load(PROFILE_PATH)
	_assert(profile != null, "UI 动效配置无法加载")
	for group: StringName in [&"entrance", &"hover", &"press", &"focus", &"tab", &"feedback"]:
		_assert(profile.duration_for(group) > 0.0, "动效组时长无效：%s" % group)

	var button_scene := load(BUTTON_SCENE_PATH) as PackedScene
	_assert(button_scene != null, "按钮动效预置无法加载")
	var button := button_scene.instantiate() as Button
	_assert(button != null, "按钮预置根节点必须是 Button")
	_assert(button.has_method("set_reduced_motion"), "按钮缺少减少动态效果接口")
	_assert(button.has_method("preview_state"), "按钮缺少状态预览接口")
	button.set_reduced_motion(true)
	button.preview_state(&"press")
	_assert(button.is_reduced_motion_enabled(), "按钮未启用减少动态效果")
	button.queue_free()

	var lab_scene := load(LAB_SCENE_PATH) as PackedScene
	_assert(lab_scene != null, "按钮动效实验场无法加载")
	var lab := lab_scene.instantiate() as Control
	_assert(lab != null, "实验场根节点必须是 Control")
	root.add_child(lab)
	await process_frame
	_assert(lab.get_node_or_null("UiThemeBinder") != null, "实验场未预置 Theme Binder")
	_assert(lab.get_node_or_null("SafeMargin/Page/Body/DemoPanel") != null, "实验场缺少演示面板")
	_assert(lab.get_node_or_null("SafeMargin/Page/Body/DemoPanel/Margin/Content/FeedbackTarget") != null, "实验场缺少反馈目标")
	var motion_buttons := get_nodes_in_group(&"ui_motion_buttons")
	_assert(motion_buttons.size() == 9, "实验场必须预置 9 个可交互按钮")
	lab.call("_on_reduced_motion_toggled", true)
	for motion_button: Node in motion_buttons:
		_assert(motion_button.call("is_reduced_motion_enabled"), "减少动态效果未同步到所有按钮")
	lab.call("play_tab_switch", "测试页签")
	lab.call("play_feedback")
	print("UI_MOTION_LAB_CONTRACT_PASS groups=6 buttons=%d reduced_motion=true" % motion_buttons.size())
	lab.queue_free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
