extends Control

const BOARD_WIDTH: int = 9
const BOARD_HEIGHT: int = 24
const BOARD_CELL_COUNT: int = BOARD_WIDTH * BOARD_HEIGHT
const KNOWN_LEGAL: String = "KNOWN_LEGAL"
const TENTATIVE: String = "TENTATIVE"
const KNOWN_ILLEGAL: String = "KNOWN_ILLEGAL"

@export var initial_seed: int = 471001
@export var full_round_limit_hypothesis: int = 50

var board_state: Array[int] = []
var player_view: Dictionary = {}
var action_previews: Array = []
var selected_piece_id: String = ""
var selected_origin: Array = []
var pending_preview: Dictionary = {}
var action_mode: String = "move"
var cell_buttons: Dictionary = {}
var ai_difficulty_id: String = "medium"
var ai_turn_pending: bool = false

@onready var match_controller: Node = $MatchController
@onready var seed_value: Label = $SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/SeedGroup/SeedValue
@onready var seed_input: LineEdit = $SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/SeedGroup/SeedInput
@onready var side_value: Label = $SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/MatchMeta/HumanSideValue
@onready var active_value: Label = $SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/MatchMeta/ActiveSideValue
@onready var round_value: Label = $SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/MatchMeta/RoundValue
@onready var config_value: Label = $SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/MatchMeta/ConfigValue
@onready var difficulty_select: OptionButton = $SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/DifficultyGroup/DifficultySelect
@onready var board_grid: GridContainer = $SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/BoardScroll/BoardGrid
@onready var overview_strip: Label = $SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/OverviewStrip
@onready var confirm_panel: PanelContainer = $SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/ActionConfirm
@onready var confirm_summary: Label = $SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/ActionConfirm/ConfirmMargin/ConfirmColumn/ConfirmSummary
@onready var confirm_warning: Label = $SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/ActionConfirm/ConfirmMargin/ConfirmColumn/ConfirmWarning
@onready var confirm_button: Button = $SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/ActionConfirm/ConfirmMargin/ConfirmColumn/ConfirmButtons/ConfirmButton
@onready var cancel_button: Button = $SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/ActionConfirm/ConfirmMargin/ConfirmColumn/ConfirmButtons/CancelButton
@onready var turn_selection: Label = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/TurnAndSelection
@onready var wall_status: Label = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/WallStatus
@onready var flag_status: Label = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/FlagStatus
@onready var piece_status: Label = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/PieceStatus
@onready var mode_status: Label = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/ModeStatus
@onready var message_value: Label = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/MessageValue
@onready var move_button: Button = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/ActionMode/MoveButton
@onready var bombard_button: Button = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/ActionMode/BombardButton
@onready var pass_button: Button = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/ActionMode/PassButton
@onready var ai_step_button: Button = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/ActionMode/AiStepButton
@onready var red_casualties: Label = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/CasualtyGrid/RedCasualties
@onready var black_casualties: Label = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/CasualtyGrid/BlackCasualties
@onready var event_log: RichTextLabel = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/EventLog
@onready var terminal_overlay: CenterContainer = $TerminalOverlay
@onready var terminal_value: Label = $TerminalOverlay/TerminalPanel/TerminalMargin/TerminalColumn/TerminalValue
@onready var ai_turn_timer: Timer = $AiTurnTimer


func _ready() -> void:
	board_state.resize(BOARD_CELL_COUNT)
	board_state.fill(0)
	_register_cell_buttons()
	_connect_controls()
	seed_input.text = str(initial_seed)
	match_controller.initialize(initial_seed, full_round_limit_hypothesis, ai_difficulty_id)
	print("GATE1_PLAYTEST_GRAYBOX_READY seed=%d cells=%d round_limit=%d status=hypothesis_cli_overridable" % [
		initial_seed, board_state.size(), full_round_limit_hypothesis,
	])


func _unhandled_input(event: InputEvent) -> void:
	var right_click := event as InputEventMouseButton
	if event.is_action_pressed("ui_cancel") \
	or (right_click != null and right_click.button_index == MOUSE_BUTTON_RIGHT and right_click.pressed):
		_clear_selection()
		message_value.text = "已取消选择。左键可重新选择己方棋子。"
		get_viewport().set_input_as_handled()


func get_board_cell_count() -> int:
	return cell_buttons.size()


