class_name LevelGuideOverlay
extends Control

signal retry_requested()
signal skip_requested()
signal exit_requested()
signal continue_requested()
signal quiz_answered(option_index: int)
signal hint_requested()
signal step_reset_requested()
signal next_chapter_requested()
signal stay_requested()

@onready var _guide: Control = %LevelGuidePanel
@onready var _decision_panel: PanelContainer = %DecisionPanel
@onready var _decision_title: Label = %DecisionTitle
@onready var _decision_body: Label = %DecisionBody
@onready var _option_buttons: Array[Button] = [%Option0, %Option1, %Option2]
@onready var _continue_button: Button = %ContinueButton
@onready var _completion_actions: HBoxContainer = %CompletionActions
@onready var _next_chapter_button: Button = %NextChapterButton
@onready var _stay_button: Button = %StayButton
@onready var _failure_actions: HBoxContainer = %FailureActions
@onready var _retry_button: Button = %RetryButton
@onready var _exit_button: Button = %BackToLevelsButton

var _track: TutorialPresentationTrack
var _current_step: Dictionary = {}
var _completed_ids: Array[String] = []
var _route_module_ids: Array[String] = []
var _level_id := ""
var _title := ""
var _step_id := ""
var _hint_available := false
var _step_reset_available := false
var _hint_revealed := false
var _hint_text := ""
var _assessment_status := ""
var _completion_summary := ""


func _ready() -> void:
	_guide.hint_requested.connect(func() -> void: hint_requested.emit())
	_guide.reset_requested.connect(func() -> void: step_reset_requested.emit())
	_continue_button.pressed.connect(_on_continue_pressed)
	_next_chapter_button.pressed.connect(func() -> void: next_chapter_requested.emit())
	_stay_button.pressed.connect(func() -> void: stay_requested.emit())
	_retry_button.pressed.connect(func() -> void: retry_requested.emit())
	_exit_button.pressed.connect(func() -> void: exit_requested.emit())
	for option_index: int in _option_buttons.size():
		_option_buttons[option_index].pressed.connect(
			func() -> void: quiz_answered.emit(option_index)
		)
	_hide_decision_content()


func configure_chapter(
	track: TutorialPresentationTrack,
	completed_ids: Array[String] = [],
	route_module_ids: Array[String] = []
) -> void:
	if track == null:
		return
	_track = track
	_level_id = track.level_id
	_title = track.title
	_completed_ids = completed_ids.duplicate()
	_route_module_ids = route_module_ids.duplicate()
	if _route_module_ids.is_empty():
		_route_module_ids = TutorialChapterCatalog.TUTORIAL_IDS.duplicate()
	_current_step = {}
	_step_id = ""
	_hint_available = false
	_step_reset_available = false
	_hint_revealed = false
	_hint_text = "点击“显示提示”查看本步操作提示。"
	_assessment_status = ""
	_completion_summary = ""
	_hide_decision_content()
	_refresh_guide()


func configure_graybox_entry(level_id: String) -> void:
	_track = null
	_level_id = level_id
	_title = "挑战测试入口"
	_step_id = "challenge_graybox"
	_hint_available = false
	_step_reset_available = false
	_hint_revealed = false
	_current_step = {
		"id": _step_id,
		"title": "限定对手尚未迁移",
		"prompt": "当前仅开放正式棋盘、棋子和基础行动链，供界面与终局回放测试。",
		"step_index": 0,
		"step_count": 1,
	}
	_guide.configure({
		"title": "关卡指引 · %s" % level_id,
		"objective": "验证正式棋盘、基础行动与终局回放链路。",
		"steps": [
			{"text": "进入正式棋盘", "status": "complete"},
			{"text": "执行基础行动", "status": "active"},
			{"text": "验证终局回放", "status": "pending"},
		],
		"current_operation": str(_current_step.get("prompt", "")),
		"hint": "挑战脚本将在后续内容任务中接入。",
		"hint_revealed": false,
		"hint_available": false,
		"reset_available": false,
	})
	_hide_decision_content()


func render_public_step(step: Dictionary) -> void:
	_current_step = step.duplicate(true)
	_step_id = str(step.get("id", step.get("step_id", "")))
	_hint_available = bool(step.get("hint_available", false))
	_step_reset_available = bool(step.get("step_reset_available", false))
	_hint_revealed = false
	_hint_text = _default_hint_for_step(step)
	_assessment_status = str(step.get("assessment_status", ""))
	_completion_summary = _summary_text(step.get("summary", []))
	_refresh_guide()
	_configure_decision(step)


