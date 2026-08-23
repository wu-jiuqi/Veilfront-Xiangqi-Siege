extends Control

const FORMAL_MATCH_STATE = preload("res://scripts/game/domain/match_state.gd")
const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

const TYPE_NAMES := {
	"general": "将",
	"guard": "士",
	"advisor": "士",
	"minister": "相",
	"elephant": "相",
	"cavalry": "骑",
	"horse": "骑",
	"chariot": "车",
	"rook": "车",
	"trebuchet": "炮",
	"cannon": "炮",
	"infantry": "兵",
	"soldier": "兵",
	"pawn": "兵",
}

const TYPE_ROLES := {
	"general": "主将 · 九宫核心单位",
	"guard": "近卫 · 九宫防守单位",
	"advisor": "近卫 · 九宫防守单位",
	"minister": "斥候 · 区域侦察单位",
	"elephant": "斥候 · 区域侦察单位",
	"cavalry": "骑军 · 机动突袭单位",
	"horse": "骑军 · 机动突袭单位",
	"chariot": "战车 · 直线压制单位",
	"rook": "战车 · 直线压制单位",
	"trebuchet": "砲军 · 远程攻城单位",
	"cannon": "砲军 · 远程攻城单位",
	"infantry": "步卒 · 基础近战单位",
	"soldier": "步卒 · 基础近战单位",
	"pawn": "步卒 · 基础近战单位",
}

const TYPE_INTROS := {
	"general": "稳守九宫，维持全军指挥。",
	"guard": "守护主将，并可触发献祭能力。",
	"advisor": "守护主将，并可触发献祭能力。",
	"minister": "跨越区域并揭示战场情报。",
	"elephant": "跨越区域并揭示战场情报。",
	"cavalry": "绕开正面阵线，切入关键交点。",
	"horse": "绕开正面阵线，切入关键交点。",
	"chariot": "沿直线推进，控制长距离通道。",
	"rook": "沿直线推进，控制长距离通道。",
	"trebuchet": "隔子攻击，并可发动区域轰炸。",
	"cannon": "隔子攻击，并可发动区域轰炸。",
	"infantry": "擅长推进与占领旗点。",
	"soldier": "擅长推进与占领旗点。",
	"pawn": "擅长推进与占领旗点。",
}

const MOVE_RULES := {
	"general": "仅在九宫内横向或纵向移动一格。",
	"guard": "仅在九宫内沿斜线移动一格。",
	"advisor": "仅在九宫内沿斜线移动一格。",
	"minister": "沿对角移动两格；象眼受阻时不可通过。",
	"elephant": "沿对角移动两格；象眼受阻时不可通过。",
	"cavalry": "按日字移动；起步方向受阻时不可通过。",
	"horse": "按日字移动；起步方向受阻时不可通过。",
	"chariot": "沿横线或纵线直行；不能越过其他棋子。",
	"rook": "沿横线或纵线直行；不能越过其他棋子。",
	"trebuchet": "沿直线移动；吃子时必须隔一枚棋子。",
	"cannon": "沿直线移动；吃子时必须隔一枚棋子。",
	"infantry": "通常向前一格或横移一格；不能越子。",
	"soldier": "通常向前一格或横移一格；不能越子。",
	"pawn": "通常向前一格或横移一格；不能越子。",
}

const SKILL_RULES := {
	"guard": "士献祭：消耗本回合行动，复活符合条件的己方棋子。",
	"advisor": "士献祭：消耗本回合行动，复活符合条件的己方棋子。",
	"trebuchet": "区域轰炸：选择合法区域，对公开目标实施炮击。",
	"cannon": "区域轰炸：选择合法区域，对公开目标实施炮击。",
	"infantry": "土献祭：消耗本回合行动，强化目标旗点。",
	"soldier": "土献祭：消耗本回合行动，强化目标旗点。",
	"pawn": "土献祭：消耗本回合行动，强化目标旗点。",
}

