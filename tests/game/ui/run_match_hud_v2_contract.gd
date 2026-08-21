extends SceneTree

const MATCH_SCREEN_SCENE: PackedScene = preload("res://scenes/game/match/match_screen.tscn")
const LAYOUT_PATH := "res://resources/game/ui/layouts/veilfront_board_ui_layout_v2.json"
const TEST_CELL := Vector2i(5, 5)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_layout_source()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen: Control = MATCH_SCREEN_SCENE.instantiate() as Control
	viewport.add_child(screen)
	await process_frame
	screen.apply_layout_for_size(Vector2(1280, 720))
	screen.render_player_view(_player_view())
	await process_frame

	var hud: Dictionary = screen.get_hud_snapshot()
	_check_catalog_text_layout(screen)
	_expect(str(hud.get("layout", {}).get("active_profile", "")) == "1280x720", "HUD did not select the exported 1280x720 profile")
	_expect(not bool(hud.get("layout", {}).get("text_layer_visibility", {}).get("faction-left/turn", false)), "deleted left turn layer remained enabled")
	_expect(not bool(hud.get("layout", {}).get("text_layer_visibility", {}).get("faction-left/return", false)), "deleted return layer remained enabled")
	_expect(not bool(hud.get("layout", {}).get("text_layer_visibility", {}).get("faction-right/mirror", false)), "deleted mirror layer remained enabled")
	_expect(str(hud.get("faction_left", {}).get("turn", "")) == "正在行动", "red faction plate did not show the active side")
	_expect("旗 1" in str(hud.get("faction_left", {}).get("stats", "")), "red faction plate did not show owned flags")
	_expect("损 3" in str(hud.get("faction_left", {}).get("stats", "")), "red faction plate did not show casualties")
	_expect("损 2" in str(hud.get("faction_right", {}).get("stats", "")), "black faction plate did not show casualties")
	_expect(str(hud.get("objective", {}).get("own_flags", "")) == "我方已发现旗帜: 1/3", "objective label did not preserve the JSON text prefix")
	_expect(str(hud.get("objective", {}).get("own_casualties", "")) == "我方阵亡: 兵*2, 士*1", "own casualty label did not list concrete pieces")
	_expect(str(hud.get("objective", {}).get("enemy_casualties", "")) == "敌方阵亡: 炮*1, 兵*1", "enemy casualty label did not list concrete pieces")

	var left_turn: Label = screen.get_node("MatchHudV2/FactionLeft/FactionLeftTurn") as Label
	var return_button: Button = screen.get_node("MatchHudV2/FactionLeft/ReturnButton") as Button
	var right_turn: Label = screen.get_node("MatchHudV2/FactionRight/FactionRightTurn") as Label
	var pass_button: Button = screen.get_node("MatchHudV2/ObjectiveEvents/PassButton") as Button
	var message_value: Label = screen.get_node("MatchHudV2/ObjectiveEvents/MessageValue") as Label
	_expect(not left_turn.visible, "deleted left turn node remained visible")
	_expect(not right_turn.visible, "deleted right turn node remained visible")
	_expect(not return_button.visible, "deleted return node remained visible")
	_expect(not pass_button.visible, "deleted pass button remained visible")
	_expect(not message_value.visible, "deleted message layer remained visible")
	_expect_anchor_rect(
		screen.get_node("MatchHudV2/FactionLeft/Portrait") as Control,
		Rect2(0.0941176471, 0.16, 0.1882352941, 0.64),
		"left portrait"
	)
	_expect_anchor_rect(
		screen.get_node("MatchHudV2/ObjectiveEvents/OwnFlags") as Control,
		Rect2(0.2951388889, 0.3703703704, 0.5, 0.0648148148),
		"objective flag text"
	)
	var board_position: Label = screen.get_node("MatchHudV2/ObjectiveEvents/BoardPosition") as Label
	_expect(board_position.text == "位置: (x, y)", "new objective position layer did not preserve JSON text")
	_expect(board_position.visible, "new objective position layer is not visible")
	_expect(
		screen.get_node_or_null("MatchHudV2/BoardFrame/BoardViewport/CoordinateReadout") == null,
		"old upper-board coordinate readout still exists"
	)
	_hover_board(screen, TEST_CELL)
	await process_frame
	_expect(board_position.text == "位置: (5, 5)", "board hover did not update the right-side position row")
	_hover_board_away(screen)
	await process_frame
	_expect(board_position.text == "位置: (x, y)", "right-side position row did not restore its JSON placeholder")
	screen.set_tutorial_navigation_enabled(true)
	_expect(return_button.visible, "tutorial navigation could not override the formal HUD deletion")
	screen.set_tutorial_navigation_enabled(false)
	_expect(not return_button.visible, "formal HUD return node did not restore JSON visibility")

	_click_board(screen, TEST_CELL)
	await create_timer(0.3).timeout
	hud = screen.get_hud_snapshot()
	_expect("车" in str(hud.get("unit", {}).get("name", "")), "unit card did not map the selected rook")
	_expect("赤方" in str(hud.get("unit", {}).get("side", "")), "unit card did not show the selected side")
	_expect("5, 5" in str(hud.get("unit", {}).get("position", "")), "unit card did not show the selected coordinate")
	_expect("已选：hud-rook" in str(hud.get("objective", {}).get("selection", "")), "objective panel did not reflect selection")
	_expect(bool(hud.get("piece_info_drawer", {}).get("visible", false)), "piece drawer did not open for the selected piece")
	_expect(str(hud.get("piece_info_drawer", {}).get("layout_structure", "")) == "text_left_actions_right", "piece drawer did not use the requested split layout")
	_expect(int(hud.get("piece_info_drawer", {}).get("visible_action_button_count", 0)) == 2, "rook drawer did not show two rectangular actions")
	_expect(bool(hud.get("piece_info_drawer", {}).get("buttons_horizontal", false)), "rook drawer actions are not horizontal")
	screen.apply_layout_for_size(Vector2(1280, 720))
	await process_frame
	_expect(bool(screen.get_hud_snapshot().get("piece_info_drawer", {}).get("visible", false)), "piece drawer closed during a same-profile layout refresh")

	var minimap: Dictionary = hud.get("minimap", {})
	_expect(bool(minimap.get("uses_player_view_only", false)), "minimap accepted a source broader than PlayerView")
	_expect(int(minimap.get("piece_count", 0)) == 1, "minimap visible piece count mismatch")
	_expect(int(minimap.get("flag_count", 0)) == 1, "minimap discovered flag count mismatch")
	_expect(bool(minimap.get("bird_eye_mode", false)), "minimap did not enter bird-eye mode")
	_expect(
		bool(minimap.get("uses_board_world_renderer", false)),
		"minimap did not reuse the formal bird-eye board renderer"
	)
	_expect(bool(minimap.get("interactive_navigation", false)), "minimap navigation is not interactive")
	_expect(
		str(minimap.get("viewport_indicator_style", "")) == "gray_viewport_area",
		"minimap does not use the gray current-view area"
	)
	_expect(int(minimap.get("wall_segment_count", 0)) == 18, "minimap did not mirror board wall semantics")
	var overview_rect: Rect2 = minimap.get("viewport_rect_normalized", Rect2())
	_expect(overview_rect.size.y > 0.0 and overview_rect.size.y < 1.0, "minimap did not show the main-board viewport")
	if "--capture-screenshot" in OS.get_cmdline_user_args():
		_hover_board(screen, TEST_CELL)
		await process_frame
		_capture_screenshot(viewport)
		_hover_board_away(screen)
	var camera_before: Vector2 = screen.get_board_render_snapshot().get("camera_position", Vector2.ZERO)
	_navigate_minimap_to_top(screen)
	await process_frame
	var motion_snapshot: Dictionary = screen.get_board_render_snapshot()
	var camera_after: Vector2 = motion_snapshot.get("camera_position", Vector2.ZERO)
	var camera_target_y := float(motion_snapshot.get("camera_target_y", camera_after.y))
	var minimap_navigation_duration := float(
		motion_snapshot.get("minimap_navigation_duration", 0.0)
	)
	_expect(
		minimap_navigation_duration > 0.0 and minimap_navigation_duration <= 0.2,
		"minimap navigation is not configured as a rapid smooth move"
	)
	_expect(camera_after.y < camera_before.y, "minimap click did not navigate the main board")
	_expect(
		bool(motion_snapshot.get("camera_motion_active", false)),
		"minimap navigation did not start smooth camera motion"
	)
	_expect(
		camera_after.y > camera_target_y + 1.0,
		"minimap navigation jumped directly to its destination"
	)
	var moving_minimap: Dictionary = screen.get_hud_snapshot().get("minimap", {})
	var moving_overview_rect: Rect2 = moving_minimap.get(
		"viewport_rect_normalized", Rect2()
	)
	_expect(
		moving_overview_rect.position.y < overview_rect.position.y,
		"minimap gray view area did not follow the moving main-board camera"
	)
	await create_timer(0.5).timeout
	var camera_finished: Vector2 = screen.get_board_render_snapshot().get(
		"camera_position", Vector2.ZERO
	)
	_expect(
		absf(camera_finished.y - camera_target_y) <= 1.0,
		"smooth minimap navigation did not settle on its destination"
	)
	_hover_board(screen, Vector2i(5, 20))
	await process_frame
	_expect(
		board_position.text == "位置: (5, 20)",
		"board hover coordinate drifted after camera navigation"
	)
	_hover_board_away(screen)
	var wheel_camera_before: Vector2 = screen.get_board_render_snapshot().get(
		"camera_position", Vector2.ZERO
	)
	_scroll_board(screen, MOUSE_BUTTON_WHEEL_DOWN)
	await process_frame
	var wheel_motion: Dictionary = screen.get_board_render_snapshot()
	var wheel_camera_after: Vector2 = wheel_motion.get("camera_position", Vector2.ZERO)
	var wheel_target_y := float(wheel_motion.get("camera_target_y", wheel_camera_after.y))
	_expect(
		bool(wheel_motion.get("camera_motion_active", false)),
		"mouse-wheel board scroll did not start smooth camera motion"
	)
	_expect(
		wheel_camera_after.y > wheel_camera_before.y and wheel_camera_after.y < wheel_target_y,
		"mouse-wheel board scroll did not interpolate between start and target"
	)
	await create_timer(0.5).timeout
	_zoom_board(screen, 6)
	await process_frame
	var zoomed_minimap: Dictionary = screen.get_hud_snapshot().get("minimap", {})
	var zoomed_overview_rect: Rect2 = zoomed_minimap.get("viewport_rect_normalized", Rect2())
	_expect(zoomed_overview_rect.size.x > 0.0 and zoomed_overview_rect.size.x < 1.0, "zoomed minimap did not expose a horizontally movable gray area")
	var horizontal_before: Vector2 = screen.get_board_render_snapshot().get("camera_position", Vector2.ZERO)
	_navigate_minimap(screen, Vector2(0.1, 0.5))
	await process_frame
	var horizontal_motion: Dictionary = screen.get_board_render_snapshot()
	var horizontal_after: Vector2 = horizontal_motion.get("camera_position", Vector2.ZERO)
	var horizontal_target: Vector2 = horizontal_motion.get("camera_target_position", horizontal_after)
	_expect(horizontal_after.x < horizontal_before.x, "minimap click did not move the zoomed board horizontally")
	_expect(horizontal_after.x > horizontal_target.x + 1.0, "horizontal minimap navigation jumped directly to its destination")
	await create_timer(0.3).timeout
	var horizontal_finished: Vector2 = screen.get_board_render_snapshot().get("camera_position", Vector2.ZERO)
	_expect(horizontal_finished.distance_to(horizontal_target) <= 1.0, "two-dimensional minimap navigation did not settle on its target")
	var mirror_button: Button = screen.find_child("MirrorButton", true, false) as Button
	_expect(mirror_button != null, "HUD mirror button is missing")
	if mirror_button != null:
		_expect(not mirror_button.visible, "deleted mirror button remained visible")
		mirror_button.pressed.emit()
		await process_frame
		minimap = screen.get_hud_snapshot().get("minimap", {})
		_expect(str(minimap.get("display_side", "")) == "black", "minimap did not mirror with the board")

	screen.queue_free()
	viewport.queue_free()
	await process_frame
	if _failures.is_empty():
		print("MATCH_HUD_V2_CONTRACT_PASS catalog=10 profile=1280x720 deletions=true")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("MATCH_HUD_V2_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_layout_source() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_expect(parsed is Dictionary, "HUD layout JSON is invalid")
	if not parsed is Dictionary:
		return
	var layout: Dictionary = parsed
	_expect(str(layout.get("schema_version", "")) == "veilfront-board-ui-layout-v2", "HUD layout schema drifted")
	_expect(str(layout.get("board_rect_meaning", "")) == "default_visible_board_screen_rect", "HUD layout lost its board rectangle semantics")
	_expect(int(layout.get("ui_catalog", []).size()) == 10, "HUD catalog must contain all ten exported slots")
	var assembly_assets := {
		"custom-ui-1787265872199-1": "res://assets/art/ui/terracotta_hud_v2/incense_assembly/round_incense_vertical_v1.png",
		"custom-ui-1787292062912-1": "res://assets/art/ui/terracotta_hud_v2/incense_assembly/piece_info_drawer_frame_v1.png",
		"custom-ui-1787292347530-2": "res://assets/art/ui/terracotta_hud_v2/incense_assembly/dual_incense_bronze_stand_v1.png",
		"custom-ui-1787292377548-3": "res://assets/art/ui/terracotta_hud_v2/incense_assembly/timer_incense_vertical_v1.png",
	}
	var catalog_ids: Array[String] = []
	for catalog_value: Variant in layout.get("ui_catalog", []):
		if not catalog_value is Dictionary:
			continue
		catalog_ids.append(str(catalog_value.get("id", "")))
		var asset_value: Variant = catalog_value.get("asset", null)
		var asset_path := str(asset_value) if asset_value is String else ""
		if not asset_path.is_empty():
			_expect(ResourceLoader.exists(asset_path), "HUD asset is missing: %s" % asset_path)
		var catalog_id := str(catalog_value.get("id", ""))
		if assembly_assets.has(catalog_id):
			_expect(str(catalog_value.get("kind", "")) == "image", "%s 没有使用正式图片资源" % catalog_id)
			_expect(asset_path == str(assembly_assets[catalog_id]), "%s 没有引用燃香组合正式资源" % catalog_id)
	for required_id: String in [
		"faction-left", "faction-right", "unit-info", "objective-events", "minimap",
		"custom-ui-1787265872199-1", "custom-ui-1787292062912-1",
		"custom-ui-1787292347530-2", "custom-ui-1787292377548-3",
		"custom-ui-1787293016650-4",
	]:
		_expect(required_id in catalog_ids, "HUD catalog is missing %s" % required_id)


func _check_catalog_text_layout(screen: Control) -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH)) as Dictionary
	var paths := {
		"faction-left/portrait": "MatchHudV2/FactionLeft/Portrait",
		"faction-left/name": "MatchHudV2/FactionLeft/FactionLeftName",
		"faction-left/stats": "MatchHudV2/FactionLeft/FactionLeftStats",
		"faction-right/portrait": "MatchHudV2/FactionRight/Portrait",
		"faction-right/name": "MatchHudV2/FactionRight/FactionRightName",
		"faction-right/stats": "MatchHudV2/FactionRight/FactionRightStats",
		"unit-info/name": "MatchHudV2/UnitInfo/UnitName",
		"unit-info/glyph": "MatchHudV2/UnitInfo/UnitPortraitGlyph",
		"unit-info/side": "MatchHudV2/UnitInfo/UnitSideStatus",
		"unit-info/position": "MatchHudV2/UnitInfo/UnitPosition",
		"unit-info/state": "MatchHudV2/UnitInfo/UnitState",
		"objective-events/heading": "MatchHudV2/ObjectiveEvents/Heading",
		"objective-events/selection": "MatchHudV2/ObjectiveEvents/SelectionStatus",
		"objective-events/move": "MatchHudV2/ObjectiveEvents/OwnFlags",
		"objective-events/bombard": "MatchHudV2/ObjectiveEvents/OwnCasualties",
		"objective-events/pass": "MatchHudV2/ObjectiveEvents/EnemyCasualties",
		"objective-events/text-1787297730520-1": "MatchHudV2/ObjectiveEvents/BoardPosition",
		"minimap/title": "MatchHudV2/Minimap/Title",
		"custom-ui-1787292062912-1/movement-caption": "MatchHudV2/PieceInfoDrawer/ContentMargin/ContentRow/TextArea/MovementCaption",
		"custom-ui-1787292062912-1/movement-summary": "MatchHudV2/PieceInfoDrawer/ContentMargin/ContentRow/TextArea/MovementSummary",
		"custom-ui-1787292062912-1/move-button": "MatchHudV2/PieceInfoDrawer/ContentMargin/ContentRow/SkillButtons/MoveButton",
		"custom-ui-1787292062912-1/bombard-button": "MatchHudV2/PieceInfoDrawer/ContentMargin/ContentRow/SkillButtons/BombardButton",
		"custom-ui-1787292062912-1/resurrect-button": "MatchHudV2/PieceInfoDrawer/ContentMargin/ContentRow/SkillButtons/ResurrectButton",
		"custom-ui-1787292062912-1/no-skill-button": "MatchHudV2/PieceInfoDrawer/ContentMargin/ContentRow/SkillButtons/NoSkillButton",
		"custom-ui-1787293016650-4/round-number": "MatchHudV2/IncenseTurnClock/RoundDisplaySlot/NumberFloat/SmokeNumber",
		"custom-ui-1787293016650-4/round-caption": "MatchHudV2/IncenseTurnClock/RoundDisplaySlot/NumberFloat/RoundCaption",
	}
	for catalog_value: Variant in layout.get("ui_catalog", []):
		if not catalog_value is Dictionary:
			continue
		var catalog: Dictionary = catalog_value
		var panel_id := str(catalog.get("id", ""))
		for layer_value: Variant in catalog.get("text_layers", []):
			if not layer_value is Dictionary:
				continue
			var layer: Dictionary = layer_value
			var binding_key := "%s/%s" % [panel_id, str(layer.get("id", ""))]
			_expect(paths.has(binding_key), "JSON text layer has no formal HUD binding: %s" % binding_key)
			if not paths.has(binding_key):
				continue
			var control: Control = screen.get_node(str(paths[binding_key])) as Control
			if not bool(layer.get("layout_managed_by_container", false)):
				var rect: Dictionary = layer.get("normalized_rect", {})
				_expect_anchor_rect(control, Rect2(
					float(rect.get("x", 0.0)),
					float(rect.get("y", 0.0)),
					float(rect.get("width", 0.0)),
					float(rect.get("height", 0.0))
				), binding_key)
			_expect(control.visible == bool(layer.get("visible", true)), "%s visibility does not match JSON" % binding_key)
			_expect(control.get_theme_font_size("font_size") == int(layer.get("font_size", 12)), "%s font size does not match JSON" % binding_key)


