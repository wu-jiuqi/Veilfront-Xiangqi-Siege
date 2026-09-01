extends SceneTree

const ONLINE_MATCH_SCENE: PackedScene = preload(
	"res://scenes/game/match/online_match_screen.tscn"
)
const FORMAL_MATCH_STATE = preload("res://scripts/game/domain/match_state.gd")
const TEST_CELL := Vector2i(2, 3)
const SCREENSHOT_PATH := "res://evidence/ui/ui-rebuild-online-match-1280x720.png"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen := ONLINE_MATCH_SCENE.instantiate() as Control
	var board_sub_viewport := screen.get_node(
		"MatchHudV3/SafeMargin/MainRows/BodyBand/CenterColumn/BoardFrame/"
		+ "BoardViewport/BoardSubViewport"
	) as SubViewport
	board_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.add_child(screen)
	for _frame: int in 5:
		await process_frame

	screen.set_session_navigation_enabled(true)
	screen.render_player_view(_player_view())
	await process_frame
	var hud := screen.get_node("MatchHudV3") as Control
	_expect(screen.get("hud_root_path") == NodePath("MatchHudV3"), "正式联机没有绑定 V3 HUD 根节点")
	_expect(hud.get_node_or_null("MarkerButton") == null, "正式 V3 HUD 仍有独立标记按钮")
	var round_compatibility := hud.find_child("RoundIncenseSlot", true, false) as Control
	_expect(round_compatibility != null and not round_compatibility.visible, "教程回合兼容槽必须保持隐藏")
	_expect(hud.find_child("PieceInfoDrawer", true, false) != null, "正式 HUD 缺少统一行动简报")
	_expect((hud.find_child("ReturnButton", true, false) as Button).visible, "联机退出按钮未显示")
	_expect(not (hud.find_child("MirrorButton", true, false) as Button).visible, "联机仍显示镜像按钮")

	_expect(
		hud.theme.resource_path == "res://resources/game/ui/themes/veilfront_ui_theme_v2.tres",
		"正式 HUD 未使用全局统一主题",
	)
	var theme_font := hud.theme.default_font
	_expect(theme_font != null and theme_font.has_char("旗".unicode_at(0)), "全局界面字体不含中文字符")
	_expect((hud.find_child("UnitIntro", true, false) as Label).get_theme_font_size("font_size") >= 12, "棋子介绍字号仍过小")
	_expect((hud.find_child("OwnFlags", true, false) as Label).get_theme_font_size("font_size") >= 13, "战局信息字号仍过小")

	_expect((hud.find_child("Round", true, false) as Label).text == "第 18 回合", "回合状态未动态刷新")
	_expect((hud.find_child("Side", true, false) as Label).text == "赤方行动", "行动方未动态刷新")
	_expect((hud.find_child("RedCaptured", true, false) as Label).text == "旗帜 1/3", "赤方占旗数未动态刷新")
	_expect((hud.find_child("RedLost", true, false) as Label).text == "损失 2", "赤方损失数未动态刷新")
	_expect((hud.find_child("RedCapturing", true, false) as Label).text == "占领 2/3", "赤方占旗进度未动态刷新")
	_expect("兵*1" in (hud.find_child("OwnCasualties", true, false) as Label).text, "右侧我方损失没有真实棋子参数")
	_expect("炮*1" in (hud.find_child("EnemyCasualties", true, false) as Label).text, "右侧敌方损失没有真实棋子参数")
	_expect("坐标" in (hud.find_child("BoardPosition", true, false) as Label).text, "右侧战局板缺少坐标行")

	var marker_result: String = screen.handle_cancel_or_marker(TEST_CELL, Vector2(600, 300))
	_expect(marker_result == "open_marker_menu", "空闲右键没有打开标记菜单")
	_expect((screen.get_node("MarkerMenu") as PopupPanel).visible, "右键标记菜单未显示")
	(screen.get_node("MarkerMenu") as PopupPanel).hide()
	await process_frame

	screen.handle_board_point(TEST_CELL)
	await process_frame
	_expect((hud.find_child("UnitName", true, false) as Label).text == "炮", "棋子名称未随选择刷新")
	_expect("远程攻城" in (hud.find_child("UnitRole", true, false) as Label).text, "棋子定位介绍未随选择刷新")
	_expect("隔一枚棋子" in (hud.find_child("ActionRule", true, false) as Label).text, "行动规则未随选择刷新")
	_expect("区域轰炸" in (hud.find_child("SkillDescription", true, false) as Label).text, "技能描述未随选择刷新")
	var move_button := hud.find_child("MoveButton", true, false) as Button
	var skill_button := hud.find_child("SkillButton", true, false) as Button
	_expect(move_button.get_parent() is HBoxContainer and move_button.position.x < skill_button.position.x, "移动／技能按钮没有横向对齐")
	_expect(skill_button.text == "轰炸" and not skill_button.disabled, "技能按钮未根据炮动态切换")

	var changed_view := _player_view()
	changed_view["full_round_index"] = 19
	changed_view["active_side"] = "black"
	changed_view["action_index"] = 2
	(changed_view["casualties"] as Array).append({"side": "red", "piece_type": "guard"})
	for flag_value: Variant in changed_view["flags"]:
		if flag_value is Dictionary and str(flag_value.get("id", "")) == "capturing":
			flag_value["capture_progress"] = 3
	screen.render_player_view(changed_view)
	await process_frame
	_expect((hud.find_child("Round", true, false) as Label).text == "第 19 回合", "回合参数变化未刷新")
	_expect((hud.find_child("Side", true, false) as Label).text == "玄方行动", "行动方参数变化未刷新")
	_expect((hud.find_child("RedLost", true, false) as Label).text == "损失 3", "损失参数变化未刷新")
	_expect((hud.find_child("RedCapturing", true, false) as Label).text == "占领 3/3", "占旗参数变化未刷新")

	if DisplayServer.get_name() != "headless":
		screen.render_player_view(_player_view())
		board_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		RenderingServer.force_draw()
		for _frame: int in 12:
			await process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
		var screenshot := viewport.get_texture().get_image()
		_expect(screenshot != null and not screenshot.is_empty(), "无法获取正式 V3 HUD 截图")
		if screenshot != null and not screenshot.is_empty():
			_expect(
				screenshot.save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH)) == OK,
				"无法保存正式 V3 HUD 截图"
			)
		board_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	screen.queue_free()
	viewport.queue_free()
	await process_frame
	_finish()


