extends Control

signal prepared_action_cancel_requested()
signal marker_menu_requested(cell: Vector2i)
signal action_previews_requested(piece_id: String, action_type: String)
signal action_prepare_requested(preview_id: String)
signal action_confirm_requested(preview_id: String)
signal skip_requested()
signal turn_timeout_requested(expected_action_index: int)
signal return_requested()
signal selection_cancelled()
signal marker_applied(cell: Vector2i, marker_type: String)
signal board_point_activated(cell: Vector2i)
signal tutorial_input_rejected(message: String)

const COMPACT_BREAKPOINT: float = 1100.0
const MINIMUM_ACTION_TARGET_HEIGHT: float = 44.0
const IDLE: String = "IDLE"
const SELECTED: String = "SELECTED"
const PREVIEW_SELECTED: String = "PREVIEW_SELECTED"
const CONFIRMING: String = "CONFIRMING"
const MARKER_MENU: String = "MARKER_MENU"
const Presenter = preload("res://scripts/game/presentation/match_screen_presenter.gd")
const PIECE_PORTRAITS := {
	"red": {
		"general": preload("res://assets/art/pieces/terracotta_warriors/red_general_idle.png"),
		"guard": preload("res://assets/art/pieces/terracotta_warriors/red_guard_idle.png"),
		"minister": preload("res://assets/art/pieces/terracotta_warriors/red_minister_idle.png"),
		"cavalry": preload("res://assets/art/pieces/terracotta_warriors/red_cavalry_idle.png"),
		"chariot": preload("res://assets/art/pieces/terracotta_warriors/red_chariot_idle.png"),
		"trebuchet": preload("res://assets/art/pieces/terracotta_warriors/red_trebuchet_idle.png"),
		"infantry": preload("res://assets/art/pieces/terracotta_warriors/red_infantry_idle.png"),
	},
	"black": {
		"general": preload("res://assets/art/pieces/terracotta_warriors/black_general_idle.png"),
		"guard": preload("res://assets/art/pieces/terracotta_warriors/black_guard_idle.png"),
		"minister": preload("res://assets/art/pieces/terracotta_warriors/black_minister_idle.png"),
		"cavalry": preload("res://assets/art/pieces/terracotta_warriors/black_cavalry_idle.png"),
		"chariot": preload("res://assets/art/pieces/terracotta_warriors/black_chariot_idle.png"),
		"trebuchet": preload("res://assets/art/pieces/terracotta_warriors/black_trebuchet_idle.png"),
		"infantry": preload("res://assets/art/pieces/terracotta_warriors/black_infantry_idle.png"),
	},
}

@export var allow_known_illegal_previews: bool = false
@export var turn_timeout_enabled: bool = false

@onready var _hud_layout: MatchHudLayout = $MatchHudV2
@onready var _board_frame: Control = $MatchHudV2/BoardFrame
@onready var _board_viewport: SubViewportContainer = $MatchHudV2/BoardFrame/BoardViewport
@onready var _marker_menu: PopupPanel = %MarkerMenu
@onready var _confirmation_panel: PanelContainer = %ActionConfirmationPanel
@onready var _incense_turn_clock: IncenseTurnClock = $MatchHudV2/IncenseTurnClock
@onready var _piece_info_drawer: PieceInfoDrawer = $MatchHudV2/PieceInfoDrawer
@onready var _return_button: Button = $MatchHudV2/FactionLeft/ReturnButton
@onready var _mirror_button: Button = $MatchHudV2/FactionRight/MirrorButton
@onready var _selection_status: Label = $MatchHudV2/ObjectiveEvents/SelectionStatus
@onready var _board_position: Label = $MatchHudV2/ObjectiveEvents/BoardPosition
@onready var _message_value: Label = $MatchHudV2/ObjectiveEvents/MessageValue
@onready var _move_button: Button = \
	$MatchHudV2/PieceInfoDrawer/ContentMargin/ContentRow/SkillButtons/MoveButton
@onready var _bombard_button: Button = \
	$MatchHudV2/PieceInfoDrawer/ContentMargin/ContentRow/SkillButtons/BombardButton
@onready var _resurrect_button: Button = \
	$MatchHudV2/PieceInfoDrawer/ContentMargin/ContentRow/SkillButtons/ResurrectButton
