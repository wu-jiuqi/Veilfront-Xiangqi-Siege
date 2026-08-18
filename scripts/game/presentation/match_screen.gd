extends Control

signal prepared_action_cancel_requested()
signal marker_menu_requested(cell: Vector2i)
signal action_previews_requested(piece_id: String, action_type: String)
signal action_prepare_requested(preview_id: String)
signal action_confirm_requested(preview_id: String)
signal skip_requested()

const COMPACT_BREAKPOINT: float = 1100.0
const IDLE: String = "IDLE"
const SELECTED: String = "SELECTED"
const PREVIEW_SELECTED: String = "PREVIEW_SELECTED"
const CONFIRMING: String = "CONFIRMING"
const MARKER_MENU: String = "MARKER_MENU"
const Presenter = preload("res://scripts/game/presentation/match_screen_presenter.gd")

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
@onready var _turn_label: Label = $SafeMargin/Page/MatchHeader/Content/TurnLabel
@onready var _round_label: Label = $SafeMargin/Page/MatchHeader/Content/RoundLabel
@onready var _wall_status: Label = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/WallStatus
@onready var _flag_status: Label = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/FlagStatus
@onready var _casualty_status: Label = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/CasualtyStatus
@onready var _skip_button: Button = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/SkipButton
@onready var _action_prompt: Label = $ActionConfirmationPanel/Content/Prompt
@onready var _action_cancel_button: Button = $ActionConfirmationPanel/Content/Buttons/CancelButton
@onready var _action_confirm_button: Button = $ActionConfirmationPanel/Content/Buttons/ConfirmButton

var _compact: bool = false
var _interaction_state: String = IDLE
var _selected_piece_id: String = ""
var _prepared_preview_id: String = ""
var _presenter: MatchScreenPresenter = Presenter.new()
var _presentation_model: Dictionary = {}
var _current_previews: Array = []
var _last_event_model: Dictionary = {}
var _last_error_model: Dictionary = {}


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_board_viewport.cancel_or_marker_requested.connect(_on_cancel_or_marker_requested)
	_marker_menu.marker_selected.connect(_on_marker_selected)
	_status_button.pressed.connect(_on_status_button_pressed)
	_cancel_button.pressed.connect(_cancel_only)
	_confirm_button.pressed.connect(confirm_prepared_action)
	_action_cancel_button.pressed.connect(_cancel_only)
	_action_confirm_button.pressed.connect(confirm_prepared_action)
	_skip_button.pressed.connect(func() -> void: skip_requested.emit())
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
	_presentation_model = _presenter.player_view_model(view)
	_turn_label.text = str(_presentation_model.get("turn_text", "行动方：--"))
	_round_label.text = str(_presentation_model.get("round_text", "回合：-- / 50"))
	_wall_status.text = str(_presentation_model.get("wall_text", "城墙：--"))
	_flag_status.text = str(_presentation_model.get("flag_text", "旗帜：--"))
	_casualty_status.text = str(_presentation_model.get("casualty_text", "阵亡：--"))
	_board_viewport.render_player_view(view)


func render_session_state(_public_state: Dictionary) -> void:
	pass


func render_visible_events(events: Array) -> void:
	_last_event_model = _presenter.visible_event_model(events)


func render_visible_error(error: Dictionary) -> void:
	_last_error_model = _presenter.visible_error_model(error)
	var message_key: String = str(_last_error_model.get("message_key", ""))
	if not message_key.is_empty():
		_action_prompt.text = message_key


func render_action_previews_from_port(previews: Array) -> void:
	_current_previews = previews.duplicate(true)


func render_prepared_action(preview_id: String) -> void:
	if preview_id.is_empty():
		_clear_local_interaction()
		return
	set_local_interaction_state(CONFIRMING, _selected_piece_id, preview_id)
	_action_prompt.text = _preview_message_key(preview_id)


func render_action_previews(selected_cell: Vector2i, previews: Array) -> void:
	_board_viewport.set_interaction(selected_cell, previews)


func request_action_previews(piece_id: String, action_type: String) -> void:
	_selected_piece_id = piece_id
	_interaction_state = SELECTED
	action_previews_requested.emit(piece_id, action_type)


func prepare_action(preview_id: String) -> void:
	if not _has_preview(preview_id):
		return
	_prepared_preview_id = preview_id
	_interaction_state = PREVIEW_SELECTED
	action_prepare_requested.emit(preview_id)


func confirm_prepared_action() -> void:
	if _interaction_state != CONFIRMING or _prepared_preview_id.is_empty():
		return
	var preview_id: String = _prepared_preview_id
	_clear_local_interaction()
	action_confirm_requested.emit(preview_id)


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


func get_presentation_snapshot() -> Dictionary:
	return {
		"match_id": str(_presentation_model.get("match_id", "")),
		"viewer_side": str(_presentation_model.get("viewer_side", "")),
		"event_count": int(_last_event_model.get("count", 0)),
		"last_event_message_key": str(_last_event_model.get("message_key", "")),
		"last_error_message_key": str(_last_error_model.get("message_key", "")),
		"preview_count": _current_previews.size(),
		"prepared_preview_id": _prepared_preview_id,
		"interaction_state": _interaction_state,
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


func _has_preview(preview_id: String) -> bool:
	for preview: Variant in _current_previews:
		if preview is Dictionary and str(preview.get("preview_id", "")) == preview_id:
			return true
	return false


func _preview_message_key(preview_id: String) -> String:
	for preview: Variant in _current_previews:
		if preview is Dictionary and str(preview.get("preview_id", "")) == preview_id:
			return str(preview.get("message_key", "action.confirm"))
	return "action.confirm"
