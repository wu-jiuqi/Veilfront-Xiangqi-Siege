extends SceneTree

const LAB_SCENE: PackedScene = preload("res://scenes/dev/ui/match_hud_v3_layout_lab.tscn")
const SCREENSHOT_PATH := "res://evidence/ui/match-hud-v3-layout-lab-1280x720.png"
const RESPONSIVE_VIEWPORTS: Array[Vector2i] = [
	Vector2i(1024, 576),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1680, 720),
]

const UI_ASSETS: Array[Dictionary] = [
	{"name": "turn", "opaque_center": true},
	{"name": "faction", "opaque_center": true},
	{"name": "panel_9slice", "opaque_center": true},
	{"name": "minimap_frame", "opaque_center": false},
	{"name": "unit_info_card", "opaque_center": true},
	{"name": "objective_events_panel", "opaque_center": true},
	{"name": "action_rules_panel", "opaque_center": true},
	{"name": "button_plate", "opaque_center": true},
]

const FILE_NAMES := {
	"turn": "turn_status_bar",
	"faction": "faction_summary_plate",
	"panel_9slice": "panel_9slice",
	"minimap_frame": "minimap_frame",
	"unit_info_card": "unit_info_card",
	"objective_events_panel": "objective_events_panel",
	"action_rules_panel": "action_rules_panel",
	"button_plate": "button_plate",
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_chroma_assets()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lab := LAB_SCENE.instantiate() as Control
	viewport.add_child(lab)
	for _frame: int in 6:
		await process_frame

	var snapshot: Dictionary = lab.call("get_lab_snapshot") as Dictionary
	var board: Dictionary = snapshot.get("board", {})
	_expect(int(board.get("piece_count", 0)) == 32, "V3 实验没有复用正式 32 枚开局棋子")
	_expect(int(board.get("horizontal_grid_line_count", 0)) > 0, "V3 实验没有复用正式棋盘网格")
	_expect(str(board.get("map_id", "")) == "terracotta_battlefield_v3", "V3 实验没有复用正式棋盘地图")
	_expect(bool(snapshot.get("uses_existing_board_viewport", false)), "V3 实验没有声明复用 BoardViewport")
	_expect(bool(snapshot.get("uses_existing_piece_art", false)), "V3 单位卡没有复用现有棋子立绘")
	_expect(not bool(snapshot.get("unit_has_numeric_stats", true)), "V3 单位卡重新引入了数值属性")
	_expect(int(snapshot.get("action_button_count", 0)) == 2, "底部行动面板不是两个按钮")
	_expect(bool(snapshot.get("action_buttons_vertical", false)), "移动／技能按钮没有上下排列")
	_expect((snapshot.get("red_summary", []) as Array).size() == 3, "赤方头像下不是三项公开信息")
	_expect((snapshot.get("black_summary", []) as Array).size() == 3, "玄方头像下不是三项公开信息")
	var initial_events: Array = snapshot.get("event_rows", [])
	_expect(initial_events.size() == 5, "右侧战局与行动板不是五行信息")
	_expect(initial_events.size() >= 4 and "坐标" in str(initial_events[3]), "右侧战局板缺少坐标信息")
	_expect(not _tree_contains_name_fragment(lab, "Incense"), "V3 实验场景仍含香盘／燃香节点")
	_expect(not _tree_contains_name_fragment(lab, "Morale"), "V3 实验场景仍含士气节点")
	_expect(not _tree_contains_name_fragment(lab, "Strength"), "V3 实验场景仍含兵力节点")
	_expect(_rects_do_not_overlap(lab), "HUD 三列或底部区域发生重叠")

	var capture_result := await _save_viewport(viewport, SCREENSHOT_PATH)
	_expect(capture_result == OK, "无法保存 V3 HUD 实验截图")
	for viewport_size: Vector2i in RESPONSIVE_VIEWPORTS:
		viewport.size = viewport_size
		for _frame: int in 3:
			await process_frame
		_expect(
			_layout_fits_viewport(lab, viewport_size),
			"HUD 在 %dx%d 下溢出或发生区域重叠" % [viewport_size.x, viewport_size.y]
		)
	lab.call("advance_demo_parameters")
	await process_frame
	var changed_snapshot: Dictionary = lab.call("get_lab_snapshot") as Dictionary
	var red_summary: Array = changed_snapshot.get("red_summary", [])
	_expect(red_summary.size() == 3 and "占领 1/3" in str(red_summary[2]), "占旗参数变化没有刷新 HUD")
	_expect(red_summary.size() == 3 and "损失 2" in str(red_summary[1]), "损失棋子参数变化没有刷新 HUD")
	_expect("第 19 回合" in str(changed_snapshot.get("round_text", "")), "回合参数变化没有刷新 HUD")
	_expect("41 秒" in str(changed_snapshot.get("timer_text", "")), "倒计时参数变化没有刷新 HUD")
	var changed_events: Array = changed_snapshot.get("event_rows", [])
	_expect(
		changed_events.size() >= 2 and "×2" in str(changed_events[1]),
		"右侧阵亡事件没有跟随参数变化刷新"
	)

	lab.queue_free()
	viewport.queue_free()
	await process_frame
	_finish()


func _check_chroma_assets() -> void:
	for asset: Dictionary in UI_ASSETS:
		var key := str(asset.get("name", ""))
		var file_name := str(FILE_NAMES.get(key, key))
		var source_path := "res://assets/art/ui/match_hud_v3/source_chroma/%s_chroma_v1.png" % file_name
		var runtime_path := "res://assets/art/ui/match_hud_v3/%s_v1.png" % file_name
		var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
		var runtime := Image.load_from_file(ProjectSettings.globalize_path(runtime_path))
		_expect(source != null and not source.is_empty(), "无法读取紫幕母版：%s" % source_path)
		_expect(runtime != null and not runtime.is_empty(), "无法读取透明成品：%s" % runtime_path)
		if source == null or runtime == null or source.is_empty() or runtime.is_empty():
			continue
		for point: Vector2i in _corner_points(source):
			var color := source.get_pixelv(point)
			_expect(
				color.r >= 0.8 and color.b >= 0.8 and color.g <= 0.25,
				"紫幕母版四角不是高饱和紫：%s" % source_path
			)
		for point: Vector2i in _corner_points(runtime):
			_expect(runtime.get_pixelv(point).a <= 0.02, "抠图成品四角不透明：%s" % runtime_path)
		var center := runtime.get_pixelv(Vector2i(runtime.get_width() / 2, runtime.get_height() / 2))
		if bool(asset.get("opaque_center", true)):
			_expect(center.a >= 0.9, "实体面板中心被误抠：%s" % runtime_path)
		else:
			_expect(center.a <= 0.05, "小地图窗口没有抠成透明：%s" % runtime_path)
	var faction := Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/art/ui/match_hud_v3/faction_summary_plate_v1.png"
	))
	if faction != null and not faction.is_empty():
		var aperture := Vector2i(roundi(faction.get_width() * 0.17), roundi(faction.get_height() * 0.5))
		_expect(faction.get_pixelv(aperture).a <= 0.05, "阵营头像窗没有抠成透明")


