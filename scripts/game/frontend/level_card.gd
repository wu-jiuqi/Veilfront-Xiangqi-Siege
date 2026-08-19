class_name LevelCard
extends PanelContainer

signal play_requested(level: LevelDefinition)

@onready var _code_label: Label = %CodeLabel
@onready var _title_label: Label = %TitleLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _status_label: Label = %StatusLabel
@onready var _play_button: Button = %PlayButton

var _level: LevelDefinition


func _ready() -> void:
	_play_button.pressed.connect(func() -> void:
		if _level != null and _play_button.disabled == false:
			play_requested.emit(_level)
	)


func configure(level: LevelDefinition, unlocked: bool) -> void:
	_level = level
	_code_label.text = level.level_id
	_title_label.text = level.title
	_summary_label.text = level.summary
	_play_button.disabled = not unlocked or not level.available
	if not level.available:
		_status_label.text = "灰盒入口待接入"
	elif unlocked:
		_status_label.text = "已开放"
	else:
		_status_label.text = "完成前置章节后开放"
	_play_button.text = "进入" if level.available and unlocked else "待解锁"


func focus_play_button() -> void:
	_play_button.grab_focus()