func get_initial_seed() -> int:
	return initial_seed


func get_player_view_snapshot() -> Dictionary:
	return player_view.duplicate(true)


func get_action_preview_snapshot() -> Array:
	return action_previews.duplicate(true)


func select_cell_for_test(cell: Array) -> void:
	_on_board_cell_pressed(int(cell[0]), int(cell[1]))


func confirm_action_for_test() -> Dictionary:
	return _submit_pending_action()


func choose_pass_for_test() -> void:
	_on_pass_pressed()


func step_ai_for_test() -> Dictionary:
	return match_controller.step_ai()


func restart_match_for_test(seed_override: int = 0) -> void:
	var seed_to_use: int = int(player_view.get("match_seed", initial_seed)) if seed_override == 0 else seed_override
	_start_match(seed_to_use)


func set_ai_difficulty_for_test(difficulty_id: String) -> void:
	var index: int = ["easy", "medium", "hard", "expert"].find(difficulty_id)
	if index < 0:
		return
	difficulty_select.select(index)
	_apply_ai_difficulty(difficulty_id)


func get_ai_difficulty_snapshot() -> Dictionary:
	return match_controller.get_ai_difficulty_snapshot()


func _register_cell_buttons() -> void:
	for button_value: Variant in board_grid.get_children():
		var button := button_value as Button
		if button == null:
			continue
		var x: int = int(button.get_meta("board_x"))
		var y: int = int(button.get_meta("board_y"))
		button.custom_minimum_size = Vector2(48.0, 48.0)
		cell_buttons[_cell_key(x, y)] = button
		button.pressed.connect(_on_board_cell_pressed.bind(x, y))
		button.gui_input.connect(_on_board_cell_gui_input.bind(button))


func _connect_controls() -> void:
	confirm_button.pressed.connect(_submit_pending_action)
	cancel_button.pressed.connect(_clear_selection)
	move_button.pressed.connect(_set_action_mode.bind("move"))
	bombard_button.pressed.connect(_set_action_mode.bind("bombard"))
	pass_button.pressed.connect(_on_pass_pressed)
	ai_step_button.pressed.connect(_on_ai_step_pressed)
	ai_turn_timer.timeout.connect(_on_ai_turn_timer_timeout)
	difficulty_select.item_selected.connect(_on_ai_difficulty_selected)
	$SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/SeedGroup/RestartButton.pressed.connect(_on_restart_pressed)
	$TerminalOverlay/TerminalPanel/TerminalMargin/TerminalColumn/TerminalButtons/SameSeedButton.pressed.connect(_restart_same_seed)
	$TerminalOverlay/TerminalPanel/TerminalMargin/TerminalColumn/TerminalButtons/NewSeedButton.pressed.connect(_on_restart_pressed)


func _on_match_controller_human_view_updated(updated_view: Dictionary) -> void:
	var previous_view: Dictionary = player_view.duplicate(true)
	player_view = updated_view.duplicate(true)
	action_previews = match_controller.get_human_action_previews()
	_clear_selection(false)
	_refresh_all()
	_refresh_notifications(previous_view, player_view)
	_schedule_ai_turn()


func _on_board_cell_gui_input(event: InputEvent, button: Button) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return
	_clear_selection()
	message_value.text = "已取消选择。左键可重新选择己方棋子。"
	button.accept_event()


func _on_board_cell_pressed(x: int, y: int) -> void:
	if not match_controller.can_human_submit():
		message_value.text = "当前不是人类行动阶段；可查看公开信息或执行 AI 单步。"
		return
	var cell: Array = [x, y]
	var own_piece: Dictionary = _own_piece_at(cell)
	if not selected_piece_id.is_empty():
		var preview: Dictionary = _preview_for_target(cell)
		if not preview.is_empty():
			if preview["classification"] == KNOWN_ILLEGAL:
				message_value.text = "该几何候选公开判定为不可提交。"
				return
			_set_pending_preview(preview)
			return
	if not own_piece.is_empty():
		_select_piece(own_piece)
	else:
		message_value.text = "先选择一枚己方在场棋子。"


func _select_piece(piece: Dictionary) -> void:
	selected_piece_id = str(piece["id"])
	selected_origin = piece["position"].duplicate()
	pending_preview = {}
	action_mode = "move"
	message_value.text = "已选择 %s；绿色为已知合法，黄色为受迷雾影响。" % selected_piece_id
	_refresh_all()


