extends SceneTree

const MATCH_SCREEN_SCENE: PackedScene = preload("res://scenes/game/match/match_screen.tscn")
const OUTPUT_PATH := "res://evidence/ui/ui-rebuild-terminal-dialog-1280x720.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen := MATCH_SCREEN_SCENE.instantiate() as Control
	viewport.add_child(screen)
	screen.apply_layout_for_size(Vector2(1280, 720))
	var view := _preview_view()
	screen.render_player_view(view)
	(screen.get_node("TerminalDialog") as MatchTerminalDialog).show_result(
		view,
		MatchTerminalDialog.CONTEXT_PREVIEW
	)
	for _frame: int in 5:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var viewport_texture := viewport.get_texture()
	if viewport_texture == null:
		push_error("当前渲染驱动没有提供正式结算页预览纹理。")
		quit(2)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("当前渲染驱动没有提供正式结算页预览图像。")
		quit(3)
		return
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("TERMINAL_DIALOG_PREVIEW_%s path=%s" % ["PASS" if result == OK else "FAIL", OUTPUT_PATH])
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
		"match_id": "terminal-preview",
		"viewer_side": "red",
		"active_side": "black",
		"action_index": 35,
		"full_round_index": 18,
		"round_limit_public": 50,
		"terminal": true,
		"winner": "red",
		"win_reason": "three_flags",
		"board": {"width": 9, "height": 24},
		"visible_cells": visible_cells,
		"hidden_detection_cells": [],
		"pieces": [
			{"alive": true, "id": "red-general", "in_reserve": false, "piece_type": "general", "position": [5, 2], "side": "red", "status_tags": []},
			{"alive": true, "id": "red-cannon", "in_reserve": false, "piece_type": "cannon", "position": [2, 13], "side": "red", "status_tags": [], "bombard_ammo": 1},
			{"alive": true, "id": "black-general", "in_reserve": false, "piece_type": "general", "position": [5, 23], "side": "black", "status_tags": []},
		],
		"flags": [
			{"capture_progress": 3, "capturing_side": "", "contested": false, "discovered": true, "id": "flag-a", "owner": "red", "position": [2, 9]},
			{"capture_progress": 3, "capturing_side": "", "contested": false, "discovered": true, "id": "flag-b", "owner": "red", "position": [5, 12]},
			{"capture_progress": 3, "capturing_side": "", "contested": false, "discovered": true, "id": "flag-c", "owner": "red", "position": [8, 16]},
		],
		"walls": [{"side": "red", "status": "INTACT"}, {"side": "black", "status": "BREACHED"}],
		"casualties": [
			{"piece_id": "red-lost-1", "piece_type": "pawn", "side": "red"},
			{"piece_id": "red-lost-2", "piece_type": "horse", "side": "red"},
			{"piece_id": "black-lost-1", "piece_type": "pawn", "side": "black"},
			{"piece_id": "black-lost-2", "piece_type": "pawn", "side": "black"},
			{"piece_id": "black-lost-3", "piece_type": "rook", "side": "black"},
		],
		"capture_ghosts": [],
		"vision_overlays": {"rook_paths": [], "elephant_reveal_zones": [], "elephant_block_fields": []},
		"contact_intel": [],
	}