@onready var _pass_button: Button = $MatchHudV2/ObjectiveEvents/PassButton
@onready var _own_flags: Label = $MatchHudV2/ObjectiveEvents/OwnFlags
@onready var _own_casualties: Label = $MatchHudV2/ObjectiveEvents/OwnCasualties
@onready var _enemy_casualties: Label = $MatchHudV2/ObjectiveEvents/EnemyCasualties
@onready var _faction_left_turn: Label = $MatchHudV2/FactionLeft/FactionLeftTurn
@onready var _faction_left_stats: Label = $MatchHudV2/FactionLeft/FactionLeftStats
@onready var _faction_right_turn: Label = $MatchHudV2/FactionRight/FactionRightTurn
@onready var _faction_right_stats: Label = $MatchHudV2/FactionRight/FactionRightStats
@onready var _unit_name: Label = $MatchHudV2/UnitInfo/UnitName
@onready var _unit_portrait: TextureRect = $MatchHudV2/UnitInfo/UnitPortrait
@onready var _tactical_minimap: TacticalMinimap = $MatchHudV2/Minimap/TacticalMinimap
@onready var _action_prompt: Label = $ActionConfirmationPanel/Content/Prompt
@onready var _action_cancel_button: Button = $ActionConfirmationPanel/Content/Buttons/CancelButton
@onready var _action_confirm_button: Button = $ActionConfirmationPanel/Content/Buttons/ConfirmButton
@onready var _terminal_dialog: AcceptDialog = $TerminalDialog
@onready var _terminal_restart_button: Button = $TerminalDialog/RestartButton

var _compact: bool = false
var _interaction_state: String = IDLE
var _selected_piece_id: String = ""
var _prepared_preview_id: String = ""
var _presenter: MatchScreenPresenter = Presenter.new()
var _presentation_model: Dictionary = {}
var _current_previews: Array = []
var _last_event_model: Dictionary = {}
var _last_error_model: Dictionary = {}
var _prepare_generation: int = 0
var _inflight_prepare_generation: int = 0
var _inflight_prepare_preview_id: String = ""
var _cancelled_prepare_tombstones: Dictionary = {}
var _current_view: Dictionary = {}
var _action_mode: String = "move"
var _tutorial_panel_width: float = 0.0
var _tutorial_step: Dictionary = {}
var _tutorial_navigation_enabled: bool = false
var _session_navigation_enabled: bool = false
var _submission_pending: bool = false


func _ready() -> void:
	_enforce_action_target_sizes()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	resized.connect(_on_match_screen_resized)
	_board_viewport.point_activated.connect(handle_board_point)
	_board_viewport.cancel_or_marker_requested.connect(_on_cancel_or_marker_requested)
	_board_viewport.hovered_cell_changed.connect(_on_board_hovered_cell_changed)
	_board_viewport.overview_changed.connect(_tactical_minimap.set_overview_state)
	_tactical_minimap.overview_navigation_requested.connect(
		_board_viewport.navigate_to_overview_ratio
	)
	_marker_menu.marker_selected.connect(_on_marker_selected)
	_marker_menu.popup_hide.connect(_on_marker_menu_hidden)
	_return_button.pressed.connect(func() -> void: return_requested.emit())
	_mirror_button.pressed.connect(_toggle_mirror_view)
	_action_cancel_button.pressed.connect(_cancel_only)
	_action_confirm_button.pressed.connect(confirm_prepared_action)
	_move_button.pressed.connect(_set_action_mode.bind("move"))
	_bombard_button.pressed.connect(_set_action_mode.bind("bombard"))
	_resurrect_button.pressed.connect(_set_action_mode.bind("resurrect"))
	_pass_button.pressed.connect(_prepare_pass)
	_incense_turn_clock.timed_out.connect(_on_turn_timeout_requested)
	_tactical_minimap.set_overview_state(_board_viewport.get_overview_state())
	_sync_board_position_from_board()
	call_deferred("apply_layout_for_size", size)


func _enforce_action_target_sizes() -> void:
	for button: Button in [_move_button, _bombard_button, _resurrect_button, _pass_button]:
		button.custom_minimum_size.y = maxf(
			button.custom_minimum_size.y,
			MINIMUM_ACTION_TARGET_HEIGHT
		)


func _toggle_mirror_view() -> void:
	_board_viewport.toggle_presentation_side()
	_tactical_minimap.set_presentation_side(_board_viewport.get_presentation_side())
	_update_mirror_button()


func _update_mirror_button() -> void:
	if not is_instance_valid(_mirror_button):
		return
	var showing_black: bool = _board_viewport.get_presentation_side() == "black"
	_mirror_button.text = "赤视角" if showing_black else "玄视角"
	_mirror_button.tooltip_text = "切回赤方视角" if showing_black else "切换玄方镜像视角"


func set_tutorial_navigation_enabled(enabled: bool) -> void:
	_tutorial_navigation_enabled = enabled
	_update_return_button()
	if enabled:
		_return_button.text = "退出教学"
	elif _session_navigation_enabled:
		_return_button.text = "退出对局"


func set_session_navigation_enabled(enabled: bool) -> void:
	_session_navigation_enabled = enabled
	_update_return_button()
	_mirror_button.visible = not enabled
	_terminal_restart_button.visible = not enabled
	if enabled:
		_return_button.text = "退出对局"


func show_session_terminal(message: String) -> void:
	_terminal_restart_button.visible = false
	_terminal_dialog.dialog_text = message if not message.is_empty() else "战局已经结束。"
	_terminal_dialog.popup_centered()


