class_name TutorialOverlay
extends PanelContainer

signal retry_requested()
signal skip_requested()
signal exit_requested()

@onready var _step_label: Label = $Content/StepLabel
@onready var _instruction: Label = $Content/Instruction
@onready var _retry_button: Button = $Content/Actions/RetryButton
@onready var _skip_button: Button = $Content/Actions/SkipButton
@onready var _exit_button: Button = $Content/Actions/ExitButton

var _step_id: String = ""
var _instruction_key: String = ""


func _ready() -> void:
	_retry_button.pressed.connect(request_retry)
	_skip_button.pressed.connect(request_skip)
	_exit_button.pressed.connect(request_exit)


func render_public_step(step: Dictionary) -> void:
	_step_id = str(step.get("step_id", ""))
	_instruction_key = str(step.get("instruction_key", ""))
	_step_label.text = "教学：%s" % _step_id
	_instruction.text = _instruction_key


func request_retry() -> void:
	retry_requested.emit()


func request_skip() -> void:
	skip_requested.emit()


func request_exit() -> void:
	exit_requested.emit()


func get_public_snapshot() -> Dictionary:
	return {"step_id": _step_id, "instruction_key": _instruction_key}
