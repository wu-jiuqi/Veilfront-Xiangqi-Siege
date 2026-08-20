extends SceneTree

const CALIBRATOR_SCENE: PackedScene = preload(
	"res://scenes/dev/ui/board_ui_layout_calibrator.tscn"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var calibrator := CALIBRATOR_SCENE.instantiate() as BoardUiLayoutCalibrator
	viewport.add_child(calibrator)
	await process_frame
	await process_frame

	var initial := calibrator.get_calibration_snapshot()
	_expect(initial.get("meaning", "") == "default_visible_board_screen_rect", "tool meaning must describe the default visible board rect")
	_expect(initial.get("explicitly_not", "") == "full_board_world_size", "tool must explicitly reject full board world sizing")
	_expect(initial.get("design_canvas_size", []) == [1280, 720], "default design canvas must be 1280x720")
	_expect(initial.get("full_board_world_size_reference", []) == [1152, 3072], "formal board world reference changed")
	_expect(int(initial.get("hud_component_count", 0)) == 7, "all seven layout HUD components must be visible in the preview")
	_expect(int(initial.get("resize_handle_count", 0)) == 8, "board rect must expose eight resize handles")
	_expect(bool(initial.get("safe_area_visible", false)), "safe-area guide should be visible by default")
	_expect(_rect_is_inside(initial), "initial board rect must stay inside the design canvas")

	calibrator.set_calibration_rect(Rect2(304.0, 120.0, 640.0, 400.0))
	await process_frame
	var edited := calibrator.get_calibration_snapshot()
	var edited_rect: Dictionary = edited.get("default_visible_board_rect_px", {})
	_expect(int(edited_rect.get("x", -1)) == 304, "programmatic X edit did not apply")
	_expect(int(edited_rect.get("y", -1)) == 120, "programmatic Y edit did not apply")
	_expect(int(edited_rect.get("width", -1)) == 640, "programmatic width edit did not apply")
	_expect(int(edited_rect.get("height", -1)) == 400, "programmatic height edit did not apply")

	var before_wide: Dictionary = edited.get("default_visible_board_rect_normalized", {})
	calibrator.set_preview_profile(1)
	await process_frame
	await process_frame
	var wide := calibrator.get_calibration_snapshot()
	var after_wide: Dictionary = wide.get("default_visible_board_rect_normalized", {})
	_expect(wide.get("design_canvas_size", []) == [1680, 720], "wide profile must use the 1680x720 logical canvas")
	_expect(
		absf(float(before_wide.get("left", 0.0)) - float(after_wide.get("left", 1.0))) <= 0.01,
		"profile switch must preserve normalized left position"
	)
	_expect(
		absf(float(before_wide.get("width", 0.0)) - float(after_wide.get("width", 1.0))) <= 0.01,
		"profile switch must preserve normalized width"
	)
	_expect(_rect_is_inside(wide), "wide-profile board rect must stay inside the design canvas")

	viewport.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BOARD_UI_LAYOUT_CALIBRATOR_CONTRACT_PASS hud=7 handles=8 profiles=4")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("BOARD_UI_LAYOUT_CALIBRATOR_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _rect_is_inside(snapshot: Dictionary) -> bool:
	var canvas: Array = snapshot.get("design_canvas_size", [])
	var rect: Dictionary = snapshot.get("default_visible_board_rect_px", {})
	if canvas.size() != 2 or rect.is_empty():
		return false
	var x := float(rect.get("x", -1.0))
	var y := float(rect.get("y", -1.0))
	var width := float(rect.get("width", -1.0))
	var height := float(rect.get("height", -1.0))
	return x >= 0.0 and y >= 0.0 and width > 0.0 and height > 0.0 \
		and x + width <= float(canvas[0]) and y + height <= float(canvas[1])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