func reset_for_session_end() -> void:
	_clear_local_interaction()
	_current_view.clear()
	_current_previews.clear()
	_last_event_model.clear()
	_last_error_model.clear()
	_presentation_model.clear()
	_cancelled_prepare_tombstones.clear()
	_submission_pending = false
	_marker_menu.hide()
	_terminal_dialog.hide()
	_board_viewport.clear_session_view()
	_tactical_minimap.clear_session_view()
	_incense_turn_clock.sync_player_view({}, false)
	_message_value.text = "等待正式战局。"
	_update_status_controls()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _marker_menu.visible:
		_marker_menu.hide()
		_interaction_state = IDLE
	else:
		_cancel_only()
	get_viewport().set_input_as_handled()


func apply_layout_for_size(requested_size: Vector2) -> void:
	_hud_layout.apply_layout_for_size(requested_size, _tutorial_panel_width)
	_update_return_button()
	_set_compact_layout(requested_size.x < COMPACT_BREAKPOINT)
	_sync_board_position_from_board()


func set_hud_scene_authored_layout_enabled(enabled: bool) -> void:
	_hud_layout.set_scene_authored_layout_enabled(enabled)


func set_tutorial_panel_width(panel_width: float) -> void:
	_tutorial_panel_width = maxf(0.0, panel_width)
	call_deferred("apply_layout_for_size", size)


func set_action_mode(mode: String) -> void:
	if mode not in ["move", "bombard", "resurrect"]:
		return
	_set_action_mode(mode)


func focus_tutorial_step(step: Dictionary) -> void:
	_tutorial_step = step.duplicate(true)
	var focus_cell := Vector2i.ZERO
	var actor_id := str(step.get("actor", ""))
	if not actor_id.is_empty():
		focus_cell = _piece_cell_by_id(actor_id)
	if not BoardCoordinateMapper.is_authority_cell_valid(focus_cell):
		focus_cell = BoardCoordinateMapper.coordinate_from_variant(
			step.get("target", step.get("point", []))
		)
	if BoardCoordinateMapper.is_authority_cell_valid(focus_cell):
		_board_viewport.focus_authority_cell(focus_cell)
	var target := BoardCoordinateMapper.coordinate_from_variant(step.get("target", [])) \
		if bool(step.get("show_target", true)) else Vector2i.ZERO
	_board_viewport.set_tutorial_target(target)


func reset_tutorial_step_interaction() -> void:
	_clear_local_interaction()
	var expected_mode := _tutorial_expected_action_mode()
	if not expected_mode.is_empty():
		_action_mode = expected_mode
	_update_status_controls()


func render_player_view(view: Dictionary) -> void:
	_submission_pending = false
	_current_view = view.duplicate(true)
	_presentation_model = _presenter.player_view_model(view)
	_incense_turn_clock.sync_player_view(view, turn_timeout_enabled)
	_board_viewport.render_player_view(view)
	_tactical_minimap.render_player_view(view, _board_viewport.get_presentation_side())
	_update_faction_panels()
	_update_unit_card()
	_update_mirror_button()
	_update_status_controls()


func render_session_state(_public_state: Dictionary) -> void:
	pass


func render_visible_events(events: Array) -> void:
	_last_event_model = _presenter.visible_event_model(events)
	var event_message := str(_last_event_model.get("message_key", ""))
	if _interaction_state == IDLE and not event_message.is_empty():
		_message_value.text = "战报：%s" % event_message


func render_visible_error(error: Dictionary) -> void:
	_submission_pending = false
	_last_error_model = _presenter.visible_error_model(error)
	var message_key: String = str(_last_error_model.get("message_key", ""))
	if not message_key.is_empty():
		_action_prompt.text = message_key


func render_action_previews_from_port(previews: Array) -> void:
	_current_previews = previews.duplicate(true)
	_refresh_selected_previews()


func render_prepared_action(preview_id: String) -> void:
	if preview_id.is_empty():
		if _interaction_state in [PREVIEW_SELECTED, CONFIRMING]:
			_clear_local_interaction()
		return
	if _cancelled_prepare_tombstones.has(preview_id):
		_consume_prepare_tombstone(preview_id)
		return
	if _interaction_state != PREVIEW_SELECTED:
		return
	if preview_id != _inflight_prepare_preview_id or _inflight_prepare_generation <= 0:
		return
	_inflight_prepare_generation = 0
	_inflight_prepare_preview_id = ""
	set_local_interaction_state(CONFIRMING, _selected_piece_id, preview_id)
	_action_prompt.text = _preview_message_key(preview_id)


func render_action_previews(selected_cell: Vector2i, previews: Array) -> void:
	_board_viewport.set_interaction(selected_cell, previews)


func request_action_previews(piece_id: String, action_type: String) -> void:
	_selected_piece_id = piece_id
	_interaction_state = SELECTED
	action_previews_requested.emit(piece_id, action_type)


