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
	_check_catalog_text_layout(screen)
	_expect(str(hud.get("layout", {}).get("active_profile", "")) == "1280x720", "HUD did not select the exported 1280x720 profile")
	_expect(not bool(hud.get("layout", {}).get("text_layer_visibility", {}).get("faction-left/turn", false)), "deleted left turn layer remained enabled")
	_expect(not bool(hud.get("layout", {}).get("text_layer_visibility", {}).get("faction-left/return", false)), "deleted return layer remained enabled")
	_expect(not bool(hud.get("layout", {}).get("text_layer_visibility", {}).get("faction-right/mirror", false)), "deleted mirror layer remained enabled")
	_expect(str(hud.get("faction_left", {}).get("turn", "")) == "正在行动", "red faction plate did not show the active side")
	_expect("旗 1" in str(hud.get("faction_left", {}).get("stats", "")), "red faction plate did not show owned flags")
	_expect("损 1" in str(hud.get("faction_right", {}).get("stats", "")), "black faction plate did not show casualties")
	_expect(str(hud.get("objective", {}).get("own_flags", "")) == "我方已发现旗帜: 1/3", "objective label did not preserve the JSON text prefix")
	_expect(str(hud.get("objective", {}).get("own_casualties", "")) == "我方阵亡: 0", "own casualty label did not preserve the JSON text prefix")
	_expect(str(hud.get("objective", {}).get("enemy_casualties", "")) == "敌方阵亡: 1", "enemy casualty label did not preserve the JSON text prefix")

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
	screen.set_tutorial_navigation_enabled(true)
	_expect(return_button.visible, "tutorial navigation could not override the formal HUD deletion")
	screen.set_tutorial_navigation_enabled(false)
	_expect(not return_button.visible, "formal HUD return node did not restore JSON visibility")

	screen.handle_board_point(Vector2i(5, 20))
	await process_frame
	hud = screen.get_hud_snapshot()
	_expect("车" in str(hud.get("unit", {}).get("name", "")), "unit card did not map the selected rook")
	_expect("赤方" in str(hud.get("unit", {}).get("side", "")), "unit card did not show the selected side")
	_expect("5, 20" in str(hud.get("unit", {}).get("position", "")), "unit card did not show the selected coordinate")
	_expect("已选：hud-rook" in str(hud.get("objective", {}).get("selection", "")), "objective panel did not reflect selection")
	_expect(bool(hud.get("piece_info_drawer", {}).get("visible", false)), "piece drawer did not open for the selected piece")
	screen.apply_layout_for_size(Vector2(1280, 720))
	await process_frame
	_expect(bool(screen.get_hud_snapshot().get("piece_info_drawer", {}).get("visible", false)), "piece drawer closed during a same-profile layout refresh")

	var minimap: Dictionary = hud.get("minimap", {})
	_expect(bool(minimap.get("uses_player_view_only", false)), "minimap accepted a source broader than PlayerView")
	_expect(int(minimap.get("piece_count", 0)) == 1, "minimap visible piece count mismatch")
	_expect(int(minimap.get("flag_count", 0)) == 1, "minimap discovered flag count mismatch")
	if "--capture-screenshot" in OS.get_cmdline_user_args():
		_capture_screenshot(viewport)
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
	var catalog_ids: Array[String] = []
	for catalog_value: Variant in layout.get("ui_catalog", []):
		if not catalog_value is Dictionary:
			continue
		catalog_ids.append(str(catalog_value.get("id", "")))
		var asset_value: Variant = catalog_value.get("asset", null)
		var asset_path := str(asset_value) if asset_value is String else ""
		if not asset_path.is_empty():
			_expect(ResourceLoader.exists(asset_path), "HUD asset is missing: %s" % asset_path)
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
