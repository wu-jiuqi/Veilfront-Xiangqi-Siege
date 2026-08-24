extends Node2D

signal point_activated(cell: Vector2i)
signal point_double_activated(cell: Vector2i)
signal cancel_or_marker_requested(cell: Vector2i)
signal zoom_requested(step: float)
signal pan_requested(amount: float)
signal point_hovered(cell: Vector2i)
signal point_hover_ended()

@export var board_theme: BoardTheme
@export var map_option: BoardMapOption

@onready var _map_background: Sprite2D = $MapBackground
@onready var _grid_renderer: Node2D = $GridRenderer
@onready var _piece_renderer: Node2D = $PieceLayer
@onready var _fog_overlay: Control = $FogOverlay
@onready var _wall_renderer: Node2D = $StructureLayer/WallViews
@onready var _intel_layer: Node2D = $IntelLayer
@onready var _flag_renderer: Node2D = $IntelLayer/FlagViews
@onready var _ghost_renderer: Node2D = $CaptureGhostLayer
@onready var _marker_overlay: Control = $MarkerOverlay
@onready var _tactical_overlay: Control = $TacticalOverlay
@onready var _interaction_overlay: Control = $InteractionOverlay
@onready var _input_surface: Control = $InputSurface

var _side: String = "red"
var _viewer_side: String = "red"
var _current_view: Dictionary = {}


func _ready() -> void:
	_input_surface.point_activated.connect(_on_point_activated)
	_input_surface.point_double_activated.connect(_on_point_double_activated)
	_input_surface.cancel_or_marker_requested.connect(_on_cancel_or_marker_requested)
	_input_surface.zoom_requested.connect(_on_zoom_requested)
	_input_surface.pan_requested.connect(_on_pan_requested)
	_input_surface.point_hovered.connect(func(cell: Vector2i) -> void: point_hovered.emit(cell))
	_input_surface.point_hover_ended.connect(func() -> void: point_hover_ended.emit())
	_apply_presentation_assets()
	_configure_empty_board()


func set_presentation_assets(theme: BoardTheme, selected_map: BoardMapOption) -> void:
	if theme != null:
		board_theme = theme
	if selected_map != null:
		map_option = selected_map
	_apply_presentation_assets()
	if _current_view.is_empty():
		_configure_empty_board()
	else:
		render_player_view(_current_view)


func render_player_view(view: Dictionary, fog_mask_texture: ImageTexture = null) -> void:
	_current_view = view.duplicate(true)
	_viewer_side = str(_current_view.get("viewer_side", "red"))
	if _side not in ["red", "black"]:
		_side = _viewer_side
	var cell_size: Vector2 = board_theme.cell_size
	_grid_renderer.configure(_current_view.get("board", {"width": 9, "height": 24}), _side, board_theme)
	_piece_renderer.render(_current_view.get("pieces", []), _side, cell_size)
	_fog_overlay.render(
		_current_view.get("visible_cells", []),
		_current_view.get("hidden_detection_cells", []),
		_side,
		cell_size,
		fog_mask_texture
	)
	_wall_renderer.render(_current_view.get("walls", []), _side, cell_size)
	_flag_renderer.render(_current_view.get("flags", []), _side, cell_size)
	_ghost_renderer.render(_current_view.get("capture_ghosts", []), _side, cell_size)
	_marker_overlay.configure(_side, cell_size, board_theme.marker_assets)
	_tactical_overlay.render_public_overlays(
		_current_view.get("vision_overlays", {}), _side, cell_size
	)
	_interaction_overlay.render_selection(Vector2i.ZERO, [], _side, cell_size)
	_input_surface.configure(_side, cell_size)


func set_marker(cell: Vector2i, marker_type: String) -> void:
	_marker_overlay.set_marker(cell, marker_type)


func clear_marker(cell: Vector2i) -> void:
	_marker_overlay.clear_marker(cell)


func has_marker(cell: Vector2i) -> bool:
	return _marker_overlay.has_marker(cell)


func set_interaction(selected_cell: Vector2i, action_previews: Array) -> void:
	_piece_renderer.set_selected_cell(selected_cell)
	_interaction_overlay.render_selection(
		selected_cell, action_previews, _side, board_theme.cell_size
	)


func clear_interaction() -> void:
	_piece_renderer.set_selected_cell(Vector2i.ZERO)
	_interaction_overlay.clear()


func set_selected_point(cell: Vector2i) -> void:
	_interaction_overlay.set_selected_point(cell)


func clear_session_view() -> void:
	_current_view.clear()
	_viewer_side = "red"
	_piece_renderer.clear_immediately()
	_configure_empty_board()


func set_tutorial_target(cell: Vector2i) -> void:
	_interaction_overlay.set_tutorial_target(cell)