func _player_view() -> Dictionary:
	var formal_state: Dictionary = FORMAL_MATCH_STATE.create(471001)
	var pieces: Array = []
	for piece_value: Variant in formal_state.get("pieces", {}).values():
		if piece_value is Dictionary:
			pieces.append((piece_value as Dictionary).duplicate(true))
	return {
		"match_id": "online-hud-v3-contract",
		"action_index": 1,
		"viewer_side": "red",
		"active_side": "red",
		"full_round_index": 18,
		"round_limit_public": 50,
		"terminal": false,
		"board": {"width": 9, "height": 24},
		"visible_cells": _all_visible_cells(),
		"hidden_detection_cells": [],
		"pieces": pieces,
		"flags": [{
			"capture_progress": 3,
			"capturing_side": "",
			"contested": false,
			"discovered": true,
			"id": "owned",
			"owner": "red",
			"position": [7, 7],
		}, {
			"capture_progress": 2,
			"capturing_side": "red",
			"contested": false,
			"discovered": true,
			"id": "capturing",
			"owner": "",
			"position": [4, 8],
		}],
		"walls": [
			{"side": "red", "status": "INTACT"},
			{"side": "black", "status": "INTACT"},
		],
		"casualties": [
			{"side": "red", "piece_type": "soldier"},
			{"side": "red", "piece_type": "rook"},
			{"side": "black", "piece_type": "cannon"},
		],
		"capture_ghosts": [],
		"vision_overlays": {
			"rook_paths": [],
			"elephant_reveal_zones": [],
			"elephant_block_fields": [],
		},
	}


func _all_visible_cells() -> Array:
	var cells: Array = []
	for y: int in range(1, 25):
		for x: int in range(1, 10):
			cells.append([x, y])
	return cells


func _tree_contains_name_fragment(node: Node, fragment: String) -> bool:
	if fragment.to_lower() in str(node.name).to_lower():
		return true
	for child: Node in node.get_children():
		if _tree_contains_name_fragment(child, fragment):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("ONLINE_MATCH_HUD_V3_CONTRACT_PASS screenshot=%s" % SCREENSHOT_PATH)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("ONLINE_MATCH_HUD_V3_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)
