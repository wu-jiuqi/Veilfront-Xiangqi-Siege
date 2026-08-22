class_name MatchTerminalDialog
extends Control

signal restart_requested()
signal exit_requested(destination: String)

const CONTEXT_LAN: String = "lan"
const CONTEXT_LEVEL: String = "level"
const CONTEXT_LOCAL: String = "local"
const CONTEXT_PREVIEW: String = "preview"
const DESTINATION_LOBBY: String = "lobby"
const DESTINATION_LEVEL_SELECT: String = "level_select"

const REASON_TEXT: Dictionary[String, String] = {
	"general_destroyed": "主将被斩",
	"simultaneous_generals_destroyed": "双方主将同时被毁",
	"three_flags": "夺得三面军旗",
	"round_limit_flags": "轮次上限按军旗数裁定",
	"round_limit_draw": "轮次上限时军旗数相同",
}
const RESULT_COLORS: Dictionary[String, Color] = {
	"victory": Color(0.96, 0.79, 0.43, 1.0),
	"defeat": Color(0.72, 0.53, 0.45, 1.0),
	"draw": Color(0.72, 0.76, 0.7, 1.0),
}

@onready var _result_panel: PanelContainer = $SafeMargin/Center/ResultPanel
@onready var _result_title: Label = %ResultTitle
@onready var _reason_label: Label = %ReasonLabel
@onready var _red_result: Label = %RedResult
@onready var _black_result: Label = %BlackResult
@onready var _round_value: Label = %RoundValue
@onready var _flag_value: Label = %FlagValue
@onready var _casualty_value: Label = %CasualtyValue
@onready var _restart_button: Button = %RestartButton
@onready var _lobby_button: Button = %LobbyButton
@onready var _level_select_button: Button = %LevelSelectButton

var _context: String = CONTEXT_LOCAL
var _presentation_model: Dictionary = {}


func _ready() -> void:
	visible = false
	resized.connect(_update_panel_size)
	configure_context(_context)
	call_deferred("_update_panel_size")


func configure_context(context: String) -> void:
	_context = context if context in [
		CONTEXT_LAN,
		CONTEXT_LEVEL,
		CONTEXT_LOCAL,
		CONTEXT_PREVIEW,
	] else CONTEXT_LOCAL
	_restart_button.visible = _context != CONTEXT_LAN
	_lobby_button.visible = _context in [CONTEXT_LAN, CONTEXT_PREVIEW]
	_level_select_button.visible = _context in [
		CONTEXT_LEVEL,
		CONTEXT_LOCAL,
		CONTEXT_PREVIEW,
	]
	_wire_focus_navigation()


func show_result(player_view: Dictionary, context: String = "") -> void:
	if not context.is_empty():
		configure_context(context)
	if not bool(player_view.get("terminal", false)):
		return
	_presentation_model = _build_presentation_model(player_view)
	_result_title.text = str(_presentation_model.get("result_text", "和局"))
	_reason_label.text = "胜负原因：%s" % str(
		_presentation_model.get("reason_text", "战局结束")
	)
	_red_result.text = "赤方 · %s" % str(_presentation_model.get("red_outcome", "未裁定"))
	_black_result.text = "玄方 · %s" % str(_presentation_model.get("black_outcome", "未裁定"))
	_round_value.text = str(_presentation_model.get("round_value", "—"))
	_flag_value.text = str(_presentation_model.get("flag_value", "—"))
	_casualty_value.text = str(_presentation_model.get("casualty_value", "—"))
	_result_title.add_theme_color_override(
		"font_color",
		RESULT_COLORS.get(str(_presentation_model.get("result_tone", "draw")), RESULT_COLORS.draw)
	)
	visible = true
	move_to_front()
	call_deferred("_focus_default_action")


func hide_result() -> void:
	for button: Button in [_restart_button, _lobby_button, _level_select_button]:
		if button.has_focus():
			button.release_focus()
	visible = false