func _rects_do_not_overlap(lab: Control) -> bool:
	var left := lab.get_node("SafeMargin/MainRows/BodyBand/LeftRail") as Control
	var center := lab.get_node("SafeMargin/MainRows/BodyBand/CenterColumn") as Control
	var right := lab.get_node("SafeMargin/MainRows/BodyBand/RightRail") as Control
	var board := lab.get_node("SafeMargin/MainRows/BodyBand/CenterColumn/BoardFrame") as Control
	var action := lab.get_node("SafeMargin/MainRows/BodyBand/CenterColumn/ActionPanel") as Control
	return not left.get_global_rect().intersects(center.get_global_rect()) \
		and not center.get_global_rect().intersects(right.get_global_rect()) \
		and not board.get_global_rect().intersects(action.get_global_rect())


func _layout_fits_viewport(lab: Control, viewport_size: Vector2i) -> bool:
	var safe_margin := lab.get_node("SafeMargin") as Control
	var top_band := lab.get_node("SafeMargin/MainRows/TopBand") as Control
	var body_band := lab.get_node("SafeMargin/MainRows/BodyBand") as Control
	var board := lab.get_node("SafeMargin/MainRows/BodyBand/CenterColumn/BoardFrame") as Control
	var mode_buttons := lab.get_node(
		"SafeMargin/MainRows/BodyBand/CenterColumn/ActionPanel/ContentMargin/Content/ModeButtons"
	) as VBoxContainer
	var move_button := lab.get_node(
		"SafeMargin/MainRows/BodyBand/CenterColumn/ActionPanel/ContentMargin/Content/ModeButtons/MoveButton"
	) as Button
	var skill_button := lab.get_node(
		"SafeMargin/MainRows/BodyBand/CenterColumn/ActionPanel/ContentMargin/Content/ModeButtons/SkillButton"
	) as Button
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	return viewport_rect.encloses(safe_margin.get_global_rect()) \
		and not top_band.get_global_rect().intersects(body_band.get_global_rect()) \
		and _rects_do_not_overlap(lab) \
		and board.size.x >= 360.0 \
		and board.size.y >= 280.0 \
		and mode_buttons is VBoxContainer \
		and move_button.position.y < skill_button.position.y


func _tree_contains_name_fragment(node: Node, fragment: String) -> bool:
	if fragment.to_lower() in str(node.name).to_lower():
		return true
	for child: Node in node.get_children():
		if _tree_contains_name_fragment(child, fragment):
			return true
	return false


func _corner_points(image: Image) -> Array[Vector2i]:
	return [
		Vector2i.ZERO,
		Vector2i(image.get_width() - 1, 0),
		Vector2i(0, image.get_height() - 1),
		Vector2i(image.get_width() - 1, image.get_height() - 1),
	]


func _save_viewport(viewport: SubViewport, output_path: String) -> Error:
	RenderingServer.force_draw()
	for _frame: int in 3:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return ERR_CANT_CREATE
	return image.save_png(ProjectSettings.globalize_path(output_path))


func _finish() -> void:
	if _failures.is_empty():
		print("MATCH_HUD_V3_LAYOUT_LAB_PASS screenshot=%s" % SCREENSHOT_PATH)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("MATCH_HUD_V3_LAYOUT_LAB_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
