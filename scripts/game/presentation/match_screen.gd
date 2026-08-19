extends Control

signal prepared_action_cancel_requested()
signal marker_menu_requested(cell: Vector2i)
signal action_previews_requested(piece_id: String, action_type: String)
signal action_prepare_requested(preview_id: String)
signal action_confirm_requested(preview_id: String)
signal skip_requested()
signal return_requested()
signal selection_cancelled()
signal marker_applied(cell: Vector2i, marker_type: String)
signal board_point_activated(cell: Vector2i)
signal tutorial_input_rejected(message: String)

const COMPACT_BREAKPOINT: float = 1100.0
const IDLE: String = "IDLE"
const SELECTED: String = "SELECTED"
const PREVIEW_SELECTED: String = "PREVIEW_SELECTED"
const CONFIRMING: String = "CONFIRMING"
const MARKER_MENU: String = "MARKER_MENU"
const Presenter = preload("res://scripts/game/presentation/match_screen_presenter.gd")

@export var allow_known_illegal_previews: bool = false

@onready var _workspace: HSplitContainer = %Workspace
@onready var _safe_margin: MarginContainer = $SafeMargin
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
@onready var _return_button: Button = $SafeMargin/Page/MatchHeader/Content/ReturnButton
@onready var _mirror_button: Button = $SafeMargin/Page/MatchHeader/Content/MirrorButton
@onready var _wall_status: Label = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/WallStatus
@onready var _flag_status: Label = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/FlagStatus
@onready var _casualty_status: Label = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/CasualtyStatus
@onready var _selection_status: Label = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/SelectionStatus
@onready var _mode_status: Label = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/ModeStatus
@onready var _message_value: Label = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/MessageValue
@onready var _move_button: Button = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/ActionMode/MoveButton
@onready var _bombard_button: Button = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/ActionMode/BombardButton
@onready var _resurrect_button: Button = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/ActionMode/ResurrectButton
@onready var _pass_button: Button = $SafeMargin/Page/Workspace/WideStatusHost/MatchStatusPanel/Content/ActionMode/PassButton
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
var _prepare_generation: int = 0
var _inflight_prepare_generation: int = 0
var _inflight_prepare_preview_id: String = ""
var _cancelled_prepare_tombstones: Dictionary = {}
var _current_view: Dictionary = {}
var _action_mode: String = "move"
var _tutorial_panel_width: float = 0.0
var _tutorial_step: Dictionary = {}


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_board_viewport.point_activated.connect(handle_board_point)
	_board_viewport.cancel_or_marker_requested.connect(_on_cancel_or_marker_requested)
	_marker_menu.marker_selected.connect(_on_marker_selected)
	_status_button.pressed.connect(_on_status_button_pressed)
	_return_button.pressed.connect(func() -> void: return_requested.emit())
	_mirror_button.pressed.connect(_toggle_mirror_view)
	_cancel_button.pressed.connect(_cancel_only)
	_confirm_button.pressed.connect(confirm_prepared_action)
	_action_cancel_button.pressed.connect(_cancel_only)
	_action_confirm_button.pressed.connect(confirm_prepared_action)
	_move_button.pressed.connect(_set_action_mode.bind("move"))
	_bombard_button.pressed.connect(_set_action_mode.bind("bombard"))
	_resurrect_button.pressed.connect(_set_action_mode.bind("resurrect"))
	_pass_button.pressed.connect(_prepare_pass)
	call_deferred("apply_layout_for_size", size)


func _toggle_mirror_view() -> void:
	_board_viewport.toggle_presentation_side()
	_update_mirror_button()


func _update_mirror_button() -> void:
	if not is_instance_valid(_mirror_button):
		return
	_mirror_button.text = "切回红方视角" if _board_viewport.get_presentation_side() == "black" else "切换黑方镜像"


func set_tutorial_navigation_enabled(enabled: bool) -> void:
	_return_button.visible = enabled
	_return_button.text = "退出教学"


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


