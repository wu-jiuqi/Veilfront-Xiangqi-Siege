extends SceneTree

const MATCH_SCREEN_SCENE: PackedScene = preload("res://scenes/game/match/match_screen.tscn")
const OUTPUT_PATH := "res://evidence/ui/incense-turn-clock-hud-preview-1280x720.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen: Control = MATCH_SCREEN_SCENE.instantiate() as Control
	viewport.add_child(screen)
	screen.apply_layout_for_size(Vector2(1280, 720))
	screen.render_player_view(_preview_view())
	screen.set_local_interaction_state("SELECTED", "preview-cannon", "")
	var clock := screen.get_node("MatchHudV2/IncenseTurnClock") as IncenseTurnClock
	clock.set_reduced_motion(true)
	clock.set_round(20, 50, false)
	clock.set_timer_remaining_for_test(38.0, false)
	await process_frame
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var viewport_texture := viewport.get_texture()
	if viewport_texture == null:
		push_error("当前渲染驱动没有提供预览纹理。")
		quit(2)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("当前渲染驱动没有提供预览图像。")
		quit(3)
		return
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("INCENSE_HUD_PREVIEW_CAPTURE_%s path=%s" % ["PASS" if result == OK else "FAIL", OUTPUT_PATH])
	screen.queue_free()
	viewport.queue_free()
	await process_frame
	quit(0 if result == OK else 1)


func _preview_view() -> Dictionary:
	var visible_cells: Array = []
	for y: int in range(1, 25):
		for x: int in range(1, 10):
			visible_cells.append([x, y])
	return {
		"match_id": "incense-hud-preview",
		"viewer_side": "red",
		"active_side": "red",
		"action_index": 39,
		"full_round_index": 20,
		"round_limit_public": 50,
		"terminal": false,
		"winner": "",
		"win_reason": "",
		"board": {"width": 9, "height": 24},
		"visible_cells": visible_cells,
		"hidden_detection_cells": [],
		"pieces": [
			{"alive": true, "id": "preview-cannon", "in_reserve": false, "piece_type": "cannon", "position": [2, 3], "side": "red", "status_tags": [], "bombard_ammo": 2},
			{"alive": true, "id": "preview-advisor", "in_reserve": false, "piece_type": "advisor", "position": [4, 2], "side": "red", "status_tags": []},
			{"alive": true, "id": "preview-horse", "in_reserve": false, "piece_type": "horse", "position": [8, 22], "side": "black", "status_tags": []},
		],
		"flags": [
			{"capture_progress": 0, "capturing_side": "", "contested": false, "discovered": true, "id": "preview-flag", "owner": "", "position": [5, 12]},
		],
		"walls": [{"side": "red", "status": "INTACT"}, {"side": "black", "status": "INTACT"}],
		"casualties": [
			{"piece_id": "red-lost", "piece_type": "pawn", "side": "red"},
			{"piece_id": "black-lost", "piece_type": "rook", "side": "black"},
		],
		"capture_ghosts": [],
		"vision_overlays": {"rook_paths": [], "elephant_reveal_zones": [], "elephant_block_fields": []},
		"contact_intel": [],
	}