func handle_board_point(cell: Vector2i) -> void:
	board_point_activated.emit(cell)
	var tutorial_type := str(_tutorial_step.get("type", ""))
	if tutorial_type in ["observe", "quiz", "annotate"]:
		_reject_tutorial_input("当前步骤不接受棋盘行动，请按教学面板操作。")
		return
	if not _can_submit_action():
		_message_value.text = "当前不是己方行动阶段。"
		return
	var own_piece: Dictionary = _owned_piece_at(cell)
	if _selected_piece_id.is_empty():
		if own_piece.is_empty():
			_message_value.text = "请先选择一枚己方棋子。"
			return
		if not _tutorial_actor_matches(str(own_piece.get("id", ""))):
			_reject_tutorial_input("当前目标需要使用另一枚棋子。")
			return
		_select_piece(own_piece)
		return
	if not _tutorial_target_matches(cell):
		_reject_tutorial_input("这个交点不是当前教学目标。")
		return
	if _action_mode == "bombard":
		var bombard_preview: Dictionary = _preview_for_target(cell)
		if not bombard_preview.is_empty():
			prepare_action(str(bombard_preview.get("preview_id", "")))
			return
	if not own_piece.is_empty():
		if not _tutorial_actor_matches(str(own_piece.get("id", ""))):
			_reject_tutorial_input("当前目标需要使用另一枚棋子。")
			return
		_select_piece(own_piece)
		return
	var preview: Dictionary = _preview_for_target(cell)
	if preview.is_empty():
		_message_value.text = "该交点不是当前模式下可提交的公开预览。"
		return
	prepare_action(str(preview.get("preview_id", "")))


func prepare_action(preview_id: String) -> void:
	if not _has_preview(preview_id):
		return
	_prepare_generation += 1
	_inflight_prepare_generation = _prepare_generation
	_inflight_prepare_preview_id = preview_id
	_prepared_preview_id = preview_id
	_interaction_state = PREVIEW_SELECTED
	action_prepare_requested.emit(preview_id)


func confirm_prepared_action() -> void:
	if _interaction_state != CONFIRMING or _prepared_preview_id.is_empty():
		return
	var preview_id: String = _prepared_preview_id
	_clear_local_interaction()
	_submission_pending = true
	_update_status_controls()
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
	if state == CONFIRMING:
		_action_cancel_button.grab_focus()
	_update_status_controls()


func get_local_interaction_state() -> String:
	return _interaction_state


func handle_cancel_or_marker(
	cell: Vector2i,
	point_position: Vector2 = Vector2(INF, INF)
) -> String:
	if _interaction_state in [PREVIEW_SELECTED, CONFIRMING]:
		_cancel_prepared_action_locally()
		return "cancel_prepared_action"
	if _interaction_state == SELECTED:
		_clear_local_interaction()
		selection_cancelled.emit()
		return "cancel_selection"
	if _interaction_state == MARKER_MENU:
		if _marker_menu.get_cell() == cell:
			_marker_menu.hide()
			_interaction_state = IDLE
			return "close_marker_menu"
		_marker_menu.hide()
	if not is_finite(point_position.x) or not is_finite(point_position.y):
		point_position = get_viewport().get_mouse_position()
	_marker_menu.open_for_cell(
		cell,
		point_position,
		get_viewport().get_visible_rect(),
		_board_viewport.has_marker(cell)
	)
	_interaction_state = MARKER_MENU
	marker_menu_requested.emit(cell)
	return "open_marker_menu"


func apply_marker(cell: Vector2i, marker_type: String) -> void:
	if str(_tutorial_step.get("type", "")) == "annotate":
		var target := BoardCoordinateMapper.coordinate_from_variant(_tutorial_step.get("target", []))
		if cell != target or marker_type != str(_tutorial_step.get("marker", "")):
			_reject_tutorial_input("标记位置或类型与当前目标不一致。")
			return
	if marker_type.is_empty():
		_board_viewport.clear_marker(cell)
		_message_value.text = "已清除交点（%d,%d）的本地标注。" % [cell.x, cell.y]
	else:
		_board_viewport.set_marker(cell, marker_type)
		_message_value.text = "已更新交点（%d,%d）的本地标注。" % [cell.x, cell.y]
	_marker_menu.hide()
	_interaction_state = IDLE
	marker_applied.emit(cell, marker_type)


func get_board_render_snapshot() -> Dictionary:
	return _board_viewport.get_render_snapshot()


func set_board_presentation_assets(theme: BoardTheme, map_option: BoardMapOption) -> void:
	_board_viewport.set_presentation_assets(theme, map_option)