const ART_TYPE_ALIASES := {
	"advisor": "guard",
	"elephant": "minister",
	"horse": "cavalry",
	"rook": "chariot",
	"cannon": "trebuchet",
	"soldier": "infantry",
	"pawn": "infantry",
}

@export var board_theme: BoardTheme
@export var map_option: BoardMapOption

@onready var _board_viewport: SubViewportContainer = %BoardViewport
@onready var _minimap: TacticalMinimap = %TacticalMinimap
@onready var _round_label: Label = %Round
@onready var _side_label: Label = %Side
@onready var _timer_label: Label = %Timer
@onready var _red_captured: Label = %RedCaptured
@onready var _red_lost: Label = %RedLost
@onready var _red_capturing: Label = %RedCapturing
@onready var _black_captured: Label = %BlackCaptured
@onready var _black_lost: Label = %BlackLost
@onready var _black_capturing: Label = %BlackCapturing
@onready var _unit_name: Label = %UnitName
@onready var _unit_portrait: TextureRect = %UnitPortrait
@onready var _unit_role: Label = %UnitRole
@onready var _unit_intro: Label = %UnitIntro
@onready var _flag_event: Label = %FlagEvent
@onready var _own_loss_event: Label = %OwnLossEvent
@onready var _enemy_loss_event: Label = %EnemyLossEvent
@onready var _coordinate_event: Label = %CoordinateEvent
@onready var _status_event: Label = %StatusEvent
@onready var _action_rule: Label = %ActionRule
@onready var _skill_description: Label = %SkillDescription
@onready var _move_button: Button = %MoveButton
@onready var _skill_button: Button = %SkillButton
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _countdown_timer: Timer = $CountdownTimer

var _player_view: Dictionary = {}
var _selected_piece: Dictionary = {}
var _selected_cell := Vector2i.ZERO
var _active_mode: String = "move"
var _seconds_remaining: int = 72
var _demo_capture_progress: int = 0


func _ready() -> void:
	_board_viewport.set_presentation_assets(board_theme, map_option)
	_board_viewport.point_activated.connect(_on_point_activated)
	_board_viewport.hovered_cell_changed.connect(_on_hovered_cell_changed)
	_board_viewport.overview_changed.connect(_minimap.set_overview_state)
	_minimap.overview_navigation_requested.connect(_board_viewport.navigate_to_overview_ratio)
	_move_button.pressed.connect(func() -> void: _set_action_mode("move"))
	_skill_button.pressed.connect(func() -> void: _set_action_mode("skill"))
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_countdown_timer.timeout.connect(_on_countdown_timeout)
	_wire_focus_neighbors()
	_player_view = _build_player_view()
	_render_player_view()
	call_deferred("_select_initial_piece")


func get_lab_snapshot() -> Dictionary:
	return {
		"board": _board_viewport.get_render_snapshot(),
		"minimap": _minimap.get_state_snapshot(),
		"selected_piece_id": str(_selected_piece.get("id", "")),
		"selected_cell": _selected_cell,
		"action_mode": _active_mode,
		"seconds_remaining": _seconds_remaining,
		"round_text": _round_label.text,
		"timer_text": _timer_label.text,
		"red_summary": [_red_captured.text, _red_lost.text, _red_capturing.text],
		"black_summary": [_black_captured.text, _black_lost.text, _black_capturing.text],
		"event_rows": [
			_flag_event.text,
			_own_loss_event.text,
			_enemy_loss_event.text,
			_coordinate_event.text,
			_status_event.text,
		],
		"unit_has_numeric_stats": false,
		"action_button_count": 2,
		"action_buttons_vertical": _move_button.get_parent() is VBoxContainer,
		"uses_existing_board_viewport": true,
		"uses_existing_piece_art": _unit_portrait.texture != null \
			and _unit_portrait.texture.resource_path.begins_with(
				"res://assets/art/pieces/terracotta_warriors/"
			),
	}