func _set_action_mode(mode: String) -> void:
	if mode == "bombard" and not _selected_has_bombardment():
		message_value.text = "当前所选炮不满足公开炮击条件。"
		return
	action_mode = mode
	pending_preview = {}
	_refresh_all()


func _on_pass_pressed() -> void:
	if not match_controller.can_human_submit():
		message_value.text = "当前不能跳过。"
		return
	for preview: Dictionary in action_previews:
		if preview["action_type"] == "pass":
			_set_pending_preview(preview)
			return


func _set_pending_preview(preview: Dictionary) -> void:
	pending_preview = preview.duplicate(true)
	var target_text: String = "—"
	if preview["target_cell"].size() == 2:
		target_text = "(%d,%d)" % [preview["target_cell"][0], preview["target_cell"][1]]
	confirm_summary.text = "%s · %s · 目标 %s · %s" % [
		str(preview["piece_id"]) if not str(preview["piece_id"]).is_empty() else "主动跳过",
		str(preview["action_type"]), target_text, str(preview["classification"]),
	]
	if preview["action_type"] == "pass":
		confirm_warning.text = "跳过会消耗本次行动，并推进墙、旗与完整轮结算。"
	elif preview["classification"] == TENTATIVE:
		confirm_warning.text = "该行动受迷雾信息影响，提交后可能失败并消耗本次行动。"
	elif preview["action_type"] == "bombard":
		confirm_warning.text = "将消耗 1 发弹药；命中格由规则结算，界面不预演。"
	else:
		confirm_warning.text = "确认后提交本次公开行动。"
	confirm_panel.visible = true
	_refresh_board()


func _submit_pending_action() -> Dictionary:
	if pending_preview.is_empty():
		return {"ok": false, "consumed": false, "error": "no_pending_preview"}
	var intent: Dictionary = {
		"piece_id": str(pending_preview["piece_id"]),
		"action_type": str(pending_preview["action_type"]),
		"target_cell": pending_preview["target_cell"].duplicate(),
		"skill_type": str(pending_preview["skill_type"]),
	}
	confirm_button.disabled = true
	var result: Dictionary = match_controller.submit_human_intent(intent)
	confirm_button.disabled = false
	if not bool(result.get("consumed", false)):
		message_value.text = "行动未提交：%s" % str(result.get("error", "unknown"))
	return result


func _on_ai_step_pressed() -> void:
	_perform_ai_turn()


func _on_ai_turn_timer_timeout() -> void:
	_perform_ai_turn()


func _schedule_ai_turn() -> void:
	if not match_controller.can_step_ai():
		ai_turn_pending = false
		ai_turn_timer.stop()
		return
	if ai_turn_pending:
		return
	ai_turn_pending = true
	message_value.text = "AI 正在思考，将自动行动……"
	ai_turn_timer.start()


func _perform_ai_turn() -> void:
	ai_turn_pending = false
	if not match_controller.can_step_ai():
		return
	ai_step_button.disabled = true
	message_value.text = "AI 行动中（仅使用 AI PlayerView）……"
	var result: Dictionary = match_controller.step_ai()
	ai_step_button.disabled = false
	if not bool(result.get("consumed", false)):
		message_value.text = "AI 行动失败：%s" % str(result.get("error", "unknown"))


func _on_restart_pressed() -> void:
	var raw_seed: String = seed_input.text.strip_edges()
	if not raw_seed.is_valid_int():
		message_value.text = "种子必须是整数。"
		return
	_start_match(int(raw_seed))


func _on_ai_difficulty_selected(index: int) -> void:
	var ids: Array[String] = ["easy", "medium", "hard", "expert"]
	if index < 0 or index >= ids.size():
		return
	_apply_ai_difficulty(ids[index])


func _apply_ai_difficulty(difficulty_id: String) -> void:
	ai_difficulty_id = difficulty_id
	message_value.text = "AI 难度已切换为%s；按当前种子重新开局。" % _difficulty_name(difficulty_id)
	_start_match(int(player_view.get("match_seed", initial_seed)))


func _restart_same_seed() -> void:
	_start_match(int(player_view.get("match_seed", initial_seed)))


