extends SceneTree

const FRONTEND_ROUTES := preload("res://scripts/integration/frontend_routes.gd")
const START_SCREEN_SCENE: PackedScene = preload("res://scenes/game/frontend/start_screen.tscn")
const SETTINGS_SCREEN_SCENE: PackedScene = preload("res://scenes/game/frontend/settings_screen.tscn")
const LEVEL_SELECT_SCENE: PackedScene = preload("res://scenes/game/frontend/level_select.tscn")
const MATCH_SCREEN_SCENE: PackedScene = preload("res://scenes/game/match/match_screen.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var options: Dictionary = _parse_options()
	var screen_id: String = str(options.get("screen", "start"))
	var width: int = int(options.get("width", 1280))
	var height: int = int(options.get("height", 720))
	var output_path: String = str(
		options.get(
			"output",
			"res://.codex-temp/ui-audit/%s-%dx%d.png" % [screen_id, width, height]
		)
	)
	root.size = Vector2i(width, height)
	var screen: Control = _instantiate_screen(screen_id)
	if screen == null:
		push_error("不支持的 UI 审查页面：%s" % screen_id)
		quit(2)
		return
	root.add_child(screen)
	await process_frame
	if screen.has_method("apply_layout_for_size"):
		screen.call("apply_layout_for_size", Vector2(width, height))
	if screen_id == "match":
		screen.call("render_player_view", _preview_player_view())
	for _frame: int in 10:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var texture: ViewportTexture = root.get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null:
		push_error("当前渲染驱动没有提供 UI 审查图像。")
		quit(3)
		return
	var absolute_output: String = ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var error: Error = image.save_png(absolute_output)
	print(
		"UI_AUDIT_CAPTURE_%s screen=%s size=%dx%d path=%s"
		% ["PASS" if error == OK else "FAIL", screen_id, width, height, absolute_output]
	)
	quit(0 if error == OK else 4)


func _instantiate_screen(screen_id: String) -> Control:
	match screen_id:
		"start":
			FRONTEND_ROUTES.request_start_menu_ready()
			return START_SCREEN_SCENE.instantiate() as Control
		"settings":
			return SETTINGS_SCREEN_SCENE.instantiate() as Control
		"level_select":
			var level_select: Control = LEVEL_SELECT_SCENE.instantiate() as Control
			level_select.set("load_saved_progress", false)
			return level_select
		"match":
			return MATCH_SCREEN_SCENE.instantiate() as Control
		_:
			return null


func _parse_options() -> Dictionary:
	var options: Dictionary[String, String] = {}
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--") or "=" not in argument:
			continue
		var separator: int = argument.find("=")
		var key: String = argument.substr(2, separator - 2)
		var value: String = argument.substr(separator + 1)
		options[key] = value
	return options


func _preview_player_view() -> Dictionary:
	var visible_cells: Array = []
	for y: int in range(1, 25):
		for x: int in range(1, 10):
			visible_cells.append([x, y])
	return {
		"match_id": "ui-audit-preview",
		"viewer_side": "red",
		"active_side": "red",
		"action_index": 15,
		"full_round_index": 8,
		"round_limit_public": 50,
		"terminal": false,
		"board": {"width": 9, "height": 24},
		"visible_cells": visible_cells,
		"hidden_detection_cells": [],
		"pieces": [{
			"alive": true,
			"id": "ui-audit-rook",
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
			"id": "ui-audit-flag",
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
			{"side": "black", "piece_type": "cannon"},
		],
		"capture_ghosts": [],
		"vision_overlays": {
			"rook_paths": [],
			"elephant_reveal_zones": [],
			"elephant_block_fields": [],
		},
		"contact_intel": [],
	}