func get_layout_snapshot() -> Dictionary:
	var hud_snapshot: Dictionary = _hud_layout.get_layout_snapshot()
	var board_rect: Rect2 = hud_snapshot.get(
		"board_rect",
		Rect2(_board_frame.global_position - global_position, _board_frame.size)
	)
	var main_buttons_inside: bool = true
	var minimum_button_height: float = INF
	for button: Button in [_move_button, _bombard_button, _resurrect_button, _pass_button]:
		var button_rect := Rect2(button.global_position - global_position, button.size)
		main_buttons_inside = main_buttons_inside \
			and button_rect.position.x >= -0.5 \
			and button_rect.position.y >= -0.5 \
			and button_rect.end.x <= size.x + 0.5 \
			and button_rect.end.y <= size.y + 0.5
		minimum_button_height = minf(minimum_button_height, button.custom_minimum_size.y)
	var confirmation_button_min_height: float = minf(
		_action_cancel_button.custom_minimum_size.y,
		_action_confirm_button.custom_minimum_size.y
	)
	return {
		"compact": _compact,
		"screen_size": size,
		"board_rect": board_rect,
		"board_rect_meaning": str(hud_snapshot.get("board_rect_meaning", "")),
		"active_profile": str(hud_snapshot.get("active_profile", "")),
		"ui_rects": hud_snapshot.get("ui_rects", {}).duplicate(true),
		"minimap": _tactical_minimap.get_state_snapshot(),
		"point_spacing": _board_viewport.get_point_spacing(),
		"main_buttons_inside": main_buttons_inside,
		"main_button_min_height": minimum_button_height,
		"confirmation_panel_inside": _control_inside_screen(_confirmation_panel),
		"confirmation_prompt_inside": _control_inside_screen(_action_prompt),
		"confirmation_buttons_inside": _control_inside_screen(_action_cancel_button) \
			and _control_inside_screen(_action_confirm_button),
		"confirmation_button_min_height": confirmation_button_min_height,
		"confirmation_prompt_text": _action_prompt.text,
		"incense_clock": _incense_turn_clock.get_state_snapshot(),
		"piece_info_drawer": _piece_info_drawer.get_state_snapshot(),
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
		"selected_piece_id": _selected_piece_id,
		"action_mode": _action_mode,
		"action_index": int(_current_view.get("action_index", 0)),
		"submission_pending": _submission_pending,
	}


func get_player_view_snapshot() -> Dictionary:
	return _current_view.duplicate(true)


func get_hud_snapshot() -> Dictionary:
	return {
		"layout": _hud_layout.get_layout_snapshot(),
		"faction_left": {
			"turn": _faction_left_turn.text,
			"stats": _faction_left_stats.text,
		},
		"faction_right": {
			"turn": _faction_right_turn.text,
			"stats": _faction_right_stats.text,
		},
		"unit": {
			"name": _unit_name.text,
			"portrait": _unit_portrait.texture.resource_path \
				if _unit_portrait.texture != null else "",
		},
		"objective": {
			"selection": _selection_status.text,
			"position": _board_position.text,
			"mode": _action_mode,
			"message": _message_value.text,
			"event": str(_last_event_model.get("message_key", "")),
			"own_flags": _own_flags.text,
			"own_casualties": _own_casualties.text,
			"enemy_casualties": _enemy_casualties.text,
		},
		"minimap": _tactical_minimap.get_state_snapshot(),
		"incense_clock": _incense_turn_clock.get_state_snapshot(),
		"piece_info_drawer": _piece_info_drawer.get_state_snapshot(),
	}


func _set_compact_layout(compact: bool) -> void:
	_compact = compact


func _update_return_button() -> void:
	if not is_instance_valid(_return_button):
		return
	_return_button.visible = _tutorial_navigation_enabled \
		or _session_navigation_enabled \
		or _hud_layout.is_text_layer_enabled("faction-left", "return")


func _clear_local_interaction() -> void:
	_interaction_state = IDLE
	_selected_piece_id = ""
	_prepared_preview_id = ""
	_inflight_prepare_generation = 0
	_inflight_prepare_preview_id = ""
	_confirmation_panel.visible = false
	_board_viewport.clear_interaction()
	_piece_info_drawer.hide_drawer()
	_update_status_controls()


func _cancel_only() -> void:
	if _interaction_state in [PREVIEW_SELECTED, CONFIRMING]:
		_cancel_prepared_action_locally()
	elif _interaction_state != IDLE:
		_clear_local_interaction()
		selection_cancelled.emit()


func _cancel_prepared_action_locally() -> void:
	var cancelled_preview_id: String = _prepared_preview_id
	if _interaction_state == PREVIEW_SELECTED \
		and not cancelled_preview_id.is_empty() \
		and _inflight_prepare_generation > 0:
		var generations: Array = _cancelled_prepare_tombstones.get(
			cancelled_preview_id,
			[]
		).duplicate()
		generations.append(_inflight_prepare_generation)
		_cancelled_prepare_tombstones[cancelled_preview_id] = generations
	_clear_local_interaction()
	prepared_action_cancel_requested.emit()


func _consume_prepare_tombstone(preview_id: String) -> void:
	var generations: Array = _cancelled_prepare_tombstones.get(preview_id, []).duplicate()
	if generations.is_empty():
		_cancelled_prepare_tombstones.erase(preview_id)
		return
	generations.pop_front()
	if generations.is_empty():
		_cancelled_prepare_tombstones.erase(preview_id)
	else:
		_cancelled_prepare_tombstones[preview_id] = generations


func _control_inside_screen(control: Control) -> bool:
	var control_rect := Rect2(control.global_position - global_position, control.size)
	return control_rect.position.x >= -0.5 \
		and control_rect.position.y >= -0.5 \
		and control_rect.end.x <= size.x + 0.5 \
		and control_rect.end.y <= size.y + 0.5