func render_feedback(kind: String, title: String, message: String) -> void:
	if title == "操作提示":
		_hint_revealed = true
		_hint_text = message
	else:
		_current_step["feedback"] = "%s：%s" % [title, message]
		_current_step["feedback_kind"] = kind
	_refresh_guide()


func hide_completion_actions() -> void:
	_completion_actions.visible = false
	if _step_id == "completed":
		_decision_panel.visible = false


func request_retry() -> void:
	retry_requested.emit()


func request_skip() -> void:
	skip_requested.emit()


func request_exit() -> void:
	exit_requested.emit()


func get_public_snapshot() -> Dictionary:
	var guide_snapshot: Dictionary = _guide.get_state_snapshot()
	return {
		"level_id": _level_id,
		"title": _title,
		"step_id": _step_id,
		"instruction_key": str(_current_step.get("instruction_key", "")),
		"prompt_expanded": not bool(guide_snapshot.get("collapsed", false)),
		"hint_visible": _hint_available,
		"step_reset_visible": _step_reset_available,
		"assessment_status": _assessment_status,
		"progress_text": _progress_text(),
		"progress_value": _progress_value(),
		"completion_summary": _completion_summary,
		"decision_mode": _decision_mode(),
		"guide": guide_snapshot,
	}


func get_layout_snapshot() -> Dictionary:
	var guide_rect := Rect2(_guide.global_position - global_position, _guide.size)
	var decision_rect := Rect2(
		_decision_panel.global_position - global_position,
		_decision_panel.size
	) if _decision_panel.visible else Rect2()
	var buttons_inside := true
	for button: Button in _visible_action_buttons():
		var rect := Rect2(button.global_position - global_position, button.size)
		buttons_inside = buttons_inside and Rect2(Vector2.ZERO, size).encloses(rect)
	return {
		"guide_rect": guide_rect,
		"guide_content_rect": guide_rect,
		"decision_rect": decision_rect,
		"buttons_inside": buttons_inside,
		"actions_scrollable": false,
	}


func set_collapsed(collapsed: bool) -> void:
	_guide.set_collapsed(collapsed)


func _refresh_guide() -> void:
	if not is_instance_valid(_guide):
		return
	var operation := str(_current_step.get("prompt", "等待关卡步骤。"))
	var feedback := str(_current_step.get("feedback", ""))
	if not feedback.is_empty():
		operation = feedback
	_guide.configure({
		"title": "关卡指引 · %s" % _level_id,
		"objective": _track.goal if _track != null else "完成当前关卡目标。",
		"steps": _visible_step_entries(),
		"current_operation": operation,
		"reason": str(_current_step.get(
			"why",
			_current_step.get("success", "本步骤由正式规则结算；展开可复盘结果。")
		)),
		"hint": _hint_text,
		"hint_revealed": _hint_revealed,
		"hint_available": _hint_available,
		"reset_available": _step_reset_available,
	})


func _visible_step_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _track == null or _track.steps.is_empty():
		return [
			{"text": "等待关卡步骤", "status": "active"},
			{"text": "完成当前目标", "status": "pending"},
			{"text": "确认关卡结果", "status": "pending"},
		]
	var count := _track.steps.size()
	var current_index := clampi(int(_current_step.get("step_index", 0)), 0, count - 1)
	var start_index := clampi(current_index - 1, 0, maxi(0, count - 3))
	var completed := _step_id == "completed"
	for slot: int in 3:
		var step_index := start_index + slot
		if step_index >= count:
			entries.append({"text": "关卡结算", "status": "pending"})
			continue
		var track_step: Dictionary = _track.steps[step_index]
		var status := "pending"
		if completed or step_index < current_index:
			status = "complete"
		elif step_index == current_index:
			status = "active"
		entries.append({
			"text": str(track_step.get("title", "步骤 %d" % (step_index + 1))),
			"status": status,
		})
	return entries


func _default_hint_for_step(step: Dictionary) -> String:
	var target: Array = step.get("target", [])
	if bool(step.get("hint_available", false)) and target.size() == 2:
		return "选择目标棋子和行动模式，目标交点为（%d,%d）。" % [
			int(target[0]), int(target[1]),
		]
	return "选择当前目标指定的棋子和行动模式，按指引完成本步。"