func get_presentation_snapshot() -> Dictionary:
	var snapshot := _presentation_model.duplicate(true)
	snapshot.merge({
		"context": _context,
		"visible": visible,
		"restart_visible": _restart_button.visible,
		"lobby_visible": _lobby_button.visible,
		"level_select_visible": _level_select_button.visible,
		"panel_size": _result_panel.size,
	}, true)
	return snapshot


func _build_presentation_model(player_view: Dictionary) -> Dictionary:
	var viewer_side := str(player_view.get("viewer_side", ""))
	var winner := str(player_view.get("winner", "draw"))
	var result_text := "和局"
	var result_tone := "draw"
	if winner in ["red", "black"]:
		result_text = "胜利" if winner == viewer_side else "败北"
		result_tone = "victory" if winner == viewer_side else "defeat"
	var reason_key := str(player_view.get("win_reason", ""))
	var flag_counts := _side_counts(player_view.get("flags", []), "owner", true)
	var casualty_counts := _side_counts(player_view.get("casualties", []), "side", false)
	return {
		"result_text": result_text,
		"result_tone": result_tone,
		"reason_key": reason_key,
		"reason_text": REASON_TEXT.get(reason_key, "战局结束"),
		"red_outcome": _faction_outcome("red", winner),
		"black_outcome": _faction_outcome("black", winner),
		"round_value": str(int(player_view.get("full_round_index", 0))) \
			if player_view.has("full_round_index") else "—",
		"flag_value": "%d : %d" % [int(flag_counts.red), int(flag_counts.black)],
		"casualty_value": "%d : %d" % [
			int(casualty_counts.red),
			int(casualty_counts.black),
		],
	}


func _side_counts(values: Variant, side_key: String, require_discovered: bool) -> Dictionary:
	var counts := {"red": 0, "black": 0}
	if not values is Array:
		return counts
	for value: Variant in values:
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		if require_discovered and not bool(item.get("discovered", false)):
			continue
		var side := str(item.get(side_key, ""))
		if side in counts:
			counts[side] = int(counts[side]) + 1
	return counts


func _faction_outcome(side: String, winner: String) -> String:
	if winner == "draw":
		return "和局"
	if winner not in ["red", "black"]:
		return "未裁定"
	return "胜利" if side == winner else "败北"


func _update_panel_size() -> void:
	if not is_instance_valid(_result_panel):
		return
	var available := size - Vector2(36.0, 36.0)
	var target := Vector2(
		clampf(size.x * 0.68, 720.0, 1060.0),
		clampf(size.y * 0.72, 460.0, 700.0)
	)
	_result_panel.custom_minimum_size = Vector2(
		minf(target.x, maxf(640.0, available.x)),
		minf(target.y, maxf(440.0, available.y))
	)


func _wire_focus_navigation() -> void:
	var actions: Array[Button] = []
	for button: Button in [_restart_button, _lobby_button, _level_select_button]:
		button.focus_neighbor_left = NodePath()
		button.focus_neighbor_right = NodePath()
		if button.visible and not button.disabled:
			actions.append(button)
	if actions.is_empty():
		return
	for index: int in actions.size():
		var button: Button = actions[index]
		button.focus_neighbor_left = button.get_path_to(
			actions[(index - 1 + actions.size()) % actions.size()]
		)
		button.focus_neighbor_right = button.get_path_to(actions[(index + 1) % actions.size()])


func _focus_default_action() -> void:
	var preferred := _lobby_button if _context == CONTEXT_LAN else _restart_button
	if preferred.visible and not preferred.disabled:
		preferred.grab_focus()
	elif _level_select_button.visible and not _level_select_button.disabled:
		_level_select_button.grab_focus()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_lobby_pressed() -> void:
	exit_requested.emit(DESTINATION_LOBBY)


func _on_level_select_pressed() -> void:
	exit_requested.emit(DESTINATION_LEVEL_SELECT)