func _on_viewport_size_changed() -> void:
	apply_layout_for_size(size)


func _on_match_screen_resized() -> void:
	apply_layout_for_size(size)


func _on_board_hovered_cell_changed(cell: Vector2i) -> void:
	if BoardCoordinateMapper.is_authority_cell_valid(cell):
		_board_position.text = "位置: (%d, %d)" % [cell.x, cell.y]
	else:
		_board_position.text = _hud_layout.get_catalog_text(
			"objective-events", "text-1787297730520-1", "位置: (x, y)"
		)


func _sync_board_position_from_board() -> void:
	if not is_instance_valid(_board_position) or not is_instance_valid(_board_viewport):
		return
	var hovered_cell: Vector2i = _board_viewport.get_render_snapshot().get(
		"hovered_cell", Vector2i.ZERO
	)
	_on_board_hovered_cell_changed(hovered_cell)


func _on_cancel_or_marker_requested(cell: Vector2i) -> void:
	handle_cancel_or_marker(cell, get_viewport().get_mouse_position())


func _on_marker_selected(cell: Vector2i, marker_type: String) -> void:
	apply_marker(cell, marker_type)


func _on_marker_menu_hidden() -> void:
	if _interaction_state == MARKER_MENU:
		_interaction_state = IDLE


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


func _can_submit_action() -> bool:
	return not _current_view.is_empty() \
		and not _submission_pending \
		and not bool(_current_view.get("terminal", false)) \
		and str(_current_view.get("viewer_side", "")) == str(_current_view.get("active_side", ""))


func _owned_piece_at(cell: Vector2i) -> Dictionary:
	var viewer_side := str(_current_view.get("viewer_side", ""))
	for piece_value: Variant in _current_view.get("pieces", []):
		if not piece_value is Dictionary:
			continue
		var piece: Dictionary = piece_value
		if str(piece.get("side", "")) == viewer_side \
		and bool(piece.get("alive", false)) \
		and not bool(piece.get("in_reserve", false)) \
		and piece.get("position", []) == [cell.x, cell.y]:
			return piece.duplicate(true)
	return {}


func _piece_cell_by_id(piece_id: String) -> Vector2i:
	for piece_value: Variant in _current_view.get("pieces", []):
		if piece_value is Dictionary and str(piece_value.get("id", "")) == piece_id:
			return BoardCoordinateMapper.coordinate_from_variant(piece_value.get("position", []))
	return Vector2i.ZERO


func _select_piece(piece: Dictionary) -> void:
	_selected_piece_id = str(piece.get("id", ""))
	var piece_type := str(piece.get("piece_type", ""))
	if (_action_mode == "bombard" and piece_type != "cannon") \
	or (_action_mode == "resurrect" and piece_type != "advisor"):
		_action_mode = "move"
	_interaction_state = SELECTED
	_message_value.text = "已选择 %s；请选择目标交点。" % _selected_piece_id
	request_action_previews(_selected_piece_id, _action_mode)
	if _action_mode == "resurrect":
		_prepare_empty_target_preview()
	_update_status_controls()


func _preview_for_target(cell: Vector2i) -> Dictionary:
	for preview_value: Variant in _current_previews:
		if not preview_value is Dictionary:
			continue
		var preview: Dictionary = preview_value
		if str(preview.get("piece_id", "")) == _selected_piece_id \
		and str(preview.get("action_type", "")) == _action_mode \
		and preview.get("target_cell", []) == [cell.x, cell.y] \
		and (allow_known_illegal_previews \
			or str(preview.get("classification", "")) != "KNOWN_ILLEGAL"):
			return preview.duplicate(true)
	return {}


func _set_action_mode(mode: String) -> void:
	var expected_mode := _tutorial_expected_action_mode()
	if not expected_mode.is_empty() and mode != expected_mode:
		_reject_tutorial_input("当前步骤需要使用%s。" % {
			"move": "普通移动", "bombard": "区域炮击", "resurrect": "献祭复活",
		}.get(expected_mode, expected_mode))
		return
	_action_mode = mode
	_prepared_preview_id = ""
	_confirmation_panel.visible = false
	_board_viewport.clear_interaction()
	_message_value.text = {
		"move": "普通移动：选择己方棋子和目标交点。",
		"bombard": "区域炮击：先选择大本营内仍有弹药的己方炮。",
		"resurrect": "献祭复活：选择一枚在场己方士。",
	}.get(mode, "请选择行动。")
	if not _selected_piece_id.is_empty():
		_interaction_state = SELECTED
		request_action_previews(_selected_piece_id, _action_mode)
		if _action_mode == "resurrect":
			_prepare_empty_target_preview()
	_update_status_controls()