func _start_match(seed_to_use: int) -> void:
	initial_seed = seed_to_use
	seed_input.text = str(seed_to_use)
	ai_turn_pending = false
	ai_turn_timer.stop()
	selected_piece_id = ""
	selected_origin = []
	pending_preview = {}
	action_mode = "move"
	match_controller.initialize(seed_to_use, full_round_limit_hypothesis, ai_difficulty_id)


func _clear_selection(refresh: bool = true) -> void:
	selected_piece_id = ""
	selected_origin = []
	pending_preview = {}
	action_mode = "move"
	if is_instance_valid(confirm_panel):
		confirm_panel.visible = false
	if refresh and not player_view.is_empty():
		_refresh_all()


func _refresh_all() -> void:
	if player_view.is_empty():
		return
	seed_value.text = str(player_view["match_seed"])
	side_value.text = "玩家：%s" % _side_name(str(player_view["viewer_side"]))
	active_value.text = "行动方：%s" % _side_name(str(player_view["active_side"]))
	round_value.text = "完整轮：%d / %d" % [player_view["full_round_index"], player_view["full_round_limit_hypothesis"]]
	config_value.text = "规则 %s · %s 回合 · AI %s" % [
		str(player_view["implementation_revision"]).trim_prefix("prototype-core-"),
		str(player_view["full_round_limit_hypothesis"]),
		_difficulty_name(ai_difficulty_id),
	]
	_refresh_board()
	_refresh_status()
	_refresh_terminal()


func _refresh_board() -> void:
	var visible_set: Dictionary = _coordinate_set(player_view.get("visible_cells", []))
	var detection_set: Dictionary = _coordinate_set(player_view.get("hidden_detection_cells", []))
	var contact_set: Dictionary = {}
	for contact: Dictionary in player_view.get("contact_intel", []):
		if contact.get("cell", []).size() == 2:
			contact_set[_cell_key(int(contact["cell"][0]), int(contact["cell"][1]))] = true
	var pieces_by_cell: Dictionary = {}
	for piece: Dictionary in player_view.get("pieces", []):
		if piece.get("position", []).size() == 2:
			pieces_by_cell[_cell_key(int(piece["position"][0]), int(piece["position"][1]))] = piece
	var flags_by_cell: Dictionary = {}
	for flag: Dictionary in player_view.get("flags", []):
		flags_by_cell[_cell_key(int(flag["position"][0]), int(flag["position"][1]))] = flag
	var preview_by_cell: Dictionary = {}
	if not selected_piece_id.is_empty():
		for preview: Dictionary in action_previews:
			if str(preview["piece_id"]) == selected_piece_id 			and str(preview["action_type"]) == action_mode 			and preview["target_cell"].size() == 2:
				preview_by_cell[_cell_key(int(preview["target_cell"][0]), int(preview["target_cell"][1]))] = preview
	for key: String in cell_buttons.keys():
		var button: Button = cell_buttons[key]
		var x: int = int(button.get_meta("board_x"))
		var y: int = int(button.get_meta("board_y"))
		var lines: Array[String] = ["%d,%d" % [x, y]]
		var tooltip_lines: Array[String] = ["坐标 (%d,%d) · %s" % [x, y, _region_name(y)]]
		button.theme_type_variation = StringName(_region_theme(y))
		var color := Color(0.58, 0.61, 0.65, 1.0)
		if visible_set.has(key):
			color = Color.WHITE
		if detection_set.has(key):
			color = Color(0.62, 0.92, 0.95, 1.0)
			tooltip_lines.append("象眼侦测范围")
		if contact_set.has(key):
			lines = ["敌?"]
			color = Color(1.0, 0.62, 0.28, 1.0)
			tooltip_lines.append("未知敌情接触")
		if flags_by_cell.has(key):
			var flag: Dictionary = flags_by_cell[key]
			lines = ["旗%d" % int(flag["capture_progress"])]
			button.theme_type_variation = &"FlagCell"
			tooltip_lines.append("旗帜：%s · 占领进度 %d/3" % [
				_owner_mark(str(flag["owner"])), int(flag["capture_progress"]),
			])
		if pieces_by_cell.has(key):
			var piece: Dictionary = pieces_by_cell[key]
			var piece_side: String = str(piece["side"])
			lines = [_piece_mark(str(piece["piece_type"]), piece_side)]
			button.theme_type_variation = &"RedPiece" if piece_side == "red" else &"BlackPiece"
			color = Color.WHITE
			tooltip_lines.append("%s%s%s" % [
				_side_name(piece_side), _piece_mark(str(piece["piece_type"]), piece_side),
				" · 隐匿" if piece.get("status_tags", []).has("hidden") else "",
			])
		if preview_by_cell.has(key):
			var preview: Dictionary = preview_by_cell[key]
			match str(preview["classification"]):
				KNOWN_LEGAL:
					color = Color(0.48, 1.0, 0.55, 1.0)
					tooltip_lines.append("已知合法落点")
				TENTATIVE:
					color = Color(1.0, 0.82, 0.28, 1.0)
					tooltip_lines.append("迷雾影响：结果未知")
				KNOWN_ILLEGAL:
					color = Color(0.42, 0.42, 0.45, 1.0)
		if selected_origin.size() == 2 and x == int(selected_origin[0]) and y == int(selected_origin[1]):
			var selected_piece: Dictionary = pieces_by_cell.get(key, {})
			if not selected_piece.is_empty():
				button.theme_type_variation = &"RedPieceSelected" \
					if str(selected_piece["side"]) == "red" else &"BlackPieceSelected"
			color = Color.WHITE
			tooltip_lines.append("当前选中；右键取消")
		button.text = "\n".join(lines)
		button.tooltip_text = "\n".join(tooltip_lines)
		button.self_modulate = color
		button.disabled = not match_controller.can_human_submit()
	overview_strip.text = "红方区域 1–8 · 中央战场 9–16 · 黑方区域 17–24 | 可见 %d/%d · 接触 %d · 侦测 %d" % [
		visible_set.size(), BOARD_CELL_COUNT, contact_set.size(), detection_set.size(),
	]


