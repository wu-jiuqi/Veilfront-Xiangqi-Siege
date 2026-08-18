extends SceneTree

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")
const MATCH_SCREEN_SCENE: PackedScene = preload("res://scenes/game/match/match_screen.tscn")
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
]

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
	match_screen.apply_layout_for_size(Vector2(resolution))
	match_screen.render_player_view(_build_layout_view())
	match_screen.set_local_interaction_state("CONFIRMING", "layout-advisor", "layout-resurrect")
	await process_frame
	await process_frame

	var snapshot: Dictionary = match_screen.get_layout_snapshot()
	var spacing: Vector2 = snapshot.get("point_spacing", Vector2.ZERO)
	var board_rect: Rect2 = snapshot.get("board_rect", Rect2())
	_expect(absf(spacing.x - spacing.y) <= 0.01, "%s point spacing is not square: %s" % [resolution, spacing])
	_expect(spacing.x > 0.0, "%s point spacing must be positive" % resolution)
	_expect(board_rect.position.x >= 0.0 and board_rect.end.x <= resolution.x + 0.5, "%s board is horizontally clipped" % resolution)
	_expect(board_rect.position.y >= 0.0 and board_rect.end.y <= resolution.y + 0.5, "%s board is vertically clipped" % resolution)
	_expect(spacing.x * 9.0 <= board_rect.size.x + 0.5, "%s nine files do not fit the board frame" % resolution)
	_expect(bool(snapshot.get("main_buttons_inside", false)), "%s main action buttons are clipped" % resolution)
	_expect(float(snapshot.get("main_button_min_height", 0.0)) >= 44.0, "%s main buttons are below 44 px" % resolution)
	_expect(bool(snapshot.get("compact", false)) == (resolution.x < 1100), "%s responsive breakpoint mismatch" % resolution)
	_expect(bool(snapshot.get("confirmation_panel_inside", false)), "%s confirmation panel is clipped" % resolution)
	_expect(bool(snapshot.get("confirmation_prompt_inside", false)), "%s confirmation prompt is clipped" % resolution)
	_expect(bool(snapshot.get("confirmation_buttons_inside", false)), "%s confirmation buttons are clipped" % resolution)
	_expect(float(snapshot.get("confirmation_button_min_height", 0.0)) >= 44.0, "%s confirmation buttons are below 44 px" % resolution)
	_expect(not str(snapshot.get("confirmation_prompt_text", "")).is_empty(), "%s confirmation prompt is empty" % resolution)

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
		"confirmation_panel_inside": snapshot.get("confirmation_panel_inside", false),
		"confirmation_prompt_inside": snapshot.get("confirmation_prompt_inside", false),
		"confirmation_buttons_inside": snapshot.get("confirmation_buttons_inside", false),
		"confirmation_button_min_height": snapshot.get("confirmation_button_min_height", 0.0),
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