func _on_continue_pressed() -> void:
	# 行动型提示只负责把玩家送入对应操作模式；进入模式后必须立即
	# 让出棋盘空间，否则 T6 的右键取消与后续献祭选择会被弹层遮挡。
	if str(_current_step.get("type", "")) in ["sacrifice_cancel", "sacrifice_confirm"]:
		_hide_decision_content()
	continue_requested.emit()


func _configure_decision(step: Dictionary) -> void:
	_hide_decision_content()
	var options_value: Variant = step.get("options", [])
	var options: Array = options_value if options_value is Array else []
	if not options.is_empty():
		_decision_panel.visible = true
		_decision_title.text = str(step.get("title", "规则确认"))
		_decision_body.text = str(step.get("prompt", "请选择正确答案。"))
		for index: int in mini(options.size(), _option_buttons.size()):
			_option_buttons[index].text = str(options[index])
			_option_buttons[index].visible = true
		_option_buttons[0].grab_focus()
		return
	var button_text := str(step.get("button", ""))
	if not button_text.is_empty():
		_decision_panel.visible = true
		_decision_title.text = str(step.get("title", "继续关卡"))
		_decision_body.text = str(step.get("prompt", "确认后继续。"))
		_continue_button.text = button_text
		_continue_button.visible = true
		_continue_button.grab_focus()
		return
	if _step_id == "completed":
		_decision_panel.visible = true
		_decision_title.text = str(step.get("title", "关卡完成"))
		_decision_body.text = _completion_summary if not _completion_summary.is_empty() \
			else str(step.get("prompt", "本章检查点已记录。"))
		_completion_actions.visible = true
		_next_chapter_button.text = "返回训练目录" \
			if _route_module_ids.find(_level_id) == _route_module_ids.size() - 1 \
			else "进入下一章"
		_next_chapter_button.grab_focus()
		return
	if _step_id == "failed":
		_decision_panel.visible = true
		_decision_title.text = str(step.get("title", "本章未通过"))
		_decision_body.text = str(step.get("prompt", "请重置章节后重试。"))
		_failure_actions.visible = true
		_retry_button.grab_focus()


func _hide_decision_content() -> void:
	_decision_panel.visible = false
	_decision_title.text = ""
	_decision_body.text = ""
	for option: Button in _option_buttons:
		option.visible = false
	_continue_button.visible = false
	_completion_actions.visible = false
	_failure_actions.visible = false


func _summary_text(summary_value: Variant) -> String:
	if not summary_value is Array or (summary_value as Array).is_empty():
		return ""
	var lines: PackedStringArray = []
	for value: Variant in summary_value:
		lines.append("• %s" % str(value))
	return "\n".join(lines)


func _progress_value() -> float:
	var route_count := maxi(1, _route_module_ids.size())
	var completed_count := 0
	for module_id: String in _route_module_ids:
		if module_id in _completed_ids:
			completed_count += 1
	if _step_id == "completed" and _level_id not in _completed_ids:
		completed_count += 1
	var step_fraction := 0.0
	if _track != null and not _track.steps.is_empty() and _step_id != "completed":
		step_fraction = float(int(_current_step.get("step_index", 0))) \
			/ float(_track.steps.size())
	return clampf((float(completed_count) + step_fraction) / float(route_count) * 100.0, 0.0, 100.0)


func _progress_text() -> String:
	if _track == null:
		return "%s · 测试入口" % _level_id
	var route_count := maxi(1, _route_module_ids.size())
	var route_index := maxi(0, _route_module_ids.find(_level_id))
	var step_count := maxi(1, _track.steps.size())
	var step_number := mini(int(_current_step.get("step_index", 0)) + 1, step_count)
	return "章节 %d / %d · 步骤 %d / %d · 总进度 %d%%" % [
		route_index + 1,
		route_count,
		step_number,
		step_count,
		roundi(_progress_value()),
	]


func _decision_mode() -> String:
	if not _decision_panel.visible:
		return "none"
	if _completion_actions.visible:
		return "completion"
	if _failure_actions.visible:
		return "failure"
	if _continue_button.visible:
		return "continue"
	return "quiz"


func _visible_action_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for button: Button in _option_buttons + [
		_continue_button,
		_next_chapter_button,
		_stay_button,
		_retry_button,
		_exit_button,
	]:
		if button.visible:
			buttons.append(button)
	return buttons