func set_tutorial_panel_width(panel_width: float) -> void:
	_tutorial_panel_width = maxf(0.0, panel_width)
	_safe_margin.offset_right = -16.0 - _tutorial_panel_width
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
	var target := BoardCoordinateMapper.coordinate_from_variant(step.get("target", []))
	_board_viewport.set_tutorial_target(target)


func render_player_view(view: Dictionary) -> void:
	_current_view = view.duplicate(true)
	_presentation_model = _presenter.player_view_model(view)
	_turn_label.text = str(_presentation_model.get("turn_text", "行动方：--"))
	_round_label.text = str(_presentation_model.get("round_text", "回合：-- / 50"))
	_wall_status.text = str(_presentation_model.get("wall_text", "城墙：--"))
	_flag_status.text = str(_presentation_model.get("flag_text", "旗帜：--"))
	_casualty_status.text = str(_presentation_model.get("casualty_text", "阵亡：--"))
	_board_viewport.render_player_view(view)
	_update_mirror_button()
	_update_status_controls()


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
	if _interaction_state in [PREVIEW_SELECTED, CONFIRMING]:
		_cancel_prepared_action_locally()
		return "cancel_prepared_action"
	if _interaction_state == SELECTED:
		_clear_local_interaction()
		selection_cancelled.emit()
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
	if str(_tutorial_step.get("type", "")) == "annotate":
		var target := BoardCoordinateMapper.coordinate_from_variant(_tutorial_step.get("target", []))
		if cell != target or marker_type != str(_tutorial_step.get("marker", "")):
			_reject_tutorial_input("标记位置或类型与当前目标不一致。")
			return
	_board_viewport.set_marker(cell, marker_type)
	_marker_menu.hide()
	_interaction_state = IDLE
	marker_applied.emit(cell, marker_type)


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
	var confirmation_button_min_height: float = minf(
		_action_cancel_button.custom_minimum_size.y,
		_action_confirm_button.custom_minimum_size.y
	)
	return {
		"compact": _compact,
		"screen_size": size,
		"board_rect": board_rect,
		"point_spacing": _board_viewport.get_point_spacing(),
		"main_buttons_inside": main_buttons_inside,
		"main_button_min_height": minimum_button_height,
		"confirmation_panel_inside": _control_inside_screen(_confirmation_panel),
		"confirmation_prompt_inside": _control_inside_screen(_action_prompt),
		"confirmation_buttons_inside": _control_inside_screen(_action_cancel_button) \
			and _control_inside_screen(_action_confirm_button),
		"confirmation_button_min_height": confirmation_button_min_height,
		"confirmation_prompt_text": _action_prompt.text,
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
	}


func get_player_view_snapshot() -> Dictionary:
	return _current_view.duplicate(true)


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
	_inflight_prepare_generation = 0
	_inflight_prepare_preview_id = ""
	_confirmation_panel.visible = false
	_board_viewport.clear_interaction()
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


func _can_submit_action() -> bool:
	return not _current_view.is_empty() \
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
	_clear_local_interaction()
	_message_value.text = {
		"move": "普通移动：选择己方棋子和目标交点。",
		"bombard": "区域炮击：先选择大本营内仍有弹药的己方炮。",
		"resurrect": "献祭复活：选择一枚在场己方士。",
	}.get(mode, "请选择行动。")
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
	_selection_status.text = "行动方：%s · 已选：%s" % [
		str(_current_view.get("active_side", "--")),
		_selected_piece_id if not _selected_piece_id.is_empty() else "无",
	]
	_mode_status.text = "模式：%s" % {
		"move": "普通移动",
		"bombard": "区域炮击",
		"resurrect": "献祭复活",
	}.get(_action_mode, _action_mode)
	var disabled := not _can_submit_action()
	_move_button.disabled = disabled
	_bombard_button.disabled = disabled
	_resurrect_button.disabled = disabled
	_pass_button.disabled = disabled


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