func _refresh_status() -> void:
	turn_selection.text = "行动 %d · %s · 选择：%s" % [
		int(player_view["action_index"]), _side_name(str(player_view["active_side"])),
		selected_piece_id if not selected_piece_id.is_empty() else "无",
	]
	var wall_lines: Array[String] = []
	for wall: Dictionary in player_view.get("walls", []):
		wall_lines.append("%s墙：%s" % [_side_name(str(wall["side"])), str(wall["status"])])
	wall_status.text = "\n".join(wall_lines)
	var flag_lines: Array[String] = []
	for flag: Dictionary in player_view.get("flags", []):
		flag_lines.append("%s (%d,%d)：%s %d/3%s" % [
			str(flag["id"]), int(flag["position"][0]), int(flag["position"][1]),
			_owner_mark(str(flag["owner"])), int(flag["capture_progress"]),
			" 争夺中" if bool(flag["contested"]) else "",
		])
	flag_status.text = "\n".join(flag_lines)
	var selected: Dictionary = _piece_by_id(selected_piece_id)
	if selected.is_empty():
		piece_status.text = "棋子：请选择己方在场棋子"
	else:
		piece_status.text = "棋子：%s · %s%s" % [
			selected_piece_id, _piece_mark(str(selected["piece_type"]), str(selected["side"])),
			" · 弹药 %d" % int(selected.get("bombard_ammo", 0)) if selected["piece_type"] == "cannon" else "",
		]
	mode_status.text = "模式：%s · 左键操作 / 右键取消" % ("区域炮击" if action_mode == "bombard" else "普通移动")
	move_button.disabled = not match_controller.can_human_submit()
	bombard_button.disabled = not match_controller.can_human_submit() or not _selected_has_bombardment()
	pass_button.disabled = not match_controller.can_human_submit()
	ai_step_button.disabled = not match_controller.can_step_ai()
	var casualty_counts: Dictionary = _casualty_counts_from_events()
	red_casualties.text = "红方：%s" % _format_casualties("red", casualty_counts["red"])
	black_casualties.text = "黑方：%s" % _format_casualties("black", casualty_counts["black"])
	var event_lines: Array[String] = []
	for event: Dictionary in player_view.get("player_events", []):
		event_lines.append("[%s] %s" % [str(event.get("id", "")), _event_summary(event)])
	event_log.text = "\n".join(event_lines) if not event_lines.is_empty() else "尚无玩家可见事件。"


