class_name TacticalMinimap
extends Control

signal overview_navigation_requested(display_ratio: Vector2)

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")
const BOARD_SIZE := Vector2i(9, 24)
const BOARD_WORLD_SIZE := Vector2(1152.0, 3072.0)
const VIEWPORT_BORDER_COLOR := Color(0.76, 0.78, 0.8, 0.96)
const VIEWPORT_AREA_COLOR := Color(0.42, 0.44, 0.46, 0.48)

@onready var _bird_eye_viewport: SubViewport = $BirdEyeViewportContainer/BirdEyeViewport
@onready var _bird_eye_world: Node2D = $BirdEyeViewportContainer/BirdEyeViewport/BoardWorld
@onready var _bird_eye_camera: Camera2D = \
	$BirdEyeViewportContainer/BirdEyeViewport/BoardWorld/BoardCamera2D

var _view: Dictionary = {}
var _display_side: String = "red"
var _overview_state: Dictionary = {
	"display_side": "red",
	"viewport_rect_normalized": Rect2(0.0, 0.0, 1.0, 1.0),
	"camera_center_normalized": Vector2(0.5, 0.5),
}
var _navigation_dragging: bool = false


func _ready() -> void:
	resized.connect(_sync_bird_eye_layout)
	var input_surface := _bird_eye_world.get_node_or_null("InputSurface") as Control
	if input_surface != null:
		input_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bird_eye_camera.position_smoothing_enabled = false
	_bird_eye_camera.position = BOARD_WORLD_SIZE * 0.5
	_sync_bird_eye_layout()
	queue_redraw()


func render_player_view(
	view: Dictionary,
	display_side: String = "red",
	fog_mask_texture: ImageTexture = null
) -> void:
	_view = view.duplicate(true)
	_display_side = display_side if display_side in ["red", "black"] else "red"
	_bird_eye_world.set_presentation_side(_display_side)
	_bird_eye_world.render_player_view(_view, fog_mask_texture)
	_sync_bird_eye_layout()
	queue_redraw()


func clear_session_view() -> void:
	_view.clear()
	_display_side = "red"
	_overview_state = {
		"display_side": "red",
		"viewport_rect_normalized": Rect2(0.0, 0.0, 1.0, 1.0),
		"camera_center_normalized": Vector2(0.5, 0.5),
	}
	_bird_eye_world.clear_session_view()
	_sync_bird_eye_layout()
	queue_redraw()


func set_presentation_side(side: String) -> void:
	_display_side = side if side in ["red", "black"] else "red"
	_bird_eye_world.set_presentation_side(_display_side)
	_sync_bird_eye_layout()
	queue_redraw()


func set_overview_state(state: Dictionary) -> void:
	_overview_state = state.duplicate(true)
	var side := str(_overview_state.get("display_side", _display_side))
	if side in ["red", "black"] and side != _display_side:
		set_presentation_side(side)
	queue_redraw()


