class_name TutorialOverlay
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

@onready var _tutorial_foldable: FoldableContainer = $TutorialFoldable
@onready var _chapter_code: Label = $TutorialFoldable/Margin/Content/ChapterCode
@onready var _chapter_progress: ProgressBar = $TutorialFoldable/Margin/Content/ChapterProgress
@onready var _progress_text: Label = $TutorialFoldable/Margin/Content/ProgressText
@onready var _assessment_status: Label = $TutorialFoldable/Margin/Content/AssessmentStatus
@onready var _chapter_title: Label = $TutorialFoldable/Margin/Content/ChapterTitle
@onready var _goal: Label = $TutorialFoldable/Margin/Content/Goal
@onready var _tags: Label = $TutorialFoldable/Margin/Content/Tags
@onready var _step_counter: Label = $TutorialFoldable/Margin/Content/StepCounter
@onready var _step_title: Label = $TutorialFoldable/Margin/Content/StepTitle
@onready var _instruction: Label = $TutorialFoldable/Margin/Content/Instruction
@onready var _feedback: Label = $TutorialFoldable/Margin/Content/Feedback
@onready var _action_log: Label = $TutorialFoldable/Margin/Content/ActionLog
@onready var _options: Array[Button] = [
	$TutorialFoldable/Margin/Content/Options/Option0,
	$TutorialFoldable/Margin/Content/Options/Option1,
	$TutorialFoldable/Margin/Content/Options/Option2,
]
@onready var _continue_button: Button = $TutorialFoldable/Margin/Content/ContinueButton
@onready var _completion_actions: HBoxContainer = $TutorialFoldable/Margin/Content/CompletionActions
@onready var _next_chapter_button: Button = $TutorialFoldable/Margin/Content/CompletionActions/NextChapterButton
@onready var _stay_button: Button = $TutorialFoldable/Margin/Content/CompletionActions/StayButton
@onready var _completion_summary: Label = $TutorialFoldable/Margin/Content/CompletionSummary
@onready var _hint_button: Button = $TutorialFoldable/Margin/Content/HintButton
@onready var _reset_step_button: Button = $TutorialFoldable/Margin/Content/ResetStepButton
@onready var _retry_button: Button = $TutorialFoldable/Margin/Content/Actions/RetryButton
@onready var _skip_button: Button = $TutorialFoldable/Margin/Content/Actions/SkipButton
@onready var _exit_button: Button = $TutorialFoldable/Margin/Content/Actions/BackToLevelsButton

var _step_id: String = ""
var _instruction_key: String = ""
var _level_id: String = ""
var _title: String = ""
var _log_entries: Array[String] = []
var _summary: PackedStringArray = []
var _completed_ids: Array[String] = []
var _step_count: int = 1

const TUTORIAL_COUNT := 11


func _ready() -> void:
	_retry_button.pressed.connect(request_retry)
	_skip_button.pressed.connect(request_skip)
	_exit_button.pressed.connect(request_exit)
	_continue_button.pressed.connect(func() -> void: continue_requested.emit())
	_hint_button.pressed.connect(func() -> void: hint_requested.emit())
	_reset_step_button.pressed.connect(func() -> void: step_reset_requested.emit())
	_next_chapter_button.pressed.connect(func() -> void: next_chapter_requested.emit())
	_stay_button.pressed.connect(_stay_on_completed_chapter)
	_tutorial_foldable.folding_changed.connect(_on_tutorial_folded)
	_apply_folded_bounds(_tutorial_foldable.folded)
	for option_index: int in _options.size():
		_options[option_index].pressed.connect(_emit_quiz_answer.bind(option_index))


func _emit_quiz_answer(option_index: int) -> void:
	quiz_answered.emit(option_index)


func configure_chapter(track: TutorialPresentationTrack, completed_ids: Array[String] = []) -> void:
	if track == null:
		return
	_level_id = track.level_id
	_title = track.title
	_summary = track.summary.duplicate()
	_completed_ids = completed_ids.duplicate()
	_chapter_code.text = "%s · %s" % [track.level_id, track.subtitle]
	_chapter_title.text = track.title
	_goal.text = track.goal
	_tags.text = " · ".join(track.tags)
	_update_progress(0, maxi(1, track.steps.size()))


func configure_graybox_entry(level_id: String) -> void:
	_level_id = level_id
	_title = "挑战灰盒入口"
	_chapter_code.text = "%s · 测试开放" % level_id
	_chapter_title.text = _title
	_goal.text = "当前开放正式棋盘、棋子和基础行动链，供界面测试。"
	_tags.text = "测试开放 · 被动对手 · 非最终挑战内容"
	_update_progress(0, 1)
	render_public_step({
		"id": "challenge_graybox",
		"title": "限定对手尚未迁移",
		"prompt": "C1–C3 的孤相、双相、双马限定对手将在挑战迁移任务中接入；当前对手只会自动跳过。",
		"step_index": 0,
		"step_count": 1,
	})