func _prepare_pass() -> void:
	if not _can_submit_action():
		return
	request_action_previews("", "pass")
	for preview_value: Variant in _current_previews:
		if preview_value is Dictionary and str(preview_value.get("action_type", "")) == "pass":
			prepare_action(str(preview_value.get("preview_id", "")))
			return
	_message_value.text = "当前没有可提交的主动跳过预览。"


func _prepare_empty_target_preview() -> void:
	for preview_value: Variant in _current_previews:
		if not preview_value is Dictionary:
			continue
		var preview: Dictionary = preview_value
		if str(preview.get("piece_id", "")) == _selected_piece_id \
		and str(preview.get("action_type", "")) == _action_mode \
		and preview.get("target_cell", []).is_empty():
			prepare_action(str(preview.get("preview_id", "")))
			return


func _refresh_selected_previews() -> void:
	if _selected_piece_id.is_empty():
		return
	var selected_cell := Vector2i.ZERO
	for piece_value: Variant in _current_view.get("pieces", []):
		if piece_value is Dictionary and str(piece_value.get("id", "")) == _selected_piece_id:
			var position: Array = piece_value.get("position", [])
			if position.size() == 2:
				selected_cell = Vector2i(int(position[0]), int(position[1]))
			break
	var filtered: Array = []
	for preview_value: Variant in _current_previews:
		if preview_value is Dictionary \
		and str(preview_value.get("piece_id", "")) == _selected_piece_id \
		and str(preview_value.get("action_type", "")) == _action_mode:
			filtered.append(preview_value)
	_board_viewport.set_interaction(selected_cell, filtered)


func _update_status_controls() -> void:
	if not is_instance_valid(_selection_status):
		return
	_board_viewport.set_piece_visual_hit_enabled(_selected_piece_id.is_empty())
	var selected_piece := _piece_by_id(_selected_piece_id)
	var selected_name := "无"
	if not selected_piece.is_empty():
		selected_name = _piece_display_name(str(selected_piece.get("piece_type", "")))
	_selection_status.text = "行动方: %s 已选: %s" % [
		_side_display_name(str(_current_view.get("active_side", ""))),
		selected_name,
	]
	var disabled := not _can_submit_action()
	_move_button.disabled = disabled
	_bombard_button.disabled = disabled
	_resurrect_button.disabled = disabled
	_pass_button.disabled = disabled
	_move_button.button_pressed = _action_mode == "move"
	_bombard_button.button_pressed = _action_mode == "bombard"
	_resurrect_button.button_pressed = _action_mode == "resurrect"
	_update_faction_panels()
	_update_objective_summary()
	_update_unit_card()


func _update_faction_panels() -> void:
	if not is_instance_valid(_faction_left_turn):
		return
	var active_side := str(_current_view.get("active_side", ""))
	_faction_left_turn.text = "正在行动" if active_side == "red" else "等待行动"
	_faction_right_turn.text = "正在行动" if active_side == "black" else "等待行动"
	_faction_left_stats.text = "墙 %s · 旗 %d · 损 %d" % [
		_side_wall_status("red"),
		_side_flag_count("red"),
		_side_casualty_count("red"),
	]
	_faction_right_stats.text = "墙 %s · 旗 %d · 损 %d" % [
		_side_wall_status("black"),
		_side_flag_count("black"),
		_side_casualty_count("black"),
	]


func _update_unit_card() -> void:
	if not is_instance_valid(_unit_name):
		return
	var piece := _piece_by_id(_selected_piece_id)
	if piece.is_empty():
		_unit_name.text = "未选择棋子"
		_unit_portrait.texture = null
		_unit_portrait.visible = true
		_piece_info_drawer.hide_drawer()
		return

	var piece_type := str(piece.get("piece_type", "unknown"))
	var piece_name := _piece_display_name(piece_type)
	_unit_name.text = piece_name
	_unit_portrait.texture = _piece_portrait_texture(str(piece.get("side", "")), piece_type)
	_unit_portrait.visible = _unit_portrait.texture != null
	_piece_info_drawer.show_piece(piece, _can_submit_action())


func _update_objective_summary() -> void:
	if not is_instance_valid(_own_flags):
		return
	var viewer_side := str(_current_view.get("viewer_side", "red"))
	var enemy_side := "black" if viewer_side == "red" else "red"
	var discovered_flags := 0
	for flag_value: Variant in _current_view.get("flags", []):
		if flag_value is Dictionary and bool(flag_value.get("discovered", false)):
			discovered_flags += 1
	_own_flags.text = _format_catalog_counter(
		_hud_layout.get_catalog_text("objective-events", "move", "我方已发现旗帜：0/3"),
		discovered_flags,
		3
	)
	_own_casualties.text = _format_casualty_summary(
		_hud_layout.get_catalog_text("objective-events", "bombard", "我方阵亡："),
		viewer_side
	)
	_enemy_casualties.text = _format_casualty_summary(
		_hud_layout.get_catalog_text("objective-events", "pass", "敌方阵亡："),
		enemy_side
	)


