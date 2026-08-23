extends Control

signal timed_out(expected_action_index: int)

@export_range(1, 600, 1) var turn_duration_seconds: int = 60

@onready var _safe_margin: MarginContainer = $SafeMargin
@onready var _board_frame: Control = %BoardFrame
@onready var _round_label: Label = %Round
@onready var _side_label: Label = %Side
@onready var _timer_label: Label = %Timer
@onready var _countdown_timer: Timer = $CountdownTimer

var _applied_screen_size := Vector2.ZERO
var _reserved_right: float = 0.0
var _scene_authored_layout_enabled: bool = true
var _seconds_remaining: int = 60
var _action_index: int = -1
var _timeout_enabled: bool = false
var _local_turn: bool = false


func _ready() -> void:
	_seconds_remaining = turn_duration_seconds
	_countdown_timer.timeout.connect(_on_countdown_timeout)
	_refresh_timer_label()


func apply_layout_for_size(requested_size: Vector2, reserved_right: float = 0.0) -> void:
	_applied_screen_size = Vector2(maxf(1.0, requested_size.x), maxf(1.0, requested_size.y))
	_reserved_right = clampf(reserved_right, 0.0, maxf(0.0, _applied_screen_size.x - 320.0))
	_safe_margin.offset_right = -_reserved_right


func set_scene_authored_layout_enabled(enabled: bool) -> void:
	_scene_authored_layout_enabled = enabled


func sync_player_view(view: Dictionary, timeout_enabled: bool) -> void:
	_timeout_enabled = timeout_enabled
	if view.is_empty():
		_action_index = -1
		_local_turn = false
		_seconds_remaining = turn_duration_seconds
		_countdown_timer.stop()
		_round_label.text = "等待战局"
		_side_label.text = "尚未开始"
		_refresh_timer_label()
		return

	var next_action_index := int(view.get("action_index", -1))
	if next_action_index != _action_index:
		_action_index = next_action_index
		_seconds_remaining = turn_duration_seconds
	var active_side := str(view.get("active_side", ""))
	var viewer_side := str(view.get("viewer_side", ""))
	_local_turn = active_side == viewer_side and not bool(view.get("terminal", false))
	_round_label.text = "第 %d 回合" % int(view.get("full_round_index", 0))
	_side_label.text = "%s方行动" % _side_display_name(active_side)
	_side_label.modulate = Color(1.0, 0.63, 0.42, 1.0) \
		if active_side == "red" else Color(0.7, 0.82, 0.54, 1.0)
	if _timeout_enabled and _local_turn:
		if _countdown_timer.is_stopped():
			_countdown_timer.start()
	else:
		_countdown_timer.stop()
	_refresh_timer_label()


func get_layout_snapshot() -> Dictionary:
	return {
		"schema_version": "match-hud-v3",
		"board_rect_meaning": "default_visible_board_screen_rect",
		"active_profile": "scene-authored-responsive" \
			if _scene_authored_layout_enabled else "container-responsive",
		"screen_size": _applied_screen_size,
		"reserved_right": _reserved_right,
		"content_rect": Rect2(Vector2.ZERO, Vector2(
			maxf(0.0, _applied_screen_size.x - _reserved_right),
			_applied_screen_size.y
		)),
		"board_rect": _local_rect(_board_frame),
		"ui_rects": {
			"faction-left": _local_rect($SafeMargin/MainRows/TopBand/FactionLeft),
			"turn-status": _local_rect($SafeMargin/MainRows/TopBand/TurnStatus),
			"faction-right": _local_rect($SafeMargin/MainRows/TopBand/FactionRight),
			"minimap": _local_rect($SafeMargin/MainRows/BodyBand/LeftRail/MinimapPanel),
			"unit-info": _local_rect($SafeMargin/MainRows/BodyBand/LeftRail/UnitInfo),
			"action-panel": _local_rect(
				$SafeMargin/MainRows/BodyBand/CenterColumn/ActionPanel
			),
			"objective-events": _local_rect(
				$SafeMargin/MainRows/BodyBand/RightRail/ObjectiveEvents
			),
			"confirmation": _local_rect(
				$SafeMargin/MainRows/BodyBand/RightRail/Confirmation
			),
		},
		"text_layer_visibility": {},
	}


func is_text_layer_enabled(_panel_id: String, _layer_id: String) -> bool:
	return false


func get_catalog_text(_panel_id: String, _layer_id: String, fallback: String = "") -> String:
	return fallback


func get_state_snapshot() -> Dictionary:
	return {
		"action_index": _action_index,
		"seconds_remaining": _seconds_remaining,
		"timeout_enabled": _timeout_enabled,
		"local_turn": _local_turn,
		"timer_running": not _countdown_timer.is_stopped(),
		"round_text": _round_label.text,
		"side_text": _side_label.text,
		"timer_text": _timer_label.text,
	}


func _local_rect(control: Control) -> Rect2:
	return Rect2(control.global_position - global_position, control.size)


func _on_countdown_timeout() -> void:
	if not _timeout_enabled or not _local_turn or _action_index < 0:
		_countdown_timer.stop()
		return
	_seconds_remaining = maxi(0, _seconds_remaining - 1)
	_refresh_timer_label()
	if _seconds_remaining > 0:
		return
	_countdown_timer.stop()
	_local_turn = false
	timed_out.emit(_action_index)


func _refresh_timer_label() -> void:
	if not _timeout_enabled:
		_timer_label.text = "不限时"
	elif not _local_turn and _action_index >= 0:
		_timer_label.text = "等待对手"
	else:
		_timer_label.text = "剩余 %d 秒" % _seconds_remaining


func _side_display_name(side: String) -> String:
	return {"red": "赤", "black": "玄"}.get(side, "—")