func render_public_step(step: Dictionary) -> void:
	_step_id = str(step.get("id", step.get("step_id", "")))
	_instruction_key = str(step.get("instruction_key", ""))
	_step_counter.text = "步骤 %d / %d" % [
		int(step.get("step_index", 0)) + 1,
		maxi(1, int(step.get("step_count", 1))),
	]
	_step_count = maxi(1, int(step.get("step_count", 1)))
	_update_progress(int(step.get("step_index", 0)), _step_count)
	_step_title.text = str(step.get("title", _step_id))
	_instruction.text = str(step.get("prompt", _instruction_key))
	_feedback.text = "按照目标在棋盘上操作。"
	_feedback.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86, 1))
	var assessment_text := str(step.get("assessment_status", ""))
	_assessment_status.text = assessment_text
	_assessment_status.visible = not assessment_text.is_empty()
	for option: Button in _options:
		option.visible = false
	var option_values: Array = step.get("options", [])
	for option_index: int in mini(option_values.size(), _options.size()):
		_options[option_index].text = str(option_values[option_index])
		_options[option_index].visible = true
	var button_text := str(step.get("button", ""))
	_continue_button.visible = not button_text.is_empty()
	_continue_button.text = button_text if not button_text.is_empty() else "继续"
	var is_completed := _step_id == "completed"
	if is_completed and _level_id not in _completed_ids:
		_completed_ids.append(_level_id)
		_update_progress(_step_count, _step_count)
	_completion_actions.visible = is_completed
	_hint_button.visible = bool(step.get("hint_available", false)) and not is_completed
	_reset_step_button.visible = bool(step.get("step_reset_available", false)) and not is_completed
	var summary_values: Array = step.get("summary", Array(_summary))
	_completion_summary.visible = is_completed and not summary_values.is_empty()
	_completion_summary.text = "本章总结：\n• " + "\n• ".join(summary_values) \
		if not summary_values.is_empty() else ""
	if is_completed:
		_next_chapter_button.text = "进入下一章" if _level_id != "T10" else "返回训练目录"
	_append_log("步骤：" + _step_title.text)


func render_feedback(kind: String, title: String, message: String) -> void:
	_feedback.text = "%s：%s" % [title, message]
	_feedback.add_theme_color_override(
		"font_color",
		Color(0.42, 0.92, 0.58, 1) if kind == "success" else Color(1.0, 0.72, 0.28, 1)
	)
	_append_log("%s：%s" % [title, message])


func _update_progress(step_index: int, step_count: int) -> void:
	var chapter_index := maxi(0, _tutorial_chapter_index(_level_id))
	var recorded := _level_id in _completed_ids
	var chapter_fraction := 0.0 if recorded else clampf(
		float(step_index) / float(maxi(1, step_count)), 0.0, 1.0
	)
	var percent := clampf(
		(float(_completed_ids.size()) + chapter_fraction) / float(TUTORIAL_COUNT) * 100.0,
		0.0,
		100.0
	)
	_progress_text.text = "章节 %d / %d · 步骤 %d / %d · 总进度 %d%%" % [
		chapter_index + 1,
		TUTORIAL_COUNT,
		mini(step_index + 1, step_count),
		step_count,
		roundi(percent),
	]
	_chapter_progress.value = percent


func _tutorial_chapter_index(level_id: String) -> int:
	if level_id.begins_with("T"):
		var numeric := level_id.trim_prefix("T").to_int()
		return clampi(numeric, 0, TUTORIAL_COUNT - 1)
	return 0


func _append_log(message: String) -> void:
	if message.is_empty():
		return
	_log_entries.append(message)
	if _log_entries.size() > 3:
		_log_entries.pop_front()
	_action_log.text = "公开行动记录：\n" + "\n".join(_log_entries)


func _stay_on_completed_chapter() -> void:
	_completion_actions.visible = false
	_append_log("已留在本章：最终局面保持只读，可使用重置章节重新操作。")


func _on_tutorial_folded(folded: bool) -> void:
	_apply_folded_bounds(folded)


func _apply_folded_bounds(_folded: bool) -> void:
	# The root rect is the authored layout source for the reused objective panel.
	# Folding only changes the prebuilt FoldableContainer content; it must not move
	# or resize the original HUD frame underneath it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func request_retry() -> void:
	retry_requested.emit()


func request_skip() -> void:
	skip_requested.emit()


func request_exit() -> void:
	exit_requested.emit()


func get_public_snapshot() -> Dictionary:
	return {
		"level_id": _level_id,
		"title": _title,
		"step_id": _step_id,
		"instruction_key": _instruction_key,
		"prompt_expanded": not _tutorial_foldable.folded,
		"hint_visible": _hint_button.visible,
		"step_reset_visible": _reset_step_button.visible,
		"assessment_status": _assessment_status.text if _assessment_status.visible else "",
		"progress_text": _progress_text.text,
		"progress_value": _chapter_progress.value,
		"completion_summary": _completion_summary.text if _completion_summary.visible else "",
	}
