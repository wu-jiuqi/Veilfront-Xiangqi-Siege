extends SceneTree

const LAB_SCENE: PackedScene = preload("res://scenes/dev/ui/level_gameplay_hud_lab.tscn")
const SCREENSHOT_PATH := "res://evidence/ui/ui-rebuild-level-guide-1280x720.png"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lab := LAB_SCENE.instantiate() as Control
	viewport.add_child(lab)
	for _frame: int in 10:
		await process_frame

	var snapshot: Dictionary = lab.call("get_lab_snapshot") as Dictionary
	var guide: Dictionary = snapshot.get("guide", {})
	var board: Dictionary = snapshot.get("board", {})
	_expect(bool(snapshot.get("initialized", false)), "关卡 HUD 测试场景未完成初始化")
	_expect(bool(snapshot.get("uses_online_match_screen_scene", false)), "测试场景没有复用正式联机对局场景")
	_expect(bool(snapshot.get("uses_match_hud_v3", false)), "测试场景没有复用正式 MatchHudV3")
	_expect(bool(snapshot.get("original_right_rail_visible", false)), "原联机右栏布局占位被移除，棋盘会扩张到右边界")
	_expect(bool(snapshot.get("original_right_content_hidden", false)), "原联机右栏内容仍与关卡指引叠加显示")
	_expect(_rects_match(snapshot), "关卡指引没有覆盖原联机 HUD 右栏")
	_expect(_center_column_clear_of_guide(lab), "棋盘与行动区扩张到了关卡指引下方")
	_expect(str(board.get("map_id", "")) == "terracotta_battlefield_v3", "测试场景没有复用正式秦俑战场地图")
	_expect(int(board.get("piece_count", 0)) == 32, "测试场景没有复用正式 32 枚开局棋子")
	_expect(str(guide.get("title", "")) == "关卡指引", "关卡指引标题未动态填充")
	_expect((guide.get("step_texts", []) as Array).size() == 3, "关卡指引不是三步结构")
	_expect((guide.get("step_statuses", []) as Array) == ["complete", "active", "pending"], "关卡步骤初始状态错误")
	_expect(int(guide.get("action_button_count", 0)) == 2, "关卡指引底部不是两个操作按钮")
	_expect(
		int(guide.get("objective_autowrap_mode", 0)) == TextServer.AUTOWRAP_WORD_SMART
		and bool(guide.get("objective_clips_text", false)),
		"关卡目标没有启用中文智能换行与边界裁切"
	)
	_expect(
		int(guide.get("current_operation_autowrap_mode", 0)) == TextServer.AUTOWRAP_WORD_SMART
		and bool(guide.get("current_operation_clips_text", false)),
		"当前操作没有启用中文智能换行与边界裁切"
	)
	_expect(
		str(guide.get("surface_system", "")) == "veilfront-ui-theme-v2" \
		and str(guide.get("background_texture_path", "")).is_empty(),
		"关卡指引没有使用统一的可伸缩主题表面"
	)

	if DisplayServer.get_name() != "headless":
		var capture_result := await _save_viewport(viewport, SCREENSHOT_PATH)
		_expect(capture_result == OK, "无法保存关卡 HUD 测试截图")
	_expect(
		_rect_inside_viewport(snapshot.get("guide_rect", Rect2()), viewport.size),
		"关卡指引在项目基准分辨率 1280x720 下溢出视口"
	)

	var hint_button := lab.find_child("HintButton", true, false) as Button
	var reset_button := lab.find_child("ResetButton", true, false) as Button
	_expect(hint_button != null and not hint_button.disabled, "显示提示按钮初始不可用")
	_expect(reset_button != null and not reset_button.disabled, "重置步骤按钮初始不可用")
	if hint_button != null:
		hint_button.pressed.emit()
	await process_frame
	var hinted: Dictionary = lab.call("get_lab_snapshot") as Dictionary
	_expect(bool((hinted.get("guide", {}) as Dictionary).get("hint_revealed", false)), "显示提示没有刷新关卡指引")
	_expect(str(hinted.get("last_guide_event", "")) == "hint_requested", "显示提示没有发出业务信号")
	if reset_button != null:
		reset_button.pressed.emit()
	await process_frame
	var reset: Dictionary = lab.call("get_lab_snapshot") as Dictionary
	_expect((reset.get("guide", {}) as Dictionary).get("step_statuses", []) == ["active", "pending", "pending"], "重置步骤没有恢复初始进度")
	_expect(str(reset.get("last_guide_event", "")) == "reset_requested", "重置步骤没有发出业务信号")
	lab.call("collapse_guide_for_test", true)
	await process_frame
	var collapsed: Dictionary = lab.call("get_lab_snapshot") as Dictionary
	_expect(bool((collapsed.get("guide", {}) as Dictionary).get("collapsed", false)), "收起按钮没有进入收起状态")
	_expect((collapsed.get("guide_rect", Rect2()) as Rect2).size.x <= 45.0, "收起后关卡指引没有缩成窄条")

	lab.queue_free()
	viewport.queue_free()
	await process_frame
	_finish()


func _rects_match(snapshot: Dictionary) -> bool:
	var original: Rect2 = snapshot.get("original_right_rect", Rect2())
	var guide: Rect2 = snapshot.get("guide_rect", Rect2())
	var matches := original.position.distance_to(guide.position) <= 1.0 \
		and original.size.distance_to(guide.size) <= 1.0
	if not matches:
		print("LEVEL_GUIDE_RECT_DIAGNOSTIC original=%s guide=%s" % [original, guide])
	return matches


func _center_column_clear_of_guide(lab: Control) -> bool:
	var center_column := lab.get_node(
		"OnlineMatchScreen/MatchHudV3/SafeMargin/MainRows/BodyBand/CenterColumn"
	) as Control
	var guide := lab.get_node(
		"LevelGuideOverlay/SafeMargin/MainRows/BodyBand/LevelGuidePanel"
	) as Control
	return not center_column.get_global_rect().intersects(guide.get_global_rect())


func _rect_inside_viewport(rect: Rect2, viewport_size: Vector2i) -> bool:
	return Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(rect)


func _save_viewport(viewport: SubViewport, output_path: String) -> Error:
	RenderingServer.force_draw()
	for _frame: int in 4:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return ERR_CANT_CREATE
	return image.save_png(ProjectSettings.globalize_path(output_path))


func _finish() -> void:
	if _failures.is_empty():
		print("LEVEL_GAMEPLAY_HUD_LAB_PASS screenshot=%s" % SCREENSHOT_PATH)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("LEVEL_GAMEPLAY_HUD_LAB_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
