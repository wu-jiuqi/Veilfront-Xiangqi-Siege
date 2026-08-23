extends SceneTree

const BOARD_VIEWPORT_SCENE: PackedScene = preload(
	"res://scenes/game/match/board/board_viewport.tscn"
)
const MATCH_HUD_SCENE: PackedScene = preload("res://scenes/game/ui/match_hud_v2.tscn")
const VIEWPORT_SIZE := Vector2i(600, 544)

var _failures: Array[String] = []


func _init() -> void:
	print("BOARD_CAMERA_LAYER_CONTRACT_STAGE init")
	call_deferred("_run")


func _run() -> void:
	print("BOARD_CAMERA_LAYER_CONTRACT_STAGE setup")
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	root.add_child(viewport)
	var board_viewport := BOARD_VIEWPORT_SCENE.instantiate() as SubViewportContainer
	# This contract validates camera state, coordinate mapping and layer order, not pixels.
	# Keeping the production 1152x3072 subviewport active under the headless renderer can
	# spend minutes rasterising the full fog/material stack before the next process frame.
	# Disable only this test instance's render target so lifecycle assertions remain exact
	# while the SceneTree continues to advance deterministically.
	var board_sub_viewport := board_viewport.get_node("BoardSubViewport") as SubViewport
	board_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	board_viewport.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(board_viewport)
	await process_frame
	print("BOARD_CAMERA_LAYER_CONTRACT_STAGE board_ready")
	board_viewport.render_player_view(_player_view("red", Vector2i(5, 1)))
	await process_frame
	print("BOARD_CAMERA_LAYER_CONTRACT_STAGE red_rendered")

	var snapshot: Dictionary = board_viewport.get_render_snapshot()
	_expect(
		is_equal_approx(
			float(snapshot.get("zoom_multiplier", 0.0)),
			float(snapshot.get("max_zoom_multiplier", -1.0))
		),
		"board did not open at maximum zoom"
	)
	_expect(
		int(snapshot.get("horizontal_grid_line_count", -1)) == 23,
		"board still draws the unwanted bottom grid line"
	)
	_expect_general_bottom_centered(board_viewport, Vector2i(5, 1), "red")
	board_viewport.clear_session_view()
	board_viewport.render_player_view(_player_view("black", Vector2i(5, 24)))
	await process_frame
	print("BOARD_CAMERA_LAYER_CONTRACT_STAGE black_rendered")
	_expect_general_bottom_centered(board_viewport, Vector2i(5, 24), "black")

	var board_world := board_viewport.get_node("BoardSubViewport/BoardWorld") as Node2D
	var piece_layer := board_world.get_node("PieceLayer") as CanvasItem
	for layer_path: String in [
		"MapBackground", "GridRenderer", "FogOverlay", "StructureLayer", "IntelLayer",
		"CaptureGhostLayer", "MarkerOverlay", "TacticalOverlay", "InteractionOverlay",
		"EffectLayer",
	]:
		var layer := board_world.get_node(layer_path) as CanvasItem
		_expect(piece_layer.z_index > layer.z_index, "piece layer is below %s" % layer_path)

	var input_surface := board_viewport.get_node("ScreenInputSurface") as Control
	_check_middle_drag(board_viewport, input_surface)

	var hud := MATCH_HUD_SCENE.instantiate() as Control
	root.add_child(hud)
	await process_frame
	print("BOARD_CAMERA_LAYER_CONTRACT_STAGE hud_ready")
	var board_border := hud.get_node_or_null("BoardFrame/BoardBorder") as NinePatchRect
	_expect(
		board_border == null or board_border.patch_margin_bottom == 0,
		"HUD board border still draws its bottom line above the map"
	)

	hud.queue_free()
	board_viewport.queue_free()
	viewport.queue_free()
	await process_frame
	print("BOARD_CAMERA_LAYER_CONTRACT_STAGE cleanup_complete")
	if _failures.is_empty():
		print("BOARD_CAMERA_LAYER_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("BOARD_CAMERA_LAYER_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_middle_drag(
	board_viewport: SubViewportContainer,
	input_surface: Control
) -> void:
	var has_middle_binding := false
	for event: InputEvent in InputMap.action_get_events(&"board_drag"):
		if event is InputEventMouseButton \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE:
			has_middle_binding = true
	_expect(has_middle_binding, "board_drag is not bound to the middle mouse button")
	var camera_before: Vector2 = board_viewport.get_render_snapshot().get(
		"camera_position", Vector2.ZERO
	)
	var press := InputEventMouseButton.new()
	press.device = InputEvent.DEVICE_ID_MOUSE
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = input_surface.size * 0.5
	input_surface.gui_input.emit(press)
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_MOUSE
	motion.position = press.position + Vector2(72.0, 0.0)
	motion.relative = Vector2(72.0, 0.0)
	input_surface.gui_input.emit(motion)
	var release := InputEventMouseButton.new()
	release.device = InputEvent.DEVICE_ID_MOUSE
	release.button_index = MOUSE_BUTTON_MIDDLE
	release.pressed = false
	release.position = motion.position
	input_surface.gui_input.emit(release)
	var camera_after: Vector2 = board_viewport.get_render_snapshot().get(
		"camera_position", Vector2.ZERO
	)
	_expect(camera_after.x < camera_before.x, "middle-button drag did not pan the board")
	_expect(
		not bool(board_viewport.get_render_snapshot().get("middle_drag_active", true)),
		"middle-button drag remained active after release"
	)


func _expect_general_bottom_centered(
	board_viewport: SubViewportContainer,
	general_cell: Vector2i,
	expected_side: String
) -> void:
	_expect(
		board_viewport.get_presentation_side() == expected_side,
		"board did not adopt the %s player's bottom perspective" % expected_side
	)
	var general_screen_position: Vector2 = \
		board_viewport.get_container_position_for_authority_cell(general_cell)
	var expected_general_position := Vector2(
		board_viewport.size.x * 0.5,
		board_viewport.size.y - board_viewport.get_point_spacing().y * 0.5
	)
	_expect(
		general_screen_position.distance_to(expected_general_position) <= 1.0,
		"%s general is not bottom-centered: %s" \
		% [expected_side, general_screen_position]
	)


func _player_view(side: String, general_cell: Vector2i) -> Dictionary:
	return {
		"viewer_side": side,
		"board": {"width": 9, "height": 24},
		"visible_cells": [
			[general_cell.x, general_cell.y],
			[maxi(general_cell.x - 1, 1), general_cell.y],
			[mini(general_cell.x + 1, 9), general_cell.y],
		],
		"hidden_detection_cells": [],
		"pieces": [{
			"alive": true,
			"id": "%s-camera-general" % side,
			"in_reserve": false,
			"piece_type": "general",
			"position": [general_cell.x, general_cell.y],
			"side": side,
			"status_tags": [],
		}],
		"flags": [],
		"walls": [],
		"capture_ghosts": [],
		"vision_overlays": {},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
