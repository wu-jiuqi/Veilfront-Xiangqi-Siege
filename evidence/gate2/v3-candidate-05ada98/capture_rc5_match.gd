extends SceneTree

const MATCH_SCREEN_SCENE: PackedScene = preload("res://scenes/game/match/match_screen.tscn")
const OUTPUT_ROOT := "res://evidence/gate2/v3-candidate-05ada98/screenshots"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]
const SIDES: Array[String] = ["red", "black"]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_position(Vector2i(-10000, -10000))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	for resolution: Vector2i in RESOLUTIONS:
		for side: String in SIDES:
			await _capture(resolution, side)
	if _failures.is_empty():
		print("GATE2_RC5_MATCH_CAPTURE_PASS images=6")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("GATE2_RC5_MATCH_CAPTURE_FAIL failures=%d" % _failures.size())
	quit(1)


func _capture(resolution: Vector2i, side: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = resolution
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen: Control = MATCH_SCREEN_SCENE.instantiate() as Control
	viewport.add_child(screen)
	await process_frame
	screen.apply_layout_for_size(Vector2(resolution))
	screen.render_player_view(_player_view(side))
	screen.set_local_interaction_state("CONFIRMING", "%s-soldier" % side, "capture-move")
	for _frame: int in 12:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path := "%s/match-%dx%d-%s.png" % [OUTPUT_ROOT, resolution.x, resolution.y, side]
	if image == null or image.is_empty():
		_failures.append("image unavailable: %s" % output_path)
	elif image.save_png(ProjectSettings.globalize_path(output_path)) != OK:
		_failures.append("save failed: %s" % output_path)
	else:
		print("GATE2_RC5_CAPTURE_PASS size=%dx%d side=%s path=%s" % [resolution.x, resolution.y, side, output_path])
	screen.queue_free()
	viewport.queue_free()
	await process_frame


func _player_view(side: String) -> Dictionary:
	var visible_cells: Array = []
	var frontier_cells: Array = []
	var min_y := 1 if side == "red" else 11
	var max_y := 14 if side == "red" else 24
	var frontier_y := 15 if side == "red" else 10
	for y: int in range(min_y, max_y + 1):
		for x: int in range(1, 10):
			visible_cells.append([x, y])
	for x: int in range(2, 9, 2):
		frontier_cells.append([x, frontier_y])
	var own_y := 4 if side == "red" else 21
	var enemy_side := "black" if side == "red" else "red"
	var enemy_y := 12 if side == "red" else 13
	return {
		"match_id": "gate2-rc5-capture-%s" % side,
		"viewer_side": side, "active_side": side, "action_index": 15,
		"full_round_index": 8, "round_limit_public": 50, "terminal": false,
		"board": {"width": 9, "height": 24}, "visible_cells": visible_cells,
		"hidden_detection_cells": frontier_cells,
		"pieces": [
			{"alive": true, "id": "%s-rook" % side, "in_reserve": false, "piece_type": "rook", "position": [2, own_y], "side": side, "status_tags": ["READY"]},
			{"alive": true, "id": "%s-soldier" % side, "in_reserve": false, "piece_type": "soldier", "position": [5, own_y + (1 if side == "red" else -1)], "side": side, "status_tags": []},
			{"alive": true, "id": "%s-elephant" % side, "in_reserve": false, "piece_type": "elephant", "position": [8, own_y], "side": side, "status_tags": []},
			{"alive": true, "id": "visible-%s-horse" % enemy_side, "in_reserve": false, "piece_type": "horse", "position": [5, enemy_y], "side": enemy_side, "status_tags": ["CONTACT"]},
		],
		"flags": [{"capture_progress": 1, "capturing_side": side, "contested": false, "discovered": true, "id": "%s-flag" % side, "owner": side, "position": [7, own_y + (-1 if side == "red" else 1)]}],
		"walls": [{"side": side, "status": "INTACT"}, {"side": enemy_side, "status": "BREACHED"}],
		"casualties": [{"side": side, "piece_type": "soldier"}, {"side": enemy_side, "piece_type": "cannon"}],
		"capture_ghosts": [],
		"vision_overlays": {"rook_paths": [{"piece_id": "%s-rook" % side, "cells": [[2, own_y], [3, own_y], [4, own_y], [5, own_y]]}], "elephant_reveal_zones": [], "elephant_block_fields": []},
		"contact_intel": [],
	}