func _player_view() -> Dictionary:
	return {
		"match_id": "hud-contract",
		"viewer_side": "red",
		"active_side": "red",
		"full_round_index": 18,
		"round_limit_public": 50,
		"terminal": false,
		"board": {"width": 9, "height": 24},
		"visible_cells": [[5, 5], [6, 5], [7, 5], [7, 6], [7, 7]],
		"hidden_detection_cells": [],
		"pieces": [{
			"alive": true,
			"id": "hud-rook",
			"in_reserve": false,
			"piece_type": "rook",
			"position": [5, 5],
			"side": "red",
			"status_tags": ["READY"],
		}],
		"flags": [{
			"capture_progress": 0,
			"capturing_side": "",
			"contested": false,
			"discovered": true,
			"id": "hud-flag",
			"owner": "red",
			"position": [7, 7],
		}],
		"walls": [
			{"side": "red", "status": "INTACT"},
			{"side": "black", "status": "BREACHED"},
		],
		"casualties": [
			{"side": "red", "piece_type": "soldier"},
			{"side": "red", "piece_type": "guard"},
			{"side": "red", "piece_type": "soldier"},
			{"side": "black", "piece_type": "cannon"},
			{"side": "black", "piece_type": "soldier"},
		],
		"capture_ghosts": [],
		"vision_overlays": {"rook_paths": [], "elephant_reveal_zones": [], "elephant_block_fields": []},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _hover_board(screen: Control, cell: Vector2i) -> void:
	var board_viewport: SubViewportContainer = screen.get_node(
		"MatchHudV2/BoardFrame/BoardViewport"
	) as SubViewportContainer
	var hover_surface: Control = board_viewport.get_node("ScreenInputSurface") as Control
	_expect(
		hover_surface.mouse_filter == Control.MOUSE_FILTER_STOP,
		"board screen interaction surface does not own GUI input"
	)
	var event := InputEventMouseMotion.new()
	event.position = board_viewport.get_container_position_for_authority_cell(cell)
	hover_surface.gui_input.emit(event)


func _hover_board_away(screen: Control) -> void:
	var hover_surface: Control = screen.get_node(
		"MatchHudV2/BoardFrame/BoardViewport/ScreenInputSurface"
	) as Control
	hover_surface.mouse_exited.emit()


func _click_board(screen: Control, cell: Vector2i) -> void:
	var board_viewport: SubViewportContainer = screen.get_node(
		"MatchHudV2/BoardFrame/BoardViewport"
	) as SubViewportContainer
	var input_surface: Control = board_viewport.get_node("ScreenInputSurface") as Control
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = board_viewport.get_container_position_for_authority_cell(cell)
	input_surface.gui_input.emit(event)


func _navigate_minimap_to_top(screen: Control) -> void:
	_navigate_minimap(screen, Vector2(0.5, 0.08))


func _navigate_minimap(screen: Control, ratio: Vector2) -> void:
	var minimap: Control = screen.get_node("MatchHudV2/Minimap/TacticalMinimap") as Control
	var board_rect: Rect2 = minimap._board_rect()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = board_rect.position + board_rect.size * ratio.clamp(Vector2.ZERO, Vector2.ONE)
	minimap._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = press.position
	minimap._gui_input(release)


func _scroll_board(screen: Control, button_index: MouseButton) -> void:
	var input_surface: Control = screen.get_node(
		"MatchHudV2/BoardFrame/BoardViewport/ScreenInputSurface"
	) as Control
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.factor = 1.0
	event.position = input_surface.size * 0.5
	input_surface.gui_input.emit(event)


func _zoom_board(screen: Control, steps: int) -> void:
	var input_surface: Control = screen.get_node(
		"MatchHudV2/BoardFrame/BoardViewport/ScreenInputSurface"
	) as Control
	for _step: int in steps:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP
		event.pressed = true
		event.ctrl_pressed = true
		event.factor = 1.0
		event.position = input_surface.size * 0.5
		input_surface.gui_input.emit(event)


func _expect_anchor_rect(control: Control, expected: Rect2, label: String) -> void:
	var actual := Rect2(
		Vector2(control.anchor_left, control.anchor_top),
		Vector2(control.anchor_right - control.anchor_left, control.anchor_bottom - control.anchor_top)
	)
	_expect(
		actual.position.distance_to(expected.position) <= 0.0001 \
		and actual.size.distance_to(expected.size) <= 0.0001,
		"%s anchor rect does not match JSON: %s" % [label, actual]
	)


func _capture_screenshot(viewport: SubViewport) -> void:
	var texture := viewport.get_texture()
	var image := texture.get_image() if texture != null else null
	if image == null:
		_failures.append("HUD screenshot was unavailable")
		return
	var output_path := ProjectSettings.globalize_path("res://evidence/gate2/match-hud-v2-1280x720.png")
	var error := image.save_png(output_path)
	_expect(error == OK, "failed to save HUD screenshot")