func advance_demo_parameters() -> void:
	_on_confirm_pressed()
	_player_view["full_round_index"] = int(_player_view.get("full_round_index", 0)) + 1
	_seconds_remaining = 41
	var casualties: Array = _player_view.get("casualties", [])
	casualties.append({"side": "red", "piece_type": "infantry"})
	_sync_turn_status()
	_sync_faction_summaries()
	_sync_event_rows()


func _build_player_view() -> Dictionary:
	var visible_cells: Array = []
	for authority_y: int in range(1, 25):
		for authority_x: int in range(1, 10):
			visible_cells.append([authority_x, authority_y])
	var formal_state: Dictionary = FORMAL_MATCH_STATE.create(471001)
	var pieces: Array = []
	for piece_value: Variant in formal_state.get("pieces", {}).values():
		if piece_value is Dictionary:
			pieces.append((piece_value as Dictionary).duplicate(true))
	return {
		"match_id": "match-hud-v3-layout-lab",
		"action_index": 1,
		"viewer_side": "red",
		"active_side": "red",
		"full_round_index": 18,
		"round_limit_public": 50,
		"terminal": false,
		"board": {"width": 9, "height": 24},
		"visible_cells": visible_cells,
		"hidden_detection_cells": [],
		"pieces": pieces,
		"flags": [
			{
				"capture_progress": 3,
				"capturing_side": "",
				"contested": false,
				"discovered": true,
				"id": "lab-flag-owned-red",
				"owner": "red",
				"position": [5, 7],
			},
			{
				"capture_progress": _demo_capture_progress,
				"capturing_side": "red",
				"contested": false,
				"discovered": true,
				"id": "lab-flag-capturing",
				"owner": "",
				"position": [3, 12],
			},
			{
				"capture_progress": 0,
				"capturing_side": "",
				"contested": false,
				"discovered": false,
				"id": "lab-flag-hidden",
				"owner": "",
				"position": [7, 18],
			},
		],
		"walls": [
			{"side": "red", "status": "INTACT"},
			{"side": "black", "status": "INTACT"},
		],
		"casualties": [
			{"side": "red", "piece_type": "infantry"},
			{"side": "black", "piece_type": "trebuchet"},
		],
		"capture_ghosts": [],
		"vision_overlays": {
			"rook_paths": [],
			"elephant_reveal_zones": [],
			"elephant_block_fields": [],
		},
	}


func _render_player_view() -> void:
	_board_viewport.render_player_view(_player_view)
	_minimap.render_player_view(_player_view, "red")
	_sync_turn_status()
	_sync_faction_summaries()
	_sync_event_rows()


func _select_initial_piece() -> void:
	for piece_value: Variant in _player_view.get("pieces", []):
		if not piece_value is Dictionary:
			continue
		var piece: Dictionary = piece_value
		if str(piece.get("side", "")) == "red" \
		and str(piece.get("piece_type", "")) in ["infantry", "soldier", "pawn"]:
			_select_piece(piece)
			return


func _on_point_activated(cell: Vector2i) -> void:
	_coordinate_event.text = "当前坐标：(%d,%d)" % [cell.x, cell.y]
	var piece := _piece_at_cell(cell)
	if piece.is_empty():
		_status_event.text = "已选择交点，等待棋子行动"
		return
	_select_piece(piece)


func _on_hovered_cell_changed(cell: Vector2i) -> void:
	if Mapper.is_authority_cell_valid(cell):
		_status_event.text = "悬停坐标：(%d,%d)" % [cell.x, cell.y]
	elif _selected_piece.is_empty():
		_status_event.text = "选择棋子查看规则"


