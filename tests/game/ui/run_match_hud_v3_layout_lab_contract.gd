extends SceneTree

const LAB_SCENE: PackedScene = preload("res://scenes/dev/ui/match_hud_v3_layout_lab.tscn")
const RESPONSIVE_VIEWPORTS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(1680, 720),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = RESPONSIVE_VIEWPORTS[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lab := LAB_SCENE.instantiate() as Control
	viewport.add_child(lab)
	var drawer := lab.find_child("PieceInfoDrawer", true, false) as Control
	drawer.call("show_piece", {"id": "layout-preview", "piece_type": "rook"}, true, false)

	for viewport_size: Vector2i in RESPONSIVE_VIEWPORTS:
		viewport.size = viewport_size
		lab.call("apply_layout_for_size", Vector2(viewport_size))
		for _frame: int in 3:
			await process_frame
		_expect(lab.theme != null, "V3 开发预览没有复用正式主题")
		_expect(_layout_fits_viewport(lab, viewport_size), "HUD 在 %dx%d 下溢出或重叠" % [viewport_size.x, viewport_size.y])
		_expect(_all_action_targets_are_usable(lab), "行动按钮小于 44 像素或没有横向排列")

	var snapshot: Dictionary = lab.call("get_layout_snapshot") as Dictionary
	_expect(str(snapshot.get("schema_version", "")) == "match-hud-v3", "开发预览没有复用正式 HUD 布局脚本")
	_expect(str(snapshot.get("active_profile", "")) == "scene-authored-responsive", "开发预览未启用容器响应式布局")
	_expect(lab.find_child("PieceInfoDrawer", true, false) != null, "开发预览缺少正式棋子信息抽屉")
	_expect(lab.find_child("BoardViewport", true, false) != null, "开发预览缺少正式棋盘视口")
	_expect(not _tree_contains_texture_panel(lab), "开发预览仍用位图承担面板或按钮布局")

	lab.queue_free()
	viewport.queue_free()
	await process_frame
	_finish()


func _layout_fits_viewport(lab: Control, viewport_size: Vector2i) -> bool:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var safe_margin := lab.get_node("SafeMargin") as Control
	var top_band := lab.get_node("SafeMargin/MainRows/TopBand") as Control
	var body_band := lab.get_node("SafeMargin/MainRows/BodyBand") as Control
	var left := lab.get_node("SafeMargin/MainRows/BodyBand/LeftRail") as Control
	var center := lab.get_node("SafeMargin/MainRows/BodyBand/CenterColumn") as Control
	var right := lab.get_node("SafeMargin/MainRows/BodyBand/RightRail") as Control
	var board := lab.get_node("SafeMargin/MainRows/BodyBand/CenterColumn/BoardFrame") as Control
	var action := lab.get_node("SafeMargin/MainRows/BodyBand/CenterColumn/ActionPanel") as Control
	var fits := viewport_rect.encloses(safe_margin.get_global_rect()) \
		and not top_band.get_global_rect().intersects(body_band.get_global_rect()) \
		and not left.get_global_rect().intersects(center.get_global_rect()) \
		and not center.get_global_rect().intersects(right.get_global_rect()) \
		and not board.get_global_rect().intersects(action.get_global_rect()) \
		and board.size.x >= 320.0 and board.size.y >= 260.0
	if not fits:
		var minimap := lab.get_node("SafeMargin/MainRows/BodyBand/LeftRail/MinimapPanel") as Control
		var unit_info := lab.get_node("SafeMargin/MainRows/BodyBand/LeftRail/UnitInfo") as Control
		var objective := lab.get_node("SafeMargin/MainRows/BodyBand/RightRail/ObjectiveEvents") as Control
		var confirmation := lab.get_node("SafeMargin/MainRows/BodyBand/RightRail/Confirmation") as Control
		print("LAYOUT_DIAGNOSTIC viewport=%s safe=%s top=%s body=%s left=%s mini=%s unit=%s center=%s right=%s objective=%s confirmation=%s board=%s action=%s" % [
			viewport_size, safe_margin.get_global_rect(), top_band.get_global_rect(), body_band.get_global_rect(),
			left.get_global_rect(), minimap.get_global_rect(), unit_info.get_global_rect(), center.get_global_rect(),
			right.get_global_rect(), objective.get_global_rect(), confirmation.get_global_rect(), board.get_global_rect(), action.get_global_rect()
		])
	return fits


func _all_action_targets_are_usable(lab: Control) -> bool:
	var move_button := lab.find_child("MoveButton", true, false) as Button
	var skill_button := lab.find_child("SkillButton", true, false) as Button
	if move_button == null or skill_button == null:
		return false
	return move_button.size.y >= 44.0 \
		and skill_button.size.y >= 44.0 \
		and absf(move_button.position.y - skill_button.position.y) <= 2.0 \
		and move_button.position.x < skill_button.position.x


func _tree_contains_texture_panel(node: Node) -> bool:
	if node is TextureButton or node is NinePatchRect:
		return true
	for child: Node in node.get_children():
		if _tree_contains_texture_panel(child):
			return true
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("MATCH_HUD_V3_LAYOUT_LAB_PASS source=production-hud viewports=4")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("MATCH_HUD_V3_LAYOUT_LAB_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