func _refresh_notifications(previous_view: Dictionary, current_view: Dictionary) -> void:
	if int(current_view.get("action_index", 0)) == 0:
		message_value.text = "对局开始：左键选择己方圆形棋子，右键取消选择。"
		return
	var notifications: Array[String] = []
	var previous_event_ids: Dictionary = {}
	for event: Dictionary in previous_view.get("player_events", []):
		previous_event_ids[str(event.get("id", ""))] = true
	for event: Dictionary in current_view.get("player_events", []):
		if previous_event_ids.has(str(event.get("id", ""))):
			continue
		var capture_summary: String = _event_capture_summary(event)
		if not capture_summary.is_empty():
			notifications.append(capture_summary)
	var previous_walls: Dictionary = _wall_status_by_side(previous_view)
	for wall: Dictionary in current_view.get("walls", []):
		var wall_side: String = str(wall.get("side", ""))
		var new_status: String = str(wall.get("status", ""))
		var old_status: String = str(previous_walls.get(wall_side, new_status))
		if new_status == old_status:
			continue
		match new_status:
			"INTACT": notifications.append("%s城墙恢复完成" % _side_name(wall_side))
			"BREACHED": notifications.append("%s城墙已被攻破" % _side_name(wall_side))
			"REPAIRING": notifications.append("%s城墙开始恢复" % _side_name(wall_side))
	var previous_flags: Dictionary = _flag_owner_by_id(previous_view)
	for flag: Dictionary in current_view.get("flags", []):
		var flag_id: String = str(flag.get("id", ""))
		var new_owner: String = str(flag.get("owner", "neutral"))
		var old_owner: String = str(previous_flags.get(flag_id, new_owner))
		if new_owner != old_owner and new_owner != "neutral":
			notifications.append("%s占领%s成功" % [_side_name(new_owner), flag_id])
	if notifications.is_empty() and str(previous_view.get("active_side", "")) == "black" \
	and str(current_view.get("active_side", "")) == str(current_view.get("viewer_side", "")):
		notifications.append("AI 已行动，轮到你")
	if not notifications.is_empty():
		message_value.text = "提示：%s" % " · ".join(notifications)


func _event_summary(event: Dictionary) -> String:
	var actor_side: String = str(event.get("actor_side", ""))
	var code: String = str(event.get("public_code", event.get("event_type", "")))
	var action_text: String = {
		"move_resolved": "完成移动",
		"bombardment_resolved": "完成区域炮击",
		"pass": "主动跳过",
		"skip": "跳过行动",
		"timeout": "行动超时",
		"route_unknown_blocked": "路线受迷雾阻挡",
		"target_unknown_occupied": "目标格存在未知棋子",
		"cannon_path_invalid": "炮路受迷雾影响",
	}.get(code, code)
	var capture_summary: String = _event_capture_summary(event)
	if capture_summary.is_empty():
		return "%s%s" % [_side_name(actor_side), action_text]
	return "%s%s；%s" % [_side_name(actor_side), action_text, capture_summary]


func _event_capture_summary(event: Dictionary) -> String:
	var actor_side: String = str(event.get("actor_side", ""))
	var casualty_side: String = _opponent_side(actor_side)
	var parts: Array[String] = []
	for capture: Dictionary in event.get("authorized_captures", []):
		var captured_mark: String = _piece_mark(str(capture.get("piece_type", "")), casualty_side)
		if bool(capture.get("rescued", false)):
			parts.append("%s士替死，保住%s" % [_side_name(casualty_side), captured_mark])
		else:
			parts.append("%s吃掉%s%s" % [
				_side_name(actor_side), _side_name(casualty_side), captured_mark,
			])
	return "；".join(parts)


func _casualty_counts_from_events() -> Dictionary:
	var result: Dictionary = {"red": {}, "black": {}}
	for event: Dictionary in player_view.get("player_events", []):
		var casualty_side: String = _opponent_side(str(event.get("actor_side", "")))
		if not result.has(casualty_side):
			continue
		for capture: Dictionary in event.get("authorized_captures", []):
			var piece_type: String = "advisor" if bool(capture.get("rescued", false)) \
				else str(capture.get("piece_type", ""))
			result[casualty_side][piece_type] = int(result[casualty_side].get(piece_type, 0)) + 1
	return result