func _select_piece(piece: Dictionary) -> void:
	_selected_piece = piece.duplicate(true)
	_selected_cell = Mapper.coordinate_from_variant(_selected_piece.get("position", []))
	var piece_type := str(_selected_piece.get("piece_type", ""))
	_unit_name.text = str(TYPE_NAMES.get(piece_type, "棋子"))
	_unit_role.text = str(TYPE_ROLES.get(piece_type, "战场单位"))
	_unit_intro.text = str(TYPE_INTROS.get(piece_type, "该单位的定位说明尚未登记。"))
	_action_rule.text = str(MOVE_RULES.get(piece_type, "该棋子的行动规则尚未登记。"))
	var skill_text := str(SKILL_RULES.get(piece_type, "无主动技能；仍可执行基础移动。"))
	_skill_description.text = skill_text
	_skill_button.disabled = not SKILL_RULES.has(piece_type)
	_unit_portrait.texture = _load_piece_portrait(str(_selected_piece.get("side", "red")), piece_type)
	_coordinate_event.text = "当前坐标：(%d,%d)" % [_selected_cell.x, _selected_cell.y]
	_status_event.text = "已选择：%s" % _unit_name.text
	_set_action_mode("move")
	_show_selection_preview()


func _piece_at_cell(cell: Vector2i) -> Dictionary:
	for piece_value: Variant in _player_view.get("pieces", []):
		if not piece_value is Dictionary:
			continue
		var piece: Dictionary = piece_value
		if not bool(piece.get("alive", true)) or bool(piece.get("in_reserve", false)):
			continue
		if Mapper.coordinate_from_variant(piece.get("position", [])) == cell:
			return piece
	return {}


func _load_piece_portrait(side: String, piece_type: String) -> Texture2D:
	var art_type := str(ART_TYPE_ALIASES.get(piece_type, piece_type))
	var path := "res://assets/art/pieces/terracotta_warriors/%s_%s_idle.png" % [side, art_type]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _show_selection_preview() -> void:
	if not Mapper.is_authority_cell_valid(_selected_cell):
		_board_viewport.clear_interaction()
		return
	var target := Vector2i(_selected_cell.x, clampi(_selected_cell.y - 1, 1, 24))
	_board_viewport.set_interaction(_selected_cell, [{
		"preview_id": "hud-v3-lab-%s" % _active_mode,
		"piece_id": str(_selected_piece.get("id", "")),
		"action_type": _active_mode,
		"target_cell": [target.x, target.y],
		"classification": "KNOWN_LEGAL",
		"message_key": "HUD V3 布局预览",
	}])


func _set_action_mode(mode: String) -> void:
	_active_mode = mode if mode in ["move", "skill"] else "move"
	if _active_mode == "skill" and _skill_button.disabled:
		_active_mode = "move"
	_move_button.button_pressed = _active_mode == "move"
	_skill_button.button_pressed = _active_mode == "skill"
	_status_event.text = "行动模式：%s" % ("移动" if _active_mode == "move" else "技能")
	_show_selection_preview()


func _on_confirm_pressed() -> void:
	_demo_capture_progress += 1
	if _demo_capture_progress > 3:
		_demo_capture_progress = 0
	for flag_value: Variant in _player_view.get("flags", []):
		if flag_value is Dictionary and str(flag_value.get("id", "")) == "lab-flag-capturing":
			(flag_value as Dictionary)["capture_progress"] = _demo_capture_progress
			break
	_sync_faction_summaries()
	_status_event.text = "参数演示：占旗进度 %d/3" % _demo_capture_progress


func _on_cancel_pressed() -> void:
	_selected_piece.clear()
	_selected_cell = Vector2i.ZERO
	_board_viewport.clear_interaction()
	_unit_name.text = "未选择棋子"
	_unit_role.text = "选择棋盘上的己方棋子"
	_unit_intro.text = "此处只显示棋子身份与定位，不显示数值属性。"
	_unit_portrait.texture = null
	_action_rule.text = "选择棋子后显示其行动规则。"
	_skill_description.text = "选择棋子后显示其当前技能。"
	_skill_button.disabled = true
	_coordinate_event.text = "当前坐标：—"
	_status_event.text = "已取消当前选择"


func _on_countdown_timeout() -> void:
	_seconds_remaining -= 1
	if _seconds_remaining < 0:
		_seconds_remaining = 72
	_timer_label.text = "剩余 %d 秒" % _seconds_remaining


