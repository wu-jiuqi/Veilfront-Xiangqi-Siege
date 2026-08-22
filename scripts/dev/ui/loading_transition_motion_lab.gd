extends Control

@onready var loading_overlay: Control = %LoadingOverlay
@onready var lab_hint: Label = %LabHint

var _sequence_tween: Tween
var _reduced_motion := false


func _ready() -> void:
	play_demo.call_deferred()


func play_demo() -> void:
	_kill_sequence()
	loading_overlay.set_reduced_motion(_reduced_motion)
	loading_overlay.start_loading("正在唤醒关城烽火…")
	lab_hint.text = _hint_text()
	_sequence_tween = _new_sequence_tween()
	_sequence_tween.tween_method(loading_overlay.set_progress, 0.0, 18.0, _scaled(1.15))
	_sequence_tween.tween_callback(loading_overlay.set_status.bind("正在布设九路战场…"))
	_sequence_tween.tween_method(loading_overlay.set_progress, 18.0, 43.0, _scaled(1.45))
	_sequence_tween.tween_callback(loading_overlay.set_status.bind("正在同步迷雾边界…"))
	_sequence_tween.tween_method(loading_overlay.set_progress, 43.0, 67.0, _scaled(1.55))
	_sequence_tween.tween_interval(_scaled(0.8))
	_sequence_tween.tween_callback(
		loading_overlay.show_failure.bind("加载失败", "未能抵达战场", "场景资源响应超时，请重试。")
	)


func show_failure_now() -> void:
	_kill_sequence()
	if not loading_overlay.visible or loading_overlay.get_transition_state() == &"hidden":
		loading_overlay.start_loading("正在同步迷雾边界…")
	loading_overlay.set_progress(67.0)
	loading_overlay.show_failure("加载失败", "未能抵达战场", "场景资源响应超时，请重试。")


func _on_retry_requested() -> void:
	play_demo()


func _on_back_requested() -> void:
	_kill_sequence()
	var exit_tween: Tween = loading_overlay.play_exit()
	exit_tween.finished.connect(play_demo, CONNECT_ONE_SHOT)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_R:
			play_demo()
			get_viewport().set_input_as_handled()
		KEY_F:
			show_failure_now()
			get_viewport().set_input_as_handled()
		KEY_M:
			_reduced_motion = not _reduced_motion
			loading_overlay.set_reduced_motion(_reduced_motion)
			lab_hint.text = _hint_text()
			get_viewport().set_input_as_handled()


func _hint_text() -> String:
	return "R 重播加载  ·  F 触发失败  ·  M 减少动态效果：%s" % ("开" if _reduced_motion else "关")


func _scaled(duration: float) -> float:
	return duration * (0.45 if _reduced_motion else 1.0)


func _new_sequence_tween() -> Tween:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	return tween


func _kill_sequence() -> void:
	if _sequence_tween != null and _sequence_tween.is_valid():
		_sequence_tween.kill()
	_sequence_tween = null