func get_state_snapshot() -> Dictionary:
	var visible_count := 0
	for cell_value: Variant in _view.get("visible_cells", []):
		if Mapper.is_authority_cell_valid(Mapper.coordinate_from_variant(cell_value)):
			visible_count += 1
	var piece_count := 0
	for piece_value: Variant in _view.get("pieces", []):
		if piece_value is Dictionary and _piece_is_drawable(piece_value):
			piece_count += 1
	var flag_count := 0
	for flag_value: Variant in _view.get("flags", []):
		if flag_value is Dictionary and _flag_is_drawable(flag_value):
			flag_count += 1
	var ghost_count := 0
	for ghost_value: Variant in _view.get("capture_ghosts", []):
		if ghost_value is Dictionary \
		and Mapper.is_authority_cell_valid(Mapper.coordinate_from_variant(
			ghost_value.get("position", [])
		)):
			ghost_count += 1
	var wall_segment_count := 0
	for wall_value: Variant in _view.get("walls", []):
		if wall_value is Dictionary and str(wall_value.get("side", "")) in ["red", "black"]:
			wall_segment_count += BOARD_SIZE.x
	return {
		"display_side": _display_side,
		"visible_cell_count": visible_count,
		"piece_count": piece_count,
		"flag_count": flag_count,
		"ghost_count": ghost_count,
		"wall_segment_count": wall_segment_count,
		"region_band_count": 5,
		"uses_player_view_only": true,
		"bird_eye_mode": true,
		"uses_board_world_renderer": true,
		"interactive_navigation": true,
		"viewport_indicator_style": "gray_viewport_area",
		"viewport_rect_normalized": _overview_state.get(
			"viewport_rect_normalized", Rect2(0.0, 0.0, 1.0, 1.0)
		),
		"camera_center_normalized": _overview_state.get(
			"camera_center_normalized", Vector2(0.5, 0.5)
		),
	}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			if not _board_rect().has_point(mouse_event.position):
				return
			_navigation_dragging = true
			_request_navigation(mouse_event.position)
		else:
			_navigation_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _navigation_dragging:
		_request_navigation((event as InputEventMouseMotion).position)
		accept_event()


func _draw() -> void:
	var board_rect := _board_rect()
	_draw_camera_viewport(board_rect)
	draw_rect(board_rect, Color(0.54, 0.43, 0.24, 0.9), false, 1.5)


func _sync_bird_eye_layout() -> void:
	if not is_node_ready():
		return
	var viewport_size := Vector2i(
		maxi(1, _bird_eye_viewport.size.x), maxi(1, _bird_eye_viewport.size.y)
	)
	var zoom_value := minf(
		float(viewport_size.x) / BOARD_WORLD_SIZE.x,
		float(viewport_size.y) / BOARD_WORLD_SIZE.y
	)
	_bird_eye_camera.zoom = Vector2(zoom_value, zoom_value)
	_bird_eye_camera.position = BOARD_WORLD_SIZE * 0.5
	queue_redraw()


func _draw_camera_viewport(board_rect: Rect2) -> void:
	var normalized: Rect2 = _overview_state.get(
		"viewport_rect_normalized", Rect2(0.0, 0.0, 1.0, 1.0)
	)
	var viewport_rect := Rect2(
		board_rect.position + normalized.position * board_rect.size,
		normalized.size * board_rect.size
	).intersection(board_rect)
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return
	draw_rect(viewport_rect, VIEWPORT_AREA_COLOR, true)
	draw_rect(viewport_rect.grow(-0.75), VIEWPORT_BORDER_COLOR, false, 1.5)


func _request_navigation(local_position: Vector2) -> void:
	var board_rect := _board_rect()
	var clamped := Vector2(
		clampf(local_position.x, board_rect.position.x, board_rect.end.x),
		clampf(local_position.y, board_rect.position.y, board_rect.end.y)
	)
	var ratio := (clamped - board_rect.position) / board_rect.size
	overview_navigation_requested.emit(Vector2(
		clampf(ratio.x, 0.0, 1.0), clampf(ratio.y, 0.0, 1.0)
	))


func _board_rect() -> Rect2:
	var cell_scale := minf(size.x / BOARD_SIZE.x, size.y / BOARD_SIZE.y)
	var board_size := Vector2(BOARD_SIZE) * cell_scale
	return Rect2((size - board_size) * 0.5, board_size)


func _piece_is_drawable(piece: Dictionary) -> bool:
	return bool(piece.get("alive", false)) \
		and not bool(piece.get("in_reserve", false)) \
		and Mapper.is_authority_cell_valid(Mapper.coordinate_from_variant(
			piece.get("position", [])
		))


func _flag_is_drawable(flag: Dictionary) -> bool:
	return bool(flag.get("discovered", false)) \
		and Mapper.is_authority_cell_valid(Mapper.coordinate_from_variant(
			flag.get("position", [])
		))
