extends SceneTree

const MATCH_SCREEN_SCENE: PackedScene = preload("res://scenes/game/match/match_screen.tscn")
const LAYOUT_PATH := "res://resources/game/ui/layouts/veilfront_board_ui_layout_v2.json"

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
	_expect(str(hud.get("layout", {}).get("active_profile", "")) == "1280x720", "HUD did not select the exported 1280x720 profile")
	_expect(str(hud.get("faction_left", {}).get("turn", "")) == "正在行动", "red faction plate did not show the active side")
	_expect("旗 1" in str(hud.get("faction_left", {}).get("stats", "")), "red faction plate did not show owned flags")
	_expect("损 1" in str(hud.get("faction_right", {}).get("stats", "")), "black faction plate did not show casualties")

	screen.handle_board_point(Vector2i(5, 20))
	await process_frame
	hud = screen.get_hud_snapshot()
	_expect("车" in str(hud.get("unit", {}).get("name", "")), "unit card did not map the selected rook")
	_expect("赤方" in str(hud.get("unit", {}).get("side", "")), "unit card did not show the selected side")
	_expect("5, 20" in str(hud.get("unit", {}).get("position", "")), "unit card did not show the selected coordinate")
	_expect("已选：hud-rook" in str(hud.get("objective", {}).get("selection", "")), "objective panel did not reflect selection")

	var minimap: Dictionary = hud.get("minimap", {})
	_expect(bool(minimap.get("uses_player_view_only", false)), "minimap accepted a source broader than PlayerView")
	_expect(int(minimap.get("piece_count", 0)) == 1, "minimap visible piece count mismatch")
	_expect(int(minimap.get("flag_count", 0)) == 1, "minimap discovered flag count mismatch")
	if "--capture-screenshot" in OS.get_cmdline_user_args():
		_capture_screenshot(viewport)
	var mirror_button: Button = screen.find_child("MirrorButton", true, false) as Button
	_expect(mirror_button != null, "HUD mirror button is missing")
	if mirror_button != null:
		mirror_button.pressed.emit()
		await process_frame
		minimap = screen.get_hud_snapshot().get("minimap", {})
		_expect(str(minimap.get("display_side", "")) == "black", "minimap did not mirror with the board")

	screen.queue_free()
	viewport.queue_free()
	await process_frame
	if _failures.is_empty():
		print("MATCH_HUD_V2_CONTRACT_PASS catalog=6 profile=1280x720")
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
	_expect(int(layout.get("ui_catalog", []).size()) == 6, "HUD catalog must contain the six exported slots")
	for catalog_value: Variant in layout.get("ui_catalog", []):
		if not catalog_value is Dictionary:
			continue
		var asset_value: Variant = catalog_value.get("asset", null)
		var asset_path := str(asset_value) if asset_value is String else ""
		if not asset_path.is_empty():
			_expect(ResourceLoader.exists(asset_path), "HUD asset is missing: %s" % asset_path)


func _player_view() -> Dictionary:
	return {
		"match_id": "hud-contract",
		"viewer_side": "red",
		"active_side": "red",
		"full_round_index": 18,
		"round_limit_public": 50,
		"terminal": false,
		"board": {"width": 9, "height": 24},
		"visible_cells": [[5, 20], [6, 20], [7, 20]],
		"hidden_detection_cells": [],
		"pieces": [{
			"alive": true,
			"id": "hud-rook",
			"in_reserve": false,
			"piece_type": "rook",
			"position": [5, 20],
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
			"position": [7, 20],
		}],
		"walls": [
			{"side": "red", "status": "INTACT"},
			{"side": "black", "status": "BREACHED"},
		],
		"casualties": [{"side": "black", "piece_type": "soldier"}],
		"capture_ghosts": [],
		"vision_overlays": {"rook_paths": [], "elephant_reveal_zones": [], "elephant_block_fields": []},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _capture_screenshot(viewport: SubViewport) -> void:
	var texture := viewport.get_texture()
	var image := texture.get_image() if texture != null else null
	if image == null:
		_failures.append("HUD screenshot was unavailable")
		return
	var output_path := ProjectSettings.globalize_path("res://evidence/gate2/match-hud-v2-1280x720.png")
	var error := image.save_png(output_path)
	_expect(error == OK, "failed to save HUD screenshot")
