extends Control

signal prepared_action_cancel_requested()
signal marker_menu_requested(cell: Vector2i)

const COMPACT_BREAKPOINT: float = 1100.0
const IDLE: String = "IDLE"
const SELECTED: String = "SELECTED"
const PREVIEW_SELECTED: String = "PREVIEW_SELECTED"
const CONFIRMING: String = "CONFIRMING"
const MARKER_MENU: String = "MARKER_MENU"

@onready var _workspace: HSplitContainer = %Workspace
@onready var _board_frame: PanelContainer = %BoardFrame
@onready var _board_viewport: SubViewportContainer = %BoardViewport
@onready var _wide_status_host: PanelContainer = %WideStatusHost
@onready var _status_panel: PanelContainer = %MatchStatusPanel
@onready var _compact_status_drawer: PopupPanel = %CompactStatusDrawer
@onready var _compact_status_host: MarginContainer = %CompactStatusHost
@onready var _compact_placeholder: Label = %CompactStatusPlaceholder
@onready var _marker_menu: PopupPanel = %MarkerMenu
@onready var _confirmation_panel: PanelContainer = %ActionConfirmationPanel
@onready var _status_button: Button = %StatusButton
@onready var _cancel_button: Button = %CancelButton
@onready var _confirm_button: Button = %ConfirmButton

var _compact: bool = false
var _interaction_state: String = IDLE
var _selected_piece_id: String = ""
var _prepared_preview_id: String = ""


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_board_viewport.cancel_or_marker_requested.connect(_on_cancel_or_marker_requested)
	_marker_menu.marker_selected.connect(_on_marker_selected)
	_status_button.pressed.connect(_on_status_button_pressed)
	_cancel_button.pressed.connect(_cancel_only)
	call_deferred("apply_layout_for_size", size)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _compact_status_drawer.visible:
		_compact_status_drawer.hide()
	elif _marker_menu.visible:
		_marker_menu.hide()
		_interaction_state = IDLE
	else:
		_cancel_only()
	get_viewport().set_input_as_handled()


func apply_layout_for_size(requested_size: Vector2) -> void:
	_set_compact_layout(requested_size.x < COMPACT_BREAKPOINT)


func render_player_view(view: Dictionary) -> void:
	_board_viewport.render_player_view(view)


func render_action_previews(selected_cell: Vector2i, previews: Array) -> void:
	_board_viewport.set_interaction(selected_cell, previews)


func set_local_interaction_state(
	state: String,
	selected_piece_id: String,
	prepared_preview_id: String
) -> void:
	if state not in [IDLE, SELECTED, PREVIEW_SELECTED, CONFIRMING, MARKER_MENU]:
		return
	_interaction_state = state
	_selected_piece_id = selected_piece_id
	_prepared_preview_id = prepared_preview_id
	_confirmation_panel.visible = state == CONFIRMING


func get_local_interaction_state() -> String:
	return _interaction_state


func handle_cancel_or_marker(cell: Vector2i) -> String:
	if _interaction_state == CONFIRMING:
		_clear_local_interaction()
		prepared_action_cancel_requested.emit()
		return "cancel_prepared_action"
	if _interaction_state in [SELECTED, PREVIEW_SELECTED]:
		_clear_local_interaction()
		return "cancel_selection"
	if _interaction_state == MARKER_MENU:
		_marker_menu.hide()
		_interaction_state = IDLE
		return "close_marker_menu"
	_marker_menu.open_for_cell(cell)
	_interaction_state = MARKER_MENU
	marker_menu_requested.emit(cell)
	return "open_marker_menu"


func apply_marker(cell: Vector2i, marker_type: String) -> void:
	_board_viewport.set_marker(cell, marker_type)
	_marker_menu.hide()
	_interaction_state = IDLE


func get_board_render_snapshot() -> Dictionary:
	return _board_viewport.get_render_snapshot()


func get_layout_snapshot() -> Dictionary:
	var board_rect := Rect2(_board_frame.global_position - global_position, _board_frame.size)
	var main_buttons_inside: bool = true
	var minimum_button_height: float = INF
	for button: Button in [_status_button, _cancel_button, _confirm_button]:
		var button_rect := Rect2(button.global_position - global_position, button.size)
		main_buttons_inside = main_buttons_inside \
			and button_rect.position.x >= -0.5 \
			and button_rect.position.y >= -0.5 \
			and button_rect.end.x <= size.x + 0.5 \
			and button_rect.end.y <= size.y + 0.5
		minimum_button_height = minf(minimum_button_height, button.custom_minimum_size.y)
	return {
		"compact": _compact,
		"screen_size": size,
		"board_rect": board_rect,
		"point_spacing": _board_viewport.get_point_spacing(),
		"main_buttons_inside": main_buttons_inside,
		"main_button_min_height": minimum_button_height,
	}


func _set_compact_layout(compact: bool) -> void:
	_compact = compact
	_compact_placeholder.visible = false
	if compact:
		if _status_panel.get_parent() != _compact_status_host:
			_status_panel.reparent(_compact_status_host)
		_wide_status_host.visible = false
		_status_button.visible = true
	else:
		if _status_panel.get_parent() != _wide_status_host:
			_status_panel.reparent(_wide_status_host)
		_wide_status_host.visible = true
		_status_button.visible = false
	_workspace.queue_sort()


func _clear_local_interaction() -> void:
	_interaction_state = IDLE
	_selected_piece_id = ""
	_prepared_preview_id = ""
	_confirmation_panel.visible = false
	_board_viewport.clear_interaction()


func _cancel_only() -> void:
	if _interaction_state == CONFIRMING:
		_clear_local_interaction()
		prepared_action_cancel_requested.emit()
	elif _interaction_state != IDLE:
		_clear_local_interaction()


func _on_viewport_size_changed() -> void:
	apply_layout_for_size(size)


func _on_cancel_or_marker_requested(cell: Vector2i) -> void:
	handle_cancel_or_marker(cell)


func _on_marker_selected(cell: Vector2i, marker_type: String) -> void:
	apply_marker(cell, marker_type)


func _on_status_button_pressed() -> void:
	if _compact:
		_compact_status_drawer.popup_centered_ratio(0.78)
