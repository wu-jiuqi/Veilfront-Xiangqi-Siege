extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/game/ui/loading_transition_overlay.tscn"
const LAB_SCENE_PATH := "res://scenes/dev/ui/loading_transition_motion_lab.tscn"
const CHROMA_KEYED_ASSETS := [
	"res://assets/art/ui/loading_transition/loading_nine_route_seal_v1.png",
	"res://assets/art/ui/loading_transition/failure_retry_button_v1.png",
	"res://assets/art/ui/loading_transition/failure_back_button_v1.png",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for asset_path: String in CHROMA_KEYED_ASSETS:
		_assert_transparent_asset(asset_path)
	var overlay_scene := load(OVERLAY_SCENE_PATH) as PackedScene
	_assert(overlay_scene != null, "加载过渡组件场景无法加载")
	var overlay := overlay_scene.instantiate() as Control
	_assert(overlay != null, "加载过渡组件根节点必须是 Control")
	root.add_child(overlay)
	await process_frame
	await process_frame
	_assert(overlay.theme != null, "加载过渡组件未绑定兵马俑 Theme")
	_assert(overlay.has_method("start_loading"), "加载过渡组件缺少 start_loading 接口")
	_assert(overlay.has_method("set_progress"), "加载过渡组件缺少 set_progress 接口")
	_assert(overlay.has_method("show_failure"), "加载过渡组件缺少 show_failure 接口")
	_assert(overlay.has_method("set_reduced_motion"), "加载过渡组件缺少减少动态效果接口")
	var fog_back := overlay.get_node("FogLayer/FogBack") as TextureRect
	var fog_front := overlay.get_node("FogLayer/FogFront") as TextureRect
	var fog_back_origin := fog_back.position
	var fog_front_origin := fog_front.position
	overlay.call("start_loading", "正在布设九路战场…")
	overlay.call("set_progress", 67.0)
	await process_frame
	var status_label := overlay.get_node("LoadingContent/StatusAnchor/StatusStack/StatusLabel") as Label
	var progress_track := overlay.get_node("LoadingContent/StatusAnchor/StatusStack/ProgressStack/ProgressTrackFrame") as TextureRect
	var progress_bar := overlay.get_node("LoadingContent/StatusAnchor/StatusStack/ProgressStack/ProgressInset/ProgressBar") as ProgressBar
	var progress_glow := overlay.get_node("LoadingContent/StatusAnchor/StatusStack/ProgressStack/ProgressInset/ProgressGlow") as ProgressBar
	var progress_fill_clip := overlay.get_node("LoadingContent/StatusAnchor/StatusStack/ProgressStack/ProgressInset/ProgressFillClip") as Control
	var progress_cursor := overlay.get_node("LoadingContent/StatusAnchor/StatusStack/ProgressStack/ProgressInset/ProgressSpark") as TextureRect
	var percent_label := overlay.get_node("LoadingContent/StatusAnchor/StatusStack/PercentLabel") as Label
	var seal_anchor := overlay.get_node("LoadingContent/SealAnchor") as Control
	_assert(status_label.size.x > 300.0 and status_label.size.y > 20.0, "加载状态标签布局无效")
	_assert(progress_bar.size.x > 300.0 and progress_bar.size.y >= 10.0, "加载进度条布局无效")
	_assert(progress_track.texture != null, "加载进度条缺少九路金属轨道")
	_assert(is_equal_approx(progress_glow.value, 67.0), "加载进度外发光没有同步")
	_assert(absf(progress_fill_clip.size.x - progress_bar.size.x * 0.67) <= 1.0, "加载进度扫光裁切没有同步")
	_assert(
		absf(progress_cursor.get_global_rect().get_center().x - (progress_bar.global_position.x + progress_bar.size.x * 0.67)) <= 1.0,
		"加载进度菱形游标没有贴合填充端点"
	)
	_assert(percent_label.text == "67%", "加载百分比没有同步")
	_assert(absf(seal_anchor.get_global_rect().get_center().x - overlay.get_global_rect().get_center().x) <= 1.0, "加载核心图形没有水平居中")
	_assert(absf(status_label.get_global_rect().get_center().x - overlay.get_global_rect().get_center().x) <= 1.0, "加载状态没有水平居中")
	overlay.call("show_failure", "加载失败", "未能抵达战场", "场景资源响应超时，请重试。")
	await create_timer(0.8).timeout
	var failure_layer := overlay.get_node("FailureLayer") as Control
	var failure_card := overlay.get_node("FailureLayer/FailureAnchor/FailureCard") as PanelContainer
	var retry_button := overlay.get_node("FailureLayer/FailureAnchor/FailureCard/Margin/Content/ButtonRow/RetryButton") as Button
	var back_button := overlay.get_node("FailureLayer/FailureAnchor/FailureCard/Margin/Content/ButtonRow/BackButton") as Button
	_assert(failure_layer.visible, "失败反馈层未显示")
	_assert(failure_card.global_position.x >= 0.0, "失败卡越过左侧边界")
	_assert(failure_card.global_position.x + failure_card.size.x <= overlay.size.x + 1.0, "失败卡越过右侧边界")
	_assert(absf(failure_card.get_global_rect().get_center().x - overlay.get_global_rect().get_center().x) <= 1.0, "失败弹窗没有水平居中")
	_assert(absf(failure_card.get_global_rect().get_center().y - overlay.get_global_rect().get_center().y) <= 1.0, "失败弹窗没有垂直居中")
	_assert(failure_card.size.y <= 400.0, "失败弹窗发生尺寸漂移")
	_assert(overlay.get_node("LoadingContent").modulate.a >= 0.55, "失败弹窗不应替换或隐藏完整加载场景")
	_assert(retry_button.get_theme_stylebox("normal") is StyleBoxTexture, "重试按钮没有使用独立抠图底板")
	_assert(back_button.get_theme_stylebox("normal") is StyleBoxTexture, "返回按钮没有使用独立抠图底板")
	_assert(overlay.call("get_transition_state") == &"failure", "失败状态没有落地")
	overlay.call("set_reduced_motion", true)
	_assert(overlay.call("is_reduced_motion_enabled"), "减少动态效果没有启用")
	_assert(fog_back.position.is_equal_approx(fog_back_origin), "减少动态效果没有复位后层雾气，重播可能产生位置漂移")
	_assert(fog_front.position.is_equal_approx(fog_front_origin), "减少动态效果没有复位前层雾气，重播可能产生位置漂移")
	overlay.queue_free()

	var lab_scene := load(LAB_SCENE_PATH) as PackedScene
	_assert(lab_scene != null, "加载过渡动效实验场无法加载")
	var lab := lab_scene.instantiate() as Control
	_assert(lab != null, "加载过渡动效实验场根节点必须是 Control")
	root.add_child(lab)
	await process_frame
	await process_frame
	_assert(lab.get_node_or_null("LoadingOverlay") != null, "实验场未预置加载过渡组件")
	_assert(lab.get_node_or_null("LabHintPanel/Margin/LabHint") != null, "实验场缺少操作提示")
	print("LOADING_TRANSITION_MOTION_LAB_CONTRACT_PASS progress=67 failure_feedback=true reduced_motion=true")
	lab.queue_free()
	quit(0)


func _assert_transparent_asset(asset_path: String) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(asset_path))
	_assert(image != null and not image.is_empty(), "紫幕抠图资产无法加载：%s" % asset_path)
	_assert(image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF], "紫幕抠图资产不是 RGBA：%s" % asset_path)
	_assert(image.get_pixel(0, 0).a <= 0.05, "紫幕抠图资产角落没有透明：%s" % asset_path)
	_assert(image.get_pixel(image.get_width() / 2, image.get_height() / 2).a >= 0.95, "紫幕抠图资产中心不是实体：%s" % asset_path)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
