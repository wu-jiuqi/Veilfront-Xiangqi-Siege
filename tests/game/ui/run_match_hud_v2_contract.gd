extends SceneTree

const MATCH_SCREEN_SCENE := preload("res://scenes/game/match/match_screen.tscn")
const TEST_CELL := Vector2i(5, 5)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen := MATCH_SCREEN_SCENE.instantiate() as Control
	viewport.add_child(screen)
	await process_frame
	await process_frame
	screen.apply_layout_for_size(Vector2(1280, 720))
	screen.render_player_view(_player_view())
	await process_frame

	var hud := screen.get_node("MatchHudV2") as Control
	_expect(hud != null, "formal match HUD did not instantiate")
	_expect(
		hud.theme.resource_path == "res://resources/game/ui/themes/veilfront_ui_theme_v2.tres",
		"formal match HUD must use the rebuilt unified theme",
	)
	var source := FileAccess.get_file_as_string("res://scenes/game/ui/match_hud_v3.tscn")
	_expect(not source.contains("match_hud_v3/"), "formal HUD still depends on layout-defining panel PNGs")
	_expect(not source.contains("StyleBoxTexture"), "formal HUD must use scalable panel and button surfaces")
	var snapshot: Dictionary = screen.get_hud_snapshot()
	_expect(
		str(snapshot.get("layout", {}).get("active_profile", "")) == "scene-authored-responsive",
		"formal HUD did not use the container-authored responsive profile",
	)

	var top_band := hud.get_node("SafeMargin/MainRows/TopBand") as Control
	var body_band := hud.get_node("SafeMargin/MainRows/BodyBand") as Control
	var left_rail := hud.get_node("SafeMargin/MainRows/BodyBand/LeftRail") as Control
	var center := hud.get_node("SafeMargin/MainRows/BodyBand/CenterColumn") as Control
	var right_rail := hud.get_node("SafeMargin/MainRows/BodyBand/RightRail") as Control
	var board := hud.find_child("BoardFrame", true, false) as Control
	_expect(top_band.get_global_rect().end.y <= body_band.get_global_rect().position.y + 0.5, "top status overlaps the battle area")
	_expect(left_rail.get_global_rect().end.x <= center.get_global_rect().position.x + 0.5, "left rail overlaps the board")
	_expect(center.get_global_rect().end.x <= right_rail.get_global_rect().position.x + 0.5, "right rail overlaps the board")
	_expect(board.size.x >= 500.0 and board.size.y >= 360.0, "board viewport is too small at 1280x720")
	_expect(hud.get_viewport_rect().encloses(hud.get_global_rect()), "formal HUD exceeds the viewport")

	for panel_name: String in ["FactionLeft", "TurnStatus", "FactionRight", "MinimapPanel", "UnitInfo", "ActionPanel", "ObjectiveEvents", "Confirmation"]:
		var panel := hud.find_child(panel_name, true, false) as Control
		_expect(panel != null, "%s panel is missing" % panel_name)
		if panel != null:
			_expect(panel.get_theme_stylebox(&"panel") is StyleBoxFlat, "%s must use a scalable surface" % panel_name)
	for button_name: String in ["ReturnButton", "MirrorButton", "MoveButton", "SkillButton", "PassButton", "ConfirmButton", "CancelButton"]:
		var button := hud.find_child(button_name, true, false) as Button
		_expect(button != null, "%s is missing" % button_name)
		if button == null:
			continue
		_expect(button.custom_minimum_size.y >= 44.0, "%s is below the interaction target" % button_name)
		_expect(button.has_method("set_reduced_motion"), "%s must use the reusable motion button" % button_name)
		_expect(button.get_theme_stylebox(&"normal") is StyleBoxFlat, "%s must use a scalable button surface" % button_name)

	_expect((hud.find_child("Round", true, false) as Label).text == "第 18 回合", "round status did not refresh")
	_expect((hud.find_child("Side", true, false) as Label).text == "赤方行动", "active side did not refresh")
	_expect("旗帜 1/3" in (hud.find_child("RedCaptured", true, false) as Label).text, "red flag state did not refresh")
	_expect("兵*2" in (hud.find_child("OwnCasualties", true, false) as Label).text, "own casualty details did not refresh")

	screen.handle_board_point(TEST_CELL)
	await process_frame
	_expect((hud.find_child("UnitName", true, false) as Label).text == "车", "unit panel did not update after selection")
	var drawer := hud.find_child("PieceInfoDrawer", true, false) as PieceInfoDrawer
	_expect(drawer.visible, "action brief did not open after selecting a piece")
	var drawer_state := drawer.get_state_snapshot()
	_expect(bool(drawer_state.get("buttons_horizontal", false)), "action buttons must remain horizontally aligned")
	_expect(int(drawer_state.get("visible_action_button_count", 0)) == 2, "action brief must expose move and skill roles")

	var minimap: Dictionary = snapshot.get("minimap", {})
	_expect(bool(minimap.get("uses_player_view_only", false)), "minimap accepted data broader than PlayerView")
	_expect(bool(minimap.get("interactive_navigation", false)), "minimap navigation is not interactive")
	_expect(int(minimap.get("piece_count", 0)) == 1, "minimap visible piece count changed")

	screen.queue_free()
	viewport.queue_free()
	await process_frame
	_finish()


func _player_view() -> Dictionary:
	return {
		"match_id": "hud-contract",
		"action_index": 1,
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
		"walls": [{"side": "red", "status": "INTACT"}, {"side": "black", "status": "BREACHED"}],
		"casualties": [
			{"side": "red", "piece_type": "soldier"},
			{"side": "red", "piece_type": "soldier"},
			{"side": "black", "piece_type": "cannon"},
		],
		"capture_ghosts": [],
		"vision_overlays": {"rook_paths": [], "elephant_reveal_zones": [], "elephant_block_fields": []},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("MATCH_HUD_V2_CONTRACT_PASS unified_theme=ok layout=responsive player_view=ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("MATCH_HUD_V2_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)