func _format_catalog_counter(template: String, count: int, total: int = -1) -> String:
	if "{count}" in template or "{total}" in template:
		return template.replace("{count}", str(count)).replace("{total}", str(total))
	var separator_index := maxi(template.rfind("："), template.rfind(":"))
	var prefix := template.substr(0, separator_index + 1).strip_edges() \
		if separator_index >= 0 else template.strip_edges()
	if total >= 0:
		return "%s %d/%d" % [prefix, count, total]
	return "%s %d" % [prefix, count]


func _format_casualty_summary(template: String, side: String) -> String:
	var counts: Dictionary = {}
	var ordered_names: Array[String] = []
	for casualty_value: Variant in _current_view.get("casualties", []):
		if not casualty_value is Dictionary \
		or str(casualty_value.get("side", "")) != side:
			continue
		var piece_name := _piece_display_name(str(casualty_value.get("piece_type", "")))
		if not counts.has(piece_name):
			counts[piece_name] = 0
			ordered_names.append(piece_name)
		counts[piece_name] = int(counts[piece_name]) + 1
	var details := PackedStringArray()
	for piece_name: String in ordered_names:
		details.append("%s*%d" % [piece_name, int(counts[piece_name])])
	var separator_index := maxi(template.rfind("："), template.rfind(":"))
	var prefix := template.substr(0, separator_index + 1).strip_edges() \
		if separator_index >= 0 else template.strip_edges()
	return "%s %s" % [prefix, ", ".join(details) if not details.is_empty() else "无"]


func _piece_display_name(piece_type: String) -> String:
	return {
		"general": "将帅", "guard": "士", "advisor": "士",
		"minister": "相", "elephant": "象",
		"chariot": "车", "rook": "车", "cavalry": "骑", "horse": "马",
		"trebuchet": "砲", "cannon": "炮",
		"infantry": "兵", "soldier": "兵", "pawn": "兵",
	}.get(piece_type, piece_type if not piece_type.is_empty() else "未知")


func _side_display_name(side: String) -> String:
	return {"red": "赤", "black": "玄"}.get(side, "—")


func _piece_portrait_texture(side: String, piece_type: String) -> Texture2D:
	var canonical_type: String = str({
		"advisor": "guard",
		"elephant": "minister",
		"horse": "cavalry",
		"rook": "chariot",
		"cannon": "trebuchet",
		"soldier": "infantry",
		"pawn": "infantry",
	}.get(piece_type, piece_type))
	var side_portraits: Dictionary = PIECE_PORTRAITS.get(side, {})
	return side_portraits.get(canonical_type) as Texture2D


func _on_turn_timeout_requested(expected_action_index: int) -> void:
	if not turn_timeout_enabled \
	or expected_action_index != int(_current_view.get("action_index", -1)) \
	or not _can_submit_action():
		return
	_clear_local_interaction()
	_message_value.text = "计时香已燃尽，系统正在选择一条合法移动。"
	turn_timeout_requested.emit(expected_action_index)


func _piece_by_id(piece_id: String) -> Dictionary:
	if piece_id.is_empty():
		return {}
	for piece_value: Variant in _current_view.get("pieces", []):
		if piece_value is Dictionary and str(piece_value.get("id", "")) == piece_id:
			return piece_value
	return {}


func _side_wall_status(side: String) -> String:
	for wall_value: Variant in _current_view.get("walls", []):
		if not wall_value is Dictionary or str(wall_value.get("side", "")) != side:
			continue
		return {
			"INTACT": "完好",
			"REPAIRING": "修复",
			"BREACHED": "破损",
		}.get(str(wall_value.get("status", "")), "未知")
	return "未知"


func _side_flag_count(side: String) -> int:
	var count := 0
	for flag_value: Variant in _current_view.get("flags", []):
		if flag_value is Dictionary \
		and bool(flag_value.get("discovered", false)) \
		and str(flag_value.get("owner", "")) == side:
			count += 1
	return count


func _side_casualty_count(side: String) -> int:
	var count := 0
	for casualty_value: Variant in _current_view.get("casualties", []):
		if casualty_value is Dictionary and str(casualty_value.get("side", "")) == side:
			count += 1
	return count


func _tutorial_actor_matches(piece_id: String) -> bool:
	var expected_actor := str(_tutorial_step.get("actor", ""))
	return expected_actor.is_empty() or expected_actor == piece_id


func _tutorial_target_matches(cell: Vector2i) -> bool:
	var step_type := str(_tutorial_step.get("type", ""))
	if step_type not in ["move", "bombard", "reject"]:
		return true
	var expected := BoardCoordinateMapper.coordinate_from_variant(_tutorial_step.get("target", []))
	return not BoardCoordinateMapper.is_authority_cell_valid(expected) or expected == cell


func _tutorial_expected_action_mode() -> String:
	match str(_tutorial_step.get("type", "")):
		"move", "reject":
			return "move"
		"bombard":
			return "bombard"
		"sacrifice_cancel", "sacrifice_confirm":
			return "resurrect"
	return ""


func _reject_tutorial_input(message: String) -> void:
	_message_value.text = message
	tutorial_input_rejected.emit(message)
