extends SceneTree

const PROFILE_PATH := "res://resources/game/ui/motion/terracotta_ui_motion_profile.tres"
const BUTTON_SCENE_PATH := "res://scenes/game/ui/ui_motion_button.tscn"
const LAB_SCENE_PATH := "res://scenes/dev/ui/ui_button_motion_lab.tscn"
const GALLERY_SCENE_PATH := "res://scenes/dev/ui/ui_hud_v2_gallery.tscn"

const GALLERY_TEXTURES := {
	"TurnStatusTexture": "res://assets/art/ui/terracotta_hud_v2/turn_status_bar_v1.png",
	"FactionLeftTexture": "res://assets/art/ui/terracotta_hud_v2/faction_status_plate_v1.png",
	"UnitInfoTexture": "res://assets/art/ui/terracotta_hud_v2/unit_info_card_v1.png",
	"ObjectiveTexture": "res://assets/art/ui/terracotta_hud_v2/objective_event_panel_v1.png",
	"ActionBarTexture": "res://assets/art/ui/terracotta_hud_v2/action_bar_frame_v1.png",
	"ActionButtonAtlasTexture": "res://assets/art/ui/terracotta_hud_v2/action_button_states_v1.png",
	"MinimapTexture": "res://assets/art/ui/terracotta_hud_v2/minimap_frame_v1.png",
	"DecorAtlasTexture": "res://assets/art/ui/terracotta_hud_v2/ui_decor_atlas_v1.png",
	"HudPanelTexture": "res://assets/art/ui/terracotta_hud_v2/hud_panel_9slice_v1.png",
}


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

	var gallery_scene := load(GALLERY_SCENE_PATH) as PackedScene
	_assert(gallery_scene != null, "HUD V2 组件预览无法加载")
	var gallery := gallery_scene.instantiate() as PanelContainer
	_assert(gallery != null, "HUD V2 组件预览根节点必须是 PanelContainer")
	root.add_child(gallery)
	await process_frame
	for node_name: String in GALLERY_TEXTURES:
		var texture_rect := gallery.get_node_or_null("%%%s" % node_name) as TextureRect
		_assert(texture_rect != null, "HUD V2 组件预览缺少节点：%s" % node_name)
		_assert(texture_rect.texture != null, "HUD V2 组件预览缺少贴图：%s" % node_name)
		_assert(texture_rect.texture.resource_path == GALLERY_TEXTURES[node_name], "HUD V2 组件贴图路径错误：%s" % node_name)
	_assert((gallery.get_node("%FactionRightTexture") as TextureRect).flip_h, "右方阵营状态板必须镜像复用")
	gallery.queue_free()

	var lab_scene := load(LAB_SCENE_PATH) as PackedScene
	_assert(lab_scene != null, "按钮动效实验场无法加载")
	var lab := lab_scene.instantiate() as Control
	_assert(lab != null, "实验场根节点必须是 Control")
	root.add_child(lab)
	await process_frame
	_assert(lab.get_node_or_null("UiThemeBinder") == null, "实验场不应包含已删除的 Theme Binder")
	_assert(lab.theme != null, "实验场未预置静态 Theme")
	_assert(lab.theme.resource_path == "res://resources/game/ui/themes/terracotta_ui_theme.tres", "实验场静态 Theme 路径错误")
	_assert(lab.get_node_or_null("SafeMargin/Page/Body/DemoPanel") != null, "实验场缺少演示面板")
	_assert(lab.get_node_or_null("SafeMargin/Page/Body/DemoPanel/Margin/Content/FeedbackTarget") != null, "实验场缺少反馈目标")
	var hud_gallery := lab.get_node_or_null("HudV2Gallery") as PanelContainer
	_assert(hud_gallery != null, "实验场未接入 HUD V2 组件预览")
	_assert(hud_gallery.visible, "实验场启动时必须先展示 HUD V2 组件预览")
	var motion_buttons := get_nodes_in_group(&"ui_motion_buttons")
	_assert(motion_buttons.size() == 9, "实验场必须预置 9 个可交互按钮")
	lab.call("_on_reduced_motion_toggled", true)
	for motion_button: Node in motion_buttons:
		_assert(motion_button.call("is_reduced_motion_enabled"), "减少动态效果未同步到所有按钮")
	lab.call("play_tab_switch", "测试页签")
	lab.call("play_feedback")
	lab.call("_on_gallery_close_requested")
	_assert(not hud_gallery.visible, "HUD V2 组件预览无法关闭")
	print("UI_MOTION_LAB_CONTRACT_PASS groups=6 buttons=%d hud_v2_textures=%d reduced_motion=true" % [motion_buttons.size(), GALLERY_TEXTURES.size()])
	lab.queue_free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
