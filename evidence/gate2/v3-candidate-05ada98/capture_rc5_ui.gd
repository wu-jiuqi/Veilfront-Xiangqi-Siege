extends SceneTree

const LEVEL_SELECT_SCENE := preload("res://scenes/game/frontend/level_select.tscn")
const TUTORIAL_LEVEL_SCENE := preload("res://scenes/game/tutorial/tutorial_level.tscn")
const ONLINE_MATCH_SCENE := preload("res://scenes/game/match/online_match_screen.tscn")
const MATCH_HUD_LAB_SCENE := preload("res://scenes/dev/ui/match_hud_v3_layout_lab.tscn")
const LEVEL_HUD_LAB_SCENE := preload("res://scenes/dev/ui/level_gameplay_hud_lab.tscn")
const FORMAL_MATCH_STATE := preload("res://scripts/game/domain/match_state.gd")
const OUTPUT_ROOT := "res://evidence/gate2/v3-candidate-05ada98/screenshots"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _options()
	var capture_type := str(options.get("type", "level-select"))
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_position(Vector2i(-10000, -10000))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	var target: Control
	var output_name := capture_type + ".png"
	match capture_type:
		"level-select":
			target = LEVEL_SELECT_SCENE.instantiate() as Control
			target.set("load_saved_progress", false)
		"online-match":
			target = ONLINE_MATCH_SCENE.instantiate() as Control
		"match-hud-lab":
			target = MATCH_HUD_LAB_SCENE.instantiate() as Control
		"level-hud-lab":
			target = LEVEL_HUD_LAB_SCENE.instantiate() as Control
		"tutorial-t0", "tutorial-t3", "tutorial-pause":
			var level_id := "T3" if capture_type == "tutorial-t3" else "T0"
			root.set_meta("veilfront_selected_level_id", level_id)
			target = TUTORIAL_LEVEL_SCENE.instantiate() as Control
		_:
			push_error("unknown capture type: %s" % capture_type)
			quit(2)
			return
	root.add_child(target)
	for _frame: int in 12:
		await process_frame
	if capture_type == "online-match":
		target.call("set_session_navigation_enabled", true)
		target.call("render_player_view", _online_view())
		var board_sub := target.get_node("MatchHudV3/SafeMargin/MainRows/BodyBand/CenterColumn/BoardFrame/BoardViewport/BoardSubViewport") as SubViewport
		board_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	elif capture_type == "tutorial-pause":
		(target.get_node("TutorialPauseMenu") as Control).call("open_menu")
	for _frame: int in 12:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image := root.get_texture().get_image()
	var output_path := "%s/%s" % [OUTPUT_ROOT, output_name]
	if image == null or image.is_empty():
		push_error("RC5 UI capture unavailable: %s" % output_path)
		quit(3)
		return
	var result := image.save_png(ProjectSettings.globalize_path(output_path))
	if result != OK:
		push_error("RC5 UI capture save failed: %s" % output_path)
		quit(4)
		return
	print("GATE2_RC5_UI_CAPTURE_PASS type=%s path=%s" % [capture_type, output_path])
	quit(0)


func _options() -> Dictionary:
	var result := {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--type="):
			result["type"] = argument.trim_prefix("--type=")
	return result


func _online_view() -> Dictionary:
	var state: Dictionary = FORMAL_MATCH_STATE.create(471001)
	var pieces: Array = []
	for piece_value: Variant in state.get("pieces", {}).values():
		if piece_value is Dictionary:
			pieces.append((piece_value as Dictionary).duplicate(true))
	var cells: Array = []
	for y: int in range(1, 25):
		for x: int in range(1, 10):
			cells.append([x, y])
	return {
		"match_id": "rc5-online-capture", "action_index": 1, "viewer_side": "red", "active_side": "red",
		"full_round_index": 18, "round_limit_public": 50, "terminal": false,
		"board": {"width": 9, "height": 24}, "visible_cells": cells, "hidden_detection_cells": [],
		"pieces": pieces,
		"flags": [{"capture_progress": 3, "capturing_side": "", "contested": false, "discovered": true, "id": "owned", "owner": "red", "position": [7, 7]}],
		"walls": [{"side": "red", "status": "INTACT"}, {"side": "black", "status": "INTACT"}],
		"casualties": [{"side": "red", "piece_type": "soldier"}, {"side": "black", "piece_type": "cannon"}],
		"capture_ghosts": [],
		"vision_overlays": {"rook_paths": [], "elephant_reveal_zones": [], "elephant_block_fields": []},
	}
