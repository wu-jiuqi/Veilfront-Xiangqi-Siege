extends SceneTree

const LAB_SCENE := preload("res://scenes/dev/ui/match_hud_v2_interaction_lab.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lab := LAB_SCENE.instantiate() as Control
	viewport.add_child(lab)
	await process_frame
	await process_frame

	var screen := lab.get_node("MatchScreen") as Control
	var hud := screen.get_node("MatchHudV2") as Control
	var snapshot: Dictionary = hud.get_layout_snapshot()
	_expect(str(snapshot.get("active_profile", "")) == "scene-authored-responsive", "interaction lab must use the container-authored profile")
	_expect(hud.theme.resource_path == "res://resources/game/ui/themes/veilfront_ui_theme_v2.tres", "interaction lab HUD uses the wrong theme")
	var board := hud.find_child("BoardFrame", true, false) as Control
	var action := hud.find_child("ActionPanel", true, false) as Control
	var left := hud.get_node("SafeMargin/MainRows/BodyBand/LeftRail") as Control
	var right := hud.get_node("SafeMargin/MainRows/BodyBand/RightRail") as Control
	_expect(board.size.x >= 500.0 and board.size.y >= 360.0, "interaction lab board is too small")
	_expect(board.get_global_rect().end.y <= action.get_global_rect().position.y + 0.5, "action brief overlaps the board")
	_expect(left.get_global_rect().end.x <= board.get_global_rect().position.x + 0.5, "left rail overlaps the board")
	_expect(board.get_global_rect().end.x <= right.get_global_rect().position.x + 0.5, "right rail overlaps the board")

	lab.queue_free()
	viewport.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("MATCH_HUD_V2_LAB_SCENE_LAYOUT_CONTRACT_PASS layout=responsive")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("MATCH_HUD_V2_LAB_SCENE_LAYOUT_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)