func get_render_snapshot() -> Dictionary:
	var flag_cell: Vector2i = _flag_renderer.get_first_flag_cell()
	return {
		"piece_count": _piece_renderer.get_rendered_count(),
		"piece_glyphs": _piece_renderer.get_rendered_glyphs(),
		"piece_cells": _piece_renderer.get_rendered_cells(),
		"piece_art_paths": _piece_renderer.get_rendered_art_paths(),
		"piece_animation_events": _piece_renderer.get_last_animation_events(),
		"selected_piece_count": _piece_renderer.get_selected_piece_count(),
		"map_id": str(map_option.map_id) if map_option != null else "",
		"map_background_path": _map_background.texture.resource_path \
			if _map_background.texture != null else "",
		"flag_count": _flag_renderer.get_rendered_count(),
		"ghost_count": _ghost_renderer.get_rendered_count(),
		"wall_segment_count": _wall_renderer.get_rendered_count(),
		"marker_count": _marker_overlay.get_marker_count(),
		"marker_asset_count": _marker_overlay.get_marker_asset_count(),
		"tactical_group_count": _tactical_overlay.get_group_count(),
		"interaction_preview_count": _interaction_overlay.get_preview_count(),
		"selected_point": _interaction_overlay.get_selected_point(),
		"tutorial_target": _interaction_overlay.get_tutorial_target(),
		"horizontal_grid_line_count": _grid_renderer.get_horizontal_line_count(),
		"flag_cell_fogged": _fog_overlay.is_cell_fogged(flag_cell) \
			if flag_cell != Vector2i.ZERO else false,
		"flag_memory_visible": _flag_renderer.get_rendered_count() > 0,
		"layer_order": {
			"fog": _fog_overlay.get_index(),
			"piece": _piece_renderer.get_index(),
			"intel": _intel_layer.get_index(),
			"marker": _marker_overlay.get_index(),
			"tactical": _tactical_overlay.get_index(),
			"interaction": _interaction_overlay.get_index(),
		},
	}


func get_point_spacing() -> Vector2:
	return _grid_renderer.get_point_spacing()


func get_viewer_side() -> String:
	return _viewer_side


func get_display_side() -> String:
	return _side


func set_presentation_side(side: String) -> void:
	if side not in ["red", "black"] or side == _side:
		return
	_side = side
	if _current_view.is_empty():
		_configure_empty_board()
		return
	render_player_view(_current_view)


func get_cell_size() -> Vector2:
	return board_theme.cell_size


func get_fog_mask_texture() -> ImageTexture:
	return _fog_overlay.get_mask_texture() as ImageTexture


func find_piece_cell_at_world_position(world_position: Vector2) -> Vector2i:
	if _piece_renderer.has_method("find_piece_cell_at_world_position"):
		return _piece_renderer.call("find_piece_cell_at_world_position", world_position) \
			as Vector2i
	return Vector2i.ZERO


func _configure_empty_board() -> void:
	if board_theme == null:
		return
	var cell_size: Vector2 = board_theme.cell_size
	_grid_renderer.configure({"width": 9, "height": 24}, _side, board_theme)
	_piece_renderer.render([], _side, cell_size)
	_piece_renderer.set_selected_cell(Vector2i.ZERO)
	_fog_overlay.render([], [], _side, cell_size)
	_wall_renderer.render([], _side, cell_size)
	_flag_renderer.render([], _side, cell_size)
	_ghost_renderer.render([], _side, cell_size)
	_marker_overlay.configure(_side, cell_size, board_theme.marker_assets)
	_marker_overlay.clear_all()
	_tactical_overlay.render_public_overlays({}, _side, cell_size)
	_interaction_overlay.render_selection(Vector2i.ZERO, [], _side, cell_size)
	_input_surface.configure(_side, cell_size)


func _apply_presentation_assets() -> void:
	if board_theme != null and not board_theme.piece_scene_set.is_empty():
		var selected_piece_scene: PackedScene = board_theme.piece_scene_set[0]
		if _piece_renderer.get("piece_scene") != selected_piece_scene:
			_piece_renderer.clear_immediately()
		_piece_renderer.set("piece_scene", selected_piece_scene)
	_configure_map_background()


func _configure_map_background() -> void:
	if map_option == null or map_option.background_texture == null or board_theme == null:
		_map_background.visible = false
		_map_background.texture = null
		return
	var texture_size: Vector2 = map_option.background_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		_map_background.visible = false
		_map_background.texture = null
		return
	var board_size := Vector2(9.0 * board_theme.cell_size.x, 24.0 * board_theme.cell_size.y)
	var cover_scale: float = maxf(
		board_size.x / texture_size.x,
		board_size.y / texture_size.y
	)
	_map_background.texture = map_option.background_texture
	_map_background.position = board_size * 0.5
	_map_background.scale = Vector2.ONE * cover_scale
	_map_background.visible = true


func _on_point_activated(cell: Vector2i) -> void:
	point_activated.emit(cell)


func _on_point_double_activated(cell: Vector2i) -> void:
	point_double_activated.emit(cell)


func _on_cancel_or_marker_requested(cell: Vector2i) -> void:
	cancel_or_marker_requested.emit(cell)


func _on_zoom_requested(step: float) -> void:
	zoom_requested.emit(step)


func _on_pan_requested(amount: float) -> void:
	pan_requested.emit(amount)
