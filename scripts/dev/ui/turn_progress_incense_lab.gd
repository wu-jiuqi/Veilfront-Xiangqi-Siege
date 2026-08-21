class_name TurnProgressIncenseLab
extends Control

@onready var _incense: TurnProgressIncense = %TurnProgressIncense
@onready var _turn_slider: HSlider = %TurnSlider
@onready var _turn_spin: SpinBox = %TurnSpin
@onready var _status: Label = %Status
@onready var _auto_button: Button = %AutoButton
@onready var _auto_timer: Timer = %AutoTimer


func _ready() -> void:
	_turn_slider.value_changed.connect(_on_turn_value_changed)
	_turn_spin.value_changed.connect(_on_turn_value_changed)
	%PreviousButton.pressed.connect(_step_turn.bind(-1))
	%NextButton.pressed.connect(_step_turn.bind(1))
	%Turn1Button.pressed.connect(_jump_to_turn.bind(1))
	%Turn25Button.pressed.connect(_jump_to_turn.bind(25))
	%Turn49Button.pressed.connect(_jump_to_turn.bind(49))
	%Turn50Button.pressed.connect(_jump_to_turn.bind(50))
	_auto_button.pressed.connect(_toggle_auto_play)
	_auto_timer.timeout.connect(_on_auto_timer_timeout)
	_incense.turn_changed.connect(_on_incense_turn_changed)
	_on_turn_value_changed(1.0)
	%NextButton.grab_focus.call_deferred()


func _on_turn_value_changed(value: float) -> void:
	var turn_number := clampi(roundi(value), 1, 50)
	_turn_slider.set_value_no_signal(turn_number)
	_turn_spin.set_value_no_signal(turn_number)
	_incense.set_turn(turn_number, 50, true)


func _step_turn(delta: int) -> void:
	_jump_to_turn(clampi(roundi(_turn_slider.value) + delta, 1, 50))


func _jump_to_turn(turn_number: int) -> void:
	_turn_slider.value = clampi(turn_number, 1, 50)


func _toggle_auto_play() -> void:
	if _auto_timer.is_stopped():
		_auto_timer.start()
		_auto_button.text = "停止自动播放"
	else:
		_auto_timer.stop()
		_auto_button.text = "自动播放 1—50"


func _on_auto_timer_timeout() -> void:
	var next_turn := roundi(_turn_slider.value) + 1
	_jump_to_turn(1 if next_turn > 50 else next_turn)


func _on_incense_turn_changed(_current_turn: int, _chinese_turn: String) -> void:
	var snapshot := _incense.get_state_snapshot()
	_status.text = "第%s回合 · 香剩余 %.0f%% · 烟带目标长度 %.1f px" % [
		TurnProgressIncense.chinese_number(int(snapshot.get("current_turn", 1))),
		float(snapshot.get("remaining_ratio", 0.0)) * 100.0,
		float(snapshot.get("smoke_length", 0.0)),
	]
