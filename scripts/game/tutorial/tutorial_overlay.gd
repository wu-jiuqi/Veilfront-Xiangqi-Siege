class_name TutorialOverlay
extends PanelContainer

signal retry_requested()
signal skip_requested()
signal exit_requested()
signal continue_requested()
signal quiz_answered(option_index: int)
signal hint_requested()

@onready var _chapter_code: Label = $Margin/Content/ChapterCode
@onready var _chapter_title: Label = $Margin/Content/ChapterTitle
@onready var _goal: Label = $Margin/Content/Goal
@onready var _tags: Label = $Margin/Content/Tags
@onready var _step_counter: Label = $Margin/Content/StepCounter
@onready var _step_title: Label = $Margin/Content/StepTitle
@onready var _instruction: Label = $Margin/Content/Instruction
@onready var _feedback: Label = $Margin/Content/Feedback
@onready var _options: Array[Button] = [
	$Margin/Content/Options/Option0,
	$Margin/Content/Options/Option1,
	$Margin/Content/Options/Option2,
]
@onready var _continue_button: Button = $Margin/Content/ContinueButton
@onready var _hint_button: Button = $Margin/Content/HintButton
@onready var _retry_button: Button = $Margin/Content/Actions/RetryButton
@onready var _skip_button: Button = $Margin/Content/Actions/SkipButton
@onready var _exit_button: Button = $Margin/Content/Actions/BackToLevelsButton

var _step_id: String = ""
var _instruction_key: String = ""
var _level_id: String = ""
var _title: String = ""


func _ready() -> void:
	_retry_button.pressed.connect(request_retry)
	_skip_button.pressed.connect(request_skip)
	_exit_button.pressed.connect(request_exit)
	_continue_button.pressed.connect(func() -> void: continue_requested.emit())
	_hint_button.pressed.connect(func() -> void: hint_requested.emit())
	for option_index: int in _options.size():
		_options[option_index].pressed.connect(_emit_quiz_answer.bind(option_index))


func _emit_quiz_answer(option_index: int) -> void:
	quiz_answered.emit(option_index)


func configure_chapter(track: TutorialPresentationTrack) -> void:
	if track == null:
		return
	_level_id = track.level_id
	_title = track.title
	_chapter_code.text = "%s · %s" % [track.level_id, track.subtitle]
	_chapter_title.text = track.title
	_goal.text = track.goal
	_tags.text = " · ".join(track.tags)


func configure_graybox_entry(level_id: String) -> void:
	_level_id = level_id
	_title = "挑战灰盒入口"
	_chapter_code.text = "%s · 测试开放" % level_id
	_chapter_title.text = _title
	_goal.text = "当前开放正式棋盘、棋子和基础行动链，供界面测试。"
	_tags.text = "测试开放 · 被动对手 · 非最终挑战内容"
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
	_step_title.text = str(step.get("title", _step_id))
	_instruction.text = str(step.get("prompt", _instruction_key))
	_feedback.text = "按照目标在棋盘上操作。"
	_feedback.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86, 1))
	for option: Button in _options:
		option.visible = false
	var option_values: Array = step.get("options", [])
	for option_index: int in mini(option_values.size(), _options.size()):
		_options[option_index].text = str(option_values[option_index])
		_options[option_index].visible = true
	var button_text := str(step.get("button", ""))
	_continue_button.visible = not button_text.is_empty()
	_continue_button.text = button_text if not button_text.is_empty() else "继续"


func render_feedback(kind: String, title: String, message: String) -> void:
	_feedback.text = "%s：%s" % [title, message]
	_feedback.add_theme_color_override(
		"font_color",
		Color(0.42, 0.92, 0.58, 1) if kind == "success" else Color(1.0, 0.72, 0.28, 1)
	)


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
	}