func _sync_turn_status() -> void:
	var round_index := int(_player_view.get("full_round_index", 0))
	var side := str(_player_view.get("active_side", "red"))
	_round_label.text = "第 %d 回合" % round_index
	_side_label.text = "%s方行动" % ("赤" if side == "red" else "玄")
	_timer_label.text = "剩余 %d 秒" % _seconds_remaining


func _sync_faction_summaries() -> void:
	var owned := {"red": 0, "black": 0}
	var capturing := {"red": 0, "black": 0}
	for flag_value: Variant in _player_view.get("flags", []):
		if not flag_value is Dictionary:
			continue
		var flag: Dictionary = flag_value
		var owner := str(flag.get("owner", ""))
		var capturing_side := str(flag.get("capturing_side", ""))
		if owner in owned:
			owned[owner] = int(owned.get(owner, 0)) + 1
		if capturing_side in capturing:
			capturing[capturing_side] = maxi(
				int(capturing.get(capturing_side, 0)), int(flag.get("capture_progress", 0))
			)
	var lost := {"red": 0, "black": 0}
	for casualty_value: Variant in _player_view.get("casualties", []):
		if casualty_value is Dictionary:
			var side := str(casualty_value.get("side", ""))
			if side in lost:
				lost[side] = int(lost.get(side, 0)) + 1
	_red_captured.text = "旗帜 %d/3" % int(owned["red"])
	_red_lost.text = "损失 %d" % int(lost["red"])
	_red_capturing.text = "占领 %d/3" % int(capturing["red"])
	_black_captured.text = "旗帜 %d/3" % int(owned["black"])
	_black_lost.text = "损失 %d" % int(lost["black"])
	_black_capturing.text = "占领 %d/3" % int(capturing["black"])


func _sync_event_rows() -> void:
	var discovered := 0
	for flag_value: Variant in _player_view.get("flags", []):
		if flag_value is Dictionary and bool(flag_value.get("discovered", false)):
			discovered += 1
	_flag_event.text = "我方已发现旗帜 %d/3" % discovered
	var viewer_side := str(_player_view.get("viewer_side", "red"))
	var enemy_side := "black" if viewer_side == "red" else "red"
	_own_loss_event.text = "我方阵亡：%s" % _format_casualties(viewer_side)
	_enemy_loss_event.text = "敌方阵亡：%s" % _format_casualties(enemy_side)
	if not Mapper.is_authority_cell_valid(_selected_cell):
		_coordinate_event.text = "当前坐标：—"


func _format_casualties(side: String) -> String:
	var counts: Dictionary = {}
	for casualty_value: Variant in _player_view.get("casualties", []):
		if not casualty_value is Dictionary:
			continue
		var casualty: Dictionary = casualty_value
		if str(casualty.get("side", "")) != side:
			continue
		var piece_type := str(casualty.get("piece_type", ""))
		counts[piece_type] = int(counts.get(piece_type, 0)) + 1
	if counts.is_empty():
		return "无"
	var piece_types: Array = counts.keys()
	piece_types.sort()
	var entries: Array[String] = []
	for piece_type_value: Variant in piece_types:
		var piece_type := str(piece_type_value)
		entries.append(
			"%s ×%d" % [str(TYPE_NAMES.get(piece_type, piece_type)), int(counts[piece_type])]
		)
	return "、".join(entries)


func _wire_focus_neighbors() -> void:
	_move_button.focus_neighbor_bottom = _skill_button.get_path()
	_skill_button.focus_neighbor_top = _move_button.get_path()
	_skill_button.focus_neighbor_right = _confirm_button.get_path()
	_confirm_button.focus_neighbor_right = _cancel_button.get_path()
	_confirm_button.focus_neighbor_left = _skill_button.get_path()
	_cancel_button.focus_neighbor_left = _confirm_button.get_path()
	_cancel_button.focus_neighbor_top = _skill_button.get_path()
	_move_button.grab_focus()
