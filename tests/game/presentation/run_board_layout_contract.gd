extends SceneTree

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")
const MATCH_SCREEN_SCENE: PackedScene = preload("res://scenes/game/match/match_screen.tscn")
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1680, 720),
	Vector2i(1280, 800),
	Vector2i(1280, 960),
	Vector2i(1920, 1080),
]
const EXPECTED_PROFILES := {
	"1280x720": "1280x720",
	"1680x720": "1680x720",
	"1280x800": "1280x800",
	"1280x960": "1280x960",
}
const EXPECTED_BOARD_RECTS := {
	"1280x720": Rect2(340, 32, 600, 544),
	"1680x720": Rect2(341, 104, 998, 450),
	"1280x800": Rect2(260, 116, 760, 500),
	"1280x960": Rect2(260, 139, 760, 600),
}
const EXPECTED_UI_RECTS := {
	"1280x720": {
		"faction-left": Rect2(48, 10, 306, 120),
		"faction-right": Rect2(928, 10, 303, 119),
		"unit-info": Rect2(129, 408, 184, 246),
		"objective-events": Rect2(916, 220, 288, 432),
		"minimap": Rect2(64, 130, 241, 264),
		"custom-ui-1787265872199-1": Rect2(1168, 272, 40, 408),
		"custom-ui-1787292062912-1": Rect2(296, 584, 648, 56),
		"custom-ui-1787292347530-2": Rect2(64, 676, 1152, 40),
		"custom-ui-1787292377548-3": Rect2(72, 443, 48, 232),
		"custom-ui-1787293016650-4": Rect2(1104, 160, 104, 96),
	},
	"1680x720": {
		"faction-left": Rect2(24, 70, 335, 100),
		"faction-right": Rect2(1322, 70, 335, 100),
		"unit-info": Rect2(24, 458, 234, 238),
		"objective-events": Rect2(1412, 183, 244, 268),
		"minimap": Rect2(1436, 516, 221, 184),
		"custom-ui-1787265872199-1": Rect2(1533, 168, 53, 496),
		"custom-ui-1787292062912-1": Rect2(305, 592, 903, 88),
		"custom-ui-1787292347530-2": Rect2(84, 664, 1512, 40),
		"custom-ui-1787292377548-3": Rect2(95, 432, 63, 232),
		"custom-ui-1787293016650-4": Rect2(1449, 160, 137, 96),
	},
	"1280x800": {
		"faction-left": Rect2(18, 78, 255, 111),
		"faction-right": Rect2(1007, 78, 255, 111),
		"unit-info": Rect2(18, 509, 178, 264),
		"objective-events": Rect2(1076, 203, 186, 298),
		"minimap": Rect2(1094, 573, 168, 204),
		"custom-ui-1787265872199-1": Rect2(1168, 187, 40, 551),
		"custom-ui-1787292062912-1": Rect2(232, 658, 688, 98),
		"custom-ui-1787292347530-2": Rect2(64, 738, 1152, 44),
		"custom-ui-1787292377548-3": Rect2(72, 480, 48, 258),
		"custom-ui-1787293016650-4": Rect2(1104, 178, 104, 107),
	},
	"1280x960": {
		"faction-left": Rect2(18, 93, 255, 133),
		"faction-right": Rect2(1007, 93, 255, 133),
		"unit-info": Rect2(18, 611, 178, 317),
		"objective-events": Rect2(1076, 244, 186, 357),
		"minimap": Rect2(1094, 688, 168, 245),
		"custom-ui-1787265872199-1": Rect2(1168, 224, 40, 661),
		"custom-ui-1787292062912-1": Rect2(232, 789, 688, 117),
		"custom-ui-1787292347530-2": Rect2(64, 885, 1152, 53),
		"custom-ui-1787292377548-3": Rect2(72, 576, 48, 309),
		"custom-ui-1787293016650-4": Rect2(1104, 213, 104, 128),
	},
}

