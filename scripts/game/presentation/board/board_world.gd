extends Node2D

signal point_activated(cell: Vector2i)
signal cancel_or_marker_requested(cell: Vector2i)
signal zoom_requested(step: float)
signal pan_requested(amount: float)
signal point_hovered(cell: Vector2i)
signal point_hover_ended()

@export var board_theme: BoardTheme

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
	_input_surface.cancel_or_marker_requested.connect(_on_cancel_or_marker_requested)
	_input_surface.zoom_requested.connect(_on_zoom_requested)
	_input_surface.pan_requested.connect(_on_pan_requested)
	_input_surface.point_hovered.connect(func(cell: Vector2i) -> void: point_hovered.emit(cell))
	_input_surface.point_hover_ended.connect(func() -> void: point_hover_ended.emit())
	_configure_empty_board()


func render_player_view(view: Dictionary) -> void:
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
		cell_size
	)
	_wall_renderer.render(_current_view.get("walls", []), _side, cell_size)
	_flag_renderer.render(_current_view.get("flags", []), _side, cell_size)
	_ghost_renderer.render(_current_view.get("capture_ghosts", []), _side, cell_size)
	_marker_overlay.configure(_side, cell_size)
	_tactical_overlay.render_public_overlays(
		_current_view.get("vision_overlays", {}), _side, cell_size
	)
	_interaction_overlay.render_selection(Vector2i.ZERO, [], _side, cell_size)
	_input_surface.configure(_side, cell_size)


func set_marker(cell: Vector2i, marker_type: String) -> void:
	_marker_overlay.set_marker(cell, marker_type)


func set_interaction(selected_cell: Vector2i, action_previews: Array) -> void:
	_interaction_overlay.render_selection(
		selected_cell, action_previews, _side, board_theme.cell_size
	)


func clear_interaction() -> void:
	_interaction_overlay.clear()


func set_tutorial_target(cell: Vector2i) -> void:
	_interaction_overlay.set_tutorial_target(cell)


func get_render_snapshot() -> Dictionary:
	var flag_cell: Vector2i = _flag_renderer.get_first_flag_cell()
	return {
		"piece_count": _piece_renderer.get_rendered_count(),
		"piece_glyphs": _piece_renderer.get_rendered_glyphs(),
		"piece_cells": _piece_renderer.get_rendered_cells(),
		"flag_count": _flag_renderer.get_rendered_count(),
		"ghost_count": _ghost_renderer.get_rendered_count(),
		"wall_segment_count": _wall_renderer.get_rendered_count(),
		"marker_count": _marker_overlay.get_marker_count(),
		"tactical_group_count": _tactical_overlay.get_group_count(),
		"interaction_preview_count": _interaction_overlay.get_preview_count(),
		"tutorial_target": _interaction_overlay.get_tutorial_target(),
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


func _configure_empty_board() -> void:
	if board_theme == null:
		return
	_grid_renderer.configure({"width": 9, "height": 24}, _side, board_theme)
	_fog_overlay.render([], [], _side, board_theme.cell_size)
	_marker_overlay.configure(_side, board_theme.cell_size)
	_tactical_overlay.render_public_overlays({}, _side, board_theme.cell_size)
	_interaction_overlay.render_selection(Vector2i.ZERO, [], _side, board_theme.cell_size)
	_input_surface.configure(_side, board_theme.cell_size)


func _on_point_activated(cell: Vector2i) -> void:
	point_activated.emit(cell)


func _on_cancel_or_marker_requested(cell: Vector2i) -> void:
	cancel_or_marker_requested.emit(cell)


func _on_zoom_requested(step: float) -> void:
	zoom_requested.emit(step)


func _on_pan_requested(amount: float) -> void:
	pan_requested.emit(amount)
