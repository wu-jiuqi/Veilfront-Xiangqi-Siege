extends SceneTree

const MATCH_SCREEN_SCENE: PackedScene = preload(
	"res://scenes/game/match/match_screen.tscn"
)
const FormalLocalSession = preload(
	"res://scripts/game/application/formal_local_session.gd"
)
const EXPECTED_MAP_PATH: String = \
	"res://assets/art/boards/terracotta_warriors/terracotta_battlefield_board_bg_gridless_v7_low_noise.png"
const EXPECTED_PIECE_SCENE_PATH: String = \
	"res://scenes/game/match/board/terracotta_piece_view.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var match_screen: Control = MATCH_SCREEN_SCENE.instantiate() as Control
	viewport.add_child(match_screen)
	match_screen.apply_layout_for_size(Vector2(viewport.size))

	var session: RefCounted = FormalLocalSession.create(471001)
	var port: RefCounted = session.create_client_port("red")
	_bind_match_screen(match_screen, port)
	port.publish_current()
	await process_frame
	await process_frame

	var board_viewport: SubViewportContainer = match_screen.get_node(
		"MatchHudV2/BoardFrame/BoardViewport"
	) as SubViewportContainer
	var board_border: NinePatchRect = match_screen.get_node(
		"MatchHudV2/BoardFrame/BoardBorder"
	) as NinePatchRect
	var input_surface: Control = board_viewport.get_node("ScreenInputSurface") as Control
	var board_world: Node2D = board_viewport.get_node("BoardSubViewport/BoardWorld") as Node2D
	var board_theme: BoardTheme = board_world.get("board_theme") as BoardTheme
	var snapshot: Dictionary = match_screen.get_board_render_snapshot()
	_check_fullscreen_layout(match_screen, viewport)
	await process_frame
	if "--capture-screenshot" in OS.get_cmdline_user_args():
		_capture_screenshot(viewport, "formal-fullscreen-2560x1080.png")
	await _check_minimap_expansion(match_screen, viewport)
	viewport.size = Vector2i(1280, 720)
	match_screen.apply_layout_for_size(Vector2(viewport.size))
	await process_frame

	_expect(
		board_border.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"formal board border blocks pointer input before it reaches the board surface"
	)
	_expect(
		input_surface.size.is_equal_approx(board_viewport.size),
		"formal board screen input surface does not cover the exported viewport"
	)
	_expect(
		str(snapshot.get("map_background_path", "")) == EXPECTED_MAP_PATH,
		"formal match did not bind the approved board artwork"
	)
	_expect(
		board_theme != null \
		and not board_theme.piece_scene_set.is_empty() \
		and board_theme.piece_scene_set[0].resource_path == EXPECTED_PIECE_SCENE_PATH,
		"formal board theme still points at a graybox or development piece scene"
	)
	var rendered_piece_count := int(snapshot.get("piece_count", 0))
	var rendered_art_paths: Array = snapshot.get("piece_art_paths", [])
	var layer_order: Dictionary = snapshot.get("layer_order", {})
	_expect(rendered_piece_count > 0, "formal match rendered no opening pieces")
	_expect(
		rendered_art_paths.size() == rendered_piece_count,
		"not every formal opening piece used an artwork texture"
	)
	_expect(
		int(layer_order.get("piece", -1)) > int(layer_order.get("fog", -1)),
		"formal pieces are drawn below the fog overlay"
	)
	if "--capture-screenshot" in OS.get_cmdline_user_args():
		_capture_screenshot(viewport)

	var preview: Dictionary = _first_legal_move(session.current_payload().get("action_previews", []))
	_expect(not preview.is_empty(), "formal local match exposed no legal opening move")
	if not preview.is_empty():
		var piece_id := str(preview.get("piece_id", ""))
		var source_cell := _piece_cell(match_screen.get_player_view_snapshot(), piece_id)
		var target_cell := BoardCoordinateMapper.coordinate_from_variant(
			preview.get("target_cell", [])
		)
		_click_visible_piece_body(viewport, input_surface, board_viewport, source_cell)
		await process_frame
		_expect(
			str(match_screen.get_presentation_snapshot().get("selected_piece_id", "")) == piece_id,
			"pointer click on a formal piece did not select it"
		)
		_expect(
			not bool(match_screen.get_board_render_snapshot().get(
				"piece_visual_hit_enabled", true
			)),
			"selected state did not restore grid-point priority for target clicks"
		)
		_click_board_cell(viewport, input_surface, board_viewport, target_cell)
		await process_frame
		_expect(
			match_screen.get_local_interaction_state() == "CONFIRMING",
			"pointer click on a legal target did not open confirmation"
		)
		var confirm_button: Button = match_screen.get_node(
			"ActionConfirmationPanel/Content/Buttons/ConfirmButton"
		) as Button
		confirm_button.pressed.emit()
		await process_frame
		await process_frame
		_expect(
			int(match_screen.get_player_view_snapshot().get("action_index", -1)) == 1,
			"confirmed pointer move did not advance the formal action index"
		)
		_expect(
			_piece_cell(match_screen.get_player_view_snapshot(), piece_id) == target_cell,
			"confirmed pointer move did not update the piece position"
		)
		_expect(
			bool(match_screen.get_board_render_snapshot().get(
				"piece_visual_hit_enabled", false
			)),
			"completed move did not restore visual-piece hit testing"
		)

	match_screen.queue_free()
	viewport.queue_free()
	await process_frame
	if _failures.is_empty():
		print("FORMAL_BOARD_ART_INPUT_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FORMAL_BOARD_ART_INPUT_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _bind_match_screen(match_screen: Control, port: RefCounted) -> void:
	port.player_view_updated.connect(match_screen.render_player_view)
	port.visible_events_received.connect(match_screen.render_visible_events)
	port.visible_error_received.connect(match_screen.render_visible_error)
	port.action_previews_updated.connect(match_screen.render_action_previews_from_port)
	port.prepared_action_changed.connect(match_screen.render_prepared_action)
	match_screen.action_previews_requested.connect(port.request_action_previews)
	match_screen.action_prepare_requested.connect(port.prepare_action)
	match_screen.action_confirm_requested.connect(port.confirm_prepared_action)
	match_screen.prepared_action_cancel_requested.connect(port.cancel_prepared_action)


func _click_board_cell(
	viewport: SubViewport,
	input_surface: Control,
	board_viewport: SubViewportContainer,
	cell: Vector2i
) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = input_surface.global_position \
		+ board_viewport.get_container_position_for_authority_cell(cell)
	event.global_position = event.position
	viewport.push_input(event, true)


func _click_visible_piece_body(
	viewport: SubViewport,
	input_surface: Control,
	board_viewport: SubViewportContainer,
	cell: Vector2i
) -> void:
	var visual_body_position: Vector2 = \
		board_viewport.get_container_position_for_authority_cell(cell)
	# 棋盘棋子已收进以交点为中心的单格安全框；保持偏离交点点击，验证视觉主体
	# 命中优先级，同时避免沿用旧站立立绘位于交点上方半格以上的过期坐标。
	visual_body_position.y -= board_viewport.get_point_spacing().y * 0.25
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = input_surface.global_position + visual_body_position
	event.global_position = event.position
	viewport.push_input(event, true)


func _check_fullscreen_layout(match_screen: Control, viewport: SubViewport) -> void:
	viewport.size = Vector2i(2560, 1080)
	match_screen.apply_layout_for_size(Vector2(viewport.size))
	var layout: Dictionary = match_screen.get_hud_snapshot().get("layout", {})
	var board_rect: Rect2 = layout.get("board_rect", Rect2())
	var expected_board_aspect := 998.0 / 450.0
	var actual_board_aspect := board_rect.size.x / maxf(board_rect.size.y, 1.0)
	_expect(
		absf(actual_board_aspect - expected_board_aspect) <= 0.001,
		"fullscreen layout stretched the formal board away from its authored aspect"
	)
	var content_rect: Rect2 = layout.get("content_rect", Rect2())
	_expect(
		content_rect.size.x > 0.0 and content_rect.size.y > 0.0,
		"fullscreen layout does not expose a centered aspect-preserving content rectangle"
	)


func _check_minimap_expansion(match_screen: Control, viewport: SubViewport) -> void:
	var button := match_screen.get_node_or_null("MatchHudV2/Minimap/MinimapExpandButton") as Button
	_expect(button != null, "formal minimap has no preset expand control")
	if button == null:
		return
	var before: Rect2 = match_screen.get_hud_snapshot().get("layout", {}).get(
		"ui_rects", {}
	).get("minimap", Rect2())
	_click_control(viewport, button)
	await process_frame
	var expanded_layout: Dictionary = match_screen.get_hud_snapshot().get("layout", {})
	var after: Rect2 = expanded_layout.get("ui_rects", {}).get("minimap", Rect2())
	_expect(bool(expanded_layout.get("minimap_expanded", false)), "minimap expand control did not enter expanded mode")
	_expect(after.size.x > before.size.x and after.size.y > before.size.y, "minimap expand control did not enlarge the map")
	if "--capture-screenshot" in OS.get_cmdline_user_args():
		_capture_screenshot(viewport, "formal-minimap-expanded.png")
	_click_control(viewport, button)
	await process_frame
	var restored_layout: Dictionary = match_screen.get_hud_snapshot().get("layout", {})
	_expect(not bool(restored_layout.get("minimap_expanded", true)), "minimap expand control did not restore compact mode")


func _click_control(viewport: SubViewport, control: Control) -> void:
	var pointer_position := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = pointer_position
		event.global_position = pointer_position
		viewport.push_input(event, true)


func _first_legal_move(previews: Array) -> Dictionary:
	for preview_value: Variant in previews:
		if preview_value is Dictionary \
		and str(preview_value.get("action_type", "")) == "move" \
		and str(preview_value.get("classification", "")) == "KNOWN_LEGAL":
			return preview_value.duplicate(true)
	return {}


func _piece_cell(view: Dictionary, piece_id: String) -> Vector2i:
	for piece_value: Variant in view.get("pieces", []):
		if piece_value is Dictionary and str(piece_value.get("id", "")) == piece_id:
			return BoardCoordinateMapper.coordinate_from_variant(
				piece_value.get("position", [])
			)
	return Vector2i.ZERO


func _capture_screenshot(
	viewport: SubViewport,
	file_name: String = "formal-board-art-input.png"
) -> void:
	var image := viewport.get_texture().get_image()
	if image == null:
		_failures.append("formal board screenshot was unavailable")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.codex-temp"))
	var output_path := ProjectSettings.globalize_path("res://.codex-temp/%s" % file_name)
	_expect(image.save_png(output_path) == OK, "failed to save the formal board screenshot")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