func _format_casualties(side: String, counts: Dictionary) -> String:
	var entries: Array[String] = []
	for piece_type: String in ["general", "advisor", "elephant", "horse", "rook", "cannon", "pawn"]:
		var count: int = int(counts.get(piece_type, 0))
		if count <= 0:
			continue
		entries.append("%s×%d" % [_piece_mark(piece_type, side), count])
	return "  ".join(entries) if not entries.is_empty() else "无"


func _wall_status_by_side(view: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for wall: Dictionary in view.get("walls", []):
		result[str(wall.get("side", ""))] = str(wall.get("status", ""))
	return result


func _flag_owner_by_id(view: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for flag: Dictionary in view.get("flags", []):
		result[str(flag.get("id", ""))] = str(flag.get("owner", "neutral"))
	return result


func _refresh_terminal() -> void:
	terminal_overlay.visible = bool(player_view["terminal"])
	if not terminal_overlay.visible:
		return
	var owned: Dictionary = {"red": 0, "black": 0}
	for flag: Dictionary in player_view.get("flags", []):
		if owned.has(flag["owner"]):
			owned[flag["owner"]] = int(owned[flag["owner"]]) + 1
	terminal_value.text = "对局结束\n胜者：%s\n胜因：%s\n完整轮：%d\n公开旗数：红 %d / 黑 %d" % [
		_side_name(str(player_view["winner"])), str(player_view["win_reason"]),
		int(player_view["full_round_index"]), owned["red"], owned["black"],
	]


func _preview_for_target(cell: Array) -> Dictionary:
	for preview: Dictionary in action_previews:
		if str(preview["piece_id"]) == selected_piece_id 		and str(preview["action_type"]) == action_mode 		and preview["target_cell"] == cell:
			return preview.duplicate(true)
	return {}


func _selected_has_bombardment() -> bool:
	if selected_piece_id.is_empty():
		return false
	for preview: Dictionary in action_previews:
		if str(preview["piece_id"]) == selected_piece_id 		and str(preview["action_type"]) == "bombard" 		and str(preview["classification"]) != KNOWN_ILLEGAL:
			return true
	return false


func _own_piece_at(cell: Array) -> Dictionary:
	for piece: Dictionary in player_view.get("pieces", []):
		if piece["side"] == player_view["viewer_side"] and piece["position"] == cell 		and bool(piece["alive"]) and not bool(piece["in_reserve"]):
			return piece
	return {}


func _piece_by_id(piece_id: String) -> Dictionary:
	for piece: Dictionary in player_view.get("pieces", []):
		if str(piece["id"]) == piece_id:
			return piece
	return {}


func _coordinate_set(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for cell: Array in cells:
		if cell.size() == 2:
			result[_cell_key(int(cell[0]), int(cell[1]))] = true
	return result


func _cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func _side_name(side: String) -> String:
	match side:
		"red": return "红方"
		"black": return "黑方"
		"draw": return "平局"
	return side if not side.is_empty() else "—"


func _side_mark(side: String) -> String:
	return "红" if side == "red" else "黑"


func _opponent_side(side: String) -> String:
	return "black" if side == "red" else "red"


func _owner_mark(owner: String) -> String:
	if owner == "neutral":
		return "中立"
	return _side_name(owner)


func _piece_mark(piece_type: String, side: String = "") -> String:
	if side == "red":
		return {
			"rook": "车", "horse": "马", "elephant": "相", "advisor": "仕",
			"general": "帅", "cannon": "炮", "pawn": "兵",
		}.get(piece_type, "?")
	if side == "black":
		return {
			"rook": "车", "horse": "马", "elephant": "象", "advisor": "士",
			"general": "将", "cannon": "炮", "pawn": "卒",
		}.get(piece_type, "?")
	return {
		"rook": "车", "horse": "马", "elephant": "象", "advisor": "士",
		"general": "将", "cannon": "炮", "pawn": "兵",
	}.get(piece_type, "?")


func _region_theme(y: int) -> String:
	if y <= 8:
		return "RedZoneCell"
	if y <= 16:
		return "BattlefieldCell"
	return "BlackZoneCell"


func _region_name(y: int) -> String:
	if y <= 8:
		return "红方区域"
	if y <= 16:
		return "中央战场"
	return "黑方区域"


func _difficulty_name(difficulty_id: String) -> String:
	return {"easy": "简单", "medium": "中等", "hard": "困难", "expert": "专家"}.get(difficulty_id, difficulty_id)