var _failures: Array[String] = []
var _capture_screenshots: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_screenshots = "--capture-screenshots" in OS.get_cmdline_user_args()
	_check_coordinate_contract()
	var snapshots: Array[Dictionary] = []
	for resolution: Vector2i in RESOLUTIONS:
		var snapshot: Dictionary = await _check_resolution(resolution)
		snapshots.append(snapshot)
	if _capture_screenshots:
		_write_snapshots(snapshots)

	if _failures.is_empty():
		print("BOARD_LAYOUT_CONTRACT_PASS resolutions=%d" % RESOLUTIONS.size())
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("BOARD_LAYOUT_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_coordinate_contract() -> void:
	_expect(
		Mapper.authority_to_display(Vector2i(5, 1), "red").y == 23,
		"red headquarters must render at the bottom"
	)
	_expect(
		Mapper.authority_to_display(Vector2i(5, 24), "black").y == 23,
		"black headquarters must render at the bottom"
	)
	var authority_cells: Array[Vector2i] = [
		Vector2i(1, 1),
		Vector2i(9, 1),
		Vector2i(1, 24),
		Vector2i(9, 24),
		Vector2i(5, 12),
	]
	for authority_cell: Vector2i in authority_cells:
		var red_display: Vector2i = Mapper.authority_to_display(authority_cell, "red")
		var black_display: Vector2i = Mapper.authority_to_display(authority_cell, "black")
		_expect(
			red_display + black_display == Vector2i(8, 23),
			"red/black display cells must be 180-degree mirrors for %s" % authority_cell
		)
		_expect(
			Mapper.display_to_authority(red_display, "red") == authority_cell,
			"red inverse mapping failed for %s" % authority_cell
		)
		_expect(
			Mapper.display_to_authority(black_display, "black") == authority_cell,
			"black inverse mapping failed for %s" % authority_cell
		)

	var red_x_step: float = Mapper.authority_to_world(
		Vector2i(2, 12), "red", Vector2(128.0, 128.0)
	).distance_to(Mapper.authority_to_world(
		Vector2i(1, 12), "red", Vector2(128.0, 128.0)
	))
	var red_y_step: float = Mapper.authority_to_world(
		Vector2i(1, 13), "red", Vector2(128.0, 128.0)
	).distance_to(Mapper.authority_to_world(
		Vector2i(1, 12), "red", Vector2(128.0, 128.0)
	))
	_expect(is_equal_approx(red_x_step, red_y_step), "authority world point spacing must be square")


func _check_resolution(resolution: Vector2i) -> Dictionary:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = resolution
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var match_screen: Control = MATCH_SCREEN_SCENE.instantiate() as Control
	viewport.add_child(match_screen)
	if not match_screen.has_method("apply_layout_for_size") \
	or not match_screen.has_method("get_layout_snapshot"):
		_failures.append("%s MatchScreen controller failed to load" % resolution)
		match_screen.queue_free()
		viewport.queue_free()
		await process_frame
		return {"resolution": [resolution.x, resolution.y], "controller_loaded": false}
	match_screen.apply_layout_for_size(Vector2(resolution))
	match_screen.render_player_view(_build_layout_view())
	match_screen.set_local_interaction_state("CONFIRMING", "layout-soldier", "layout-move")
	await process_frame
	await process_frame

	var snapshot: Dictionary = match_screen.get_layout_snapshot()
	var spacing: Vector2 = snapshot.get("point_spacing", Vector2.ZERO)
	var board_rect: Rect2 = snapshot.get("board_rect", Rect2())
	var board_camera: Camera2D = match_screen.get_node("MatchHudV2/BoardFrame/BoardViewport/BoardSubViewport/BoardWorld/BoardCamera2D") as Camera2D
	var board_scroll_bar: Control = match_screen.get_node_or_null(
		"MatchHudV2/BoardFrame/BoardViewport/VerticalScrollBar"
	) as Control
	var board_motion: Dictionary = match_screen.get_board_render_snapshot()
	var resolution_key := "%dx%d" % [resolution.x, resolution.y]
	_expect(
		not board_camera.position_smoothing_enabled,
		"%s native camera smoothing competes with explicit scroll tween" % resolution
	)
	_expect(board_scroll_bar == null, "%s board still exposes an unwanted scroll bar" % resolution)
	_expect(str(board_motion.get("camera_pan_axes", "")) == "xy", "%s board camera is not configured for two-dimensional navigation" % resolution)
	var scroll_duration := float(board_motion.get("camera_scroll_duration", 0.0))
	_expect(scroll_duration > 0.0, "%s board camera scrolling has no interpolation duration" % resolution)
	_expect(scroll_duration <= 0.5, "%s board camera interpolation is too sluggish" % resolution)
	var minimap_duration := float(board_motion.get("minimap_navigation_duration", 0.0))
	_expect(minimap_duration > 0.0, "%s minimap navigation has no interpolation duration" % resolution)
	_expect(minimap_duration <= 0.2, "%s minimap navigation is not rapid enough" % resolution)
	_expect(absf(spacing.x - spacing.y) <= 0.01, "%s point spacing is not square: %s" % [resolution, spacing])
	_expect(spacing.x > 0.0, "%s point spacing must be positive" % resolution)
	_expect(board_rect.position.x >= 0.0 and board_rect.end.x <= resolution.x + 0.5, "%s board is horizontally clipped" % resolution)
	_expect(board_rect.position.y >= 0.0 and board_rect.end.y <= resolution.y + 0.5, "%s board is vertically clipped" % resolution)
	_expect(
		spacing.x * 9.0 > board_rect.size.x + 0.5,
		"%s board did not start at the requested maximum zoom" % resolution
	)
	_expect(bool(snapshot.get("main_buttons_inside", false)), "%s main action buttons are clipped" % resolution)
	_expect(float(snapshot.get("main_button_min_height", 0.0)) >= 44.0, "%s main buttons are below 44 px" % resolution)
	_expect(bool(snapshot.get("compact", false)) == (resolution.x < 1100), "%s responsive breakpoint mismatch" % resolution)
	_expect(bool(snapshot.get("central_confirmation_ui_removed", false)), "%s central confirmation UI still exists" % resolution)
	_expect(bool(snapshot.get("confirming_action_button_inside", false)), "%s confirming move button is clipped" % resolution)
	_expect(float(snapshot.get("confirming_action_button_min_height", 0.0)) >= 44.0, "%s confirming move button is below 44 px" % resolution)
	_expect(str(snapshot.get("confirming_action_button_text", "")) == "确认移动", "%s move button did not expose its confirm state" % resolution)
	_expect(
		str(snapshot.get("board_rect_meaning", "")) == "default_visible_board_screen_rect",
		"%s board rectangle semantics drifted from the exported JSON" % resolution
	)
	var ui_rects: Dictionary = snapshot.get("ui_rects", {})
	for ui_id: String in [
		"faction-left", "faction-right", "unit-info", "objective-events", "minimap",
		"custom-ui-1787265872199-1", "custom-ui-1787292062912-1",
		"custom-ui-1787292347530-2", "custom-ui-1787292377548-3",
		"custom-ui-1787293016650-4",
	]:
		_expect(ui_rects.has(ui_id), "%s missing HUD slot %s" % [resolution, ui_id])
		if ui_rects.has(ui_id):
			var ui_rect: Rect2 = ui_rects.get(ui_id, Rect2())
			_expect(ui_rect.position.x >= -0.5 and ui_rect.position.y >= -0.5, "%s %s starts outside screen" % [resolution, ui_id])
			_expect(ui_rect.end.x <= resolution.x + 0.5 and ui_rect.end.y <= resolution.y + 0.5, "%s %s exceeds screen" % [resolution, ui_id])
	var minimap: Dictionary = snapshot.get("minimap", {})
	_expect(bool(minimap.get("uses_player_view_only", false)), "%s minimap is not PlayerView-only" % resolution)
	_expect(
		bool(minimap.get("uses_board_world_renderer", false)),
		"%s minimap does not reuse the formal board renderer" % resolution
	)
	_expect(
		str(minimap.get("viewport_indicator_style", "")) == "gray_viewport_area",
		"%s minimap does not use the gray current-view area" % resolution
	)
	_expect(int(minimap.get("piece_count", 0)) == 3, "%s minimap did not consume visible pieces" % resolution)
	_expect(int(minimap.get("flag_count", 0)) == 1, "%s minimap did not consume discovered flags" % resolution)

	if EXPECTED_BOARD_RECTS.has(resolution_key):
		_expect(str(snapshot.get("active_profile", "")) == str(EXPECTED_PROFILES[resolution_key]), "%s selected the wrong JSON profile" % resolution)
		_expect(_rect_is_equal(board_rect, EXPECTED_BOARD_RECTS[resolution_key]), "%s board rect does not match JSON: %s" % [resolution, board_rect])
		var expected_ui: Dictionary = EXPECTED_UI_RECTS[resolution_key]
		for ui_id: String in expected_ui.keys():
			_expect(_rect_is_equal(ui_rects.get(ui_id, Rect2()), expected_ui[ui_id]), "%s %s rect does not match JSON" % [resolution, ui_id])

	var image_path: String = "res://evidence/gate2/i1-s4-%dx%d.png" % [resolution.x, resolution.y]
	if _capture_screenshots:
		var viewport_texture: ViewportTexture = viewport.get_texture()
		if viewport_texture == null:
			_failures.append("rendering driver did not provide viewport texture: %s" % image_path)
		else:
			var image: Image = viewport_texture.get_image()
			if image == null:
				_failures.append("viewport image was unavailable: %s" % image_path)
			else:
				var save_error: Error = image.save_png(ProjectSettings.globalize_path(image_path))
				_expect(save_error == OK, "failed to save screenshot: %s" % image_path)

	match_screen.queue_free()
	viewport.queue_free()
	await process_frame
	return {
		"resolution": [resolution.x, resolution.y],
		"compact": snapshot.get("compact", false),
		"point_spacing": [spacing.x, spacing.y],
		"board_rect": [board_rect.position.x, board_rect.position.y, board_rect.size.x, board_rect.size.y],
		"main_buttons_inside": snapshot.get("main_buttons_inside", false),
		"main_button_min_height": snapshot.get("main_button_min_height", 0.0),
		"central_confirmation_ui_removed": snapshot.get("central_confirmation_ui_removed", false),
		"confirming_action_button_inside": snapshot.get("confirming_action_button_inside", false),
		"confirming_action_button_min_height": snapshot.get("confirming_action_button_min_height", 0.0),
		"screenshot": image_path if _capture_screenshots else "pending_capture",
	}


func _write_snapshots(snapshots: Array[Dictionary]) -> void:
	var output_path: String = ProjectSettings.globalize_path(
		"res://evidence/gate2/iteration1-s4-layout-snapshots.json"
	)
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to write layout snapshots")
		return
	file.store_string(JSON.stringify({"schema_version": "veilfront-layout-snapshot-v1", "snapshots": snapshots}, "\t") + "\n")


func _build_layout_view() -> Dictionary:
	var visible_cells: Array = []
	for authority_y: int in range(1, 8):
		for authority_x: int in range(1, 10):
			visible_cells.append([authority_x, authority_y])
	return {
		"viewer_side": "red",
		"board": {"width": 9, "height": 24},
		"visible_cells": visible_cells,
		"hidden_detection_cells": [],
		"pieces": [
			{"alive": true, "id": "layout-rook", "in_reserve": false, "piece_type": "rook", "position": [1, 3], "side": "red", "status_tags": []},
			{"alive": true, "id": "layout-elephant", "in_reserve": false, "piece_type": "elephant", "position": [5, 3], "side": "red", "status_tags": []},
			{"alive": true, "id": "layout-soldier", "in_reserve": false, "piece_type": "soldier", "position": [5, 4], "side": "red", "status_tags": []},
		],
		"flags": [{"capture_progress": 0, "capturing_side": "", "contested": false, "discovered": true, "id": "layout-flag", "owner": "", "position": [7, 6]}],
		"walls": [{"side": "red", "status": "INTACT"}, {"side": "black", "status": "INTACT"}],
		"capture_ghosts": [{"piece_id": "layout-ghost", "piece_type": "horse", "position": [3, 5], "side": "red"}],
		"vision_overlays": {
			"rook_paths": [{"piece_id": "layout-rook", "cells": [[1, 3], [2, 3], [3, 3], [4, 3]]}],
			"elephant_reveal_zones": [{"piece_id": "layout-elephant", "cells": [
				[3, 1], [4, 1], [5, 1],
				[3, 2], [4, 2], [5, 2], [6, 2],
				[3, 3], [4, 3], [5, 3], [6, 3], [7, 3],
				[4, 4], [5, 4], [6, 4], [7, 4],
				[5, 5], [6, 5], [7, 5],
			]}],
			"elephant_block_fields": [{"piece_id": "layout-elephant", "cells": [
				[4, 2], [5, 2], [6, 2],
				[4, 3], [5, 3], [6, 3],
				[4, 4], [5, 4], [6, 4],
			]}],
		},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _rect_is_equal(actual: Rect2, expected: Rect2) -> bool:
	return actual.position.distance_to(expected.position) <= 0.51 \
		and actual.size.distance_to(expected.size) <= 0.51
