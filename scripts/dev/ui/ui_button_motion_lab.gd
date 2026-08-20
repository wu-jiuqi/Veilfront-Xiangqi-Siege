extends Control

@export var motion_profile: Resource

@onready var demo_panel: PanelContainer = %DemoPanel
@onready var feedback_target: PanelContainer = %FeedbackTarget
@onready var tab_indicator: Panel = %TabIndicator
@onready var status_label: Label = %StatusLabel
@onready var reduced_motion_toggle: CheckButton = %ReducedMotionToggle
@onready var primary_button: Button = %PrimaryButton

var _entry_tween: Tween
var _feedback_tween: Tween
var _tab_tween: Tween


func _ready() -> void:
	_set_reduced_motion(false)
	demo_panel.resized.connect(_update_demo_pivot)
	_update_demo_pivot()
	primary_button.grab_focus.call_deferred()
	play_entrance.call_deferred()


func play_entrance() -> void:
	_kill_tween(_entry_tween)
	_update_demo_pivot()
	demo_panel.modulate = Color(1, 1, 1, 0)
	demo_panel.scale = Vector2.ONE if reduced_motion_toggle.button_pressed else Vector2(0.985, 0.985)
	_entry_tween = _new_tween()
	_entry_tween.set_parallel(true)
	_entry_tween.tween_property(demo_panel, "modulate", Color.WHITE, _duration(&"entrance"))
	_entry_tween.tween_property(demo_panel, "scale", Vector2.ONE, _duration(&"entrance"))
	status_label.text = "已重播：入场动效"


func play_feedback() -> void:
	_kill_tween(_feedback_tween)
	feedback_target.pivot_offset = feedback_target.size * 0.5
	feedback_target.self_modulate = Color(1.35, 0.55, 0.38, 1)
	feedback_target.scale = Vector2.ONE if reduced_motion_toggle.button_pressed else Vector2(1.025, 1.025)
	_feedback_tween = _new_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(feedback_target, "self_modulate", Color.WHITE, _duration(&"feedback"))
	_feedback_tween.tween_property(feedback_target, "scale", Vector2.ONE, _duration(&"feedback"))
	status_label.text = "已触发：结果反馈动效"


func play_tab_switch(tab_name: String) -> void:
	_kill_tween(_tab_tween)
	tab_indicator.pivot_offset = tab_indicator.size * 0.5
	tab_indicator.self_modulate = Color(1.25, 1.08, 0.62, 1)
	tab_indicator.scale = Vector2.ONE if reduced_motion_toggle.button_pressed else Vector2(0.75, 1.0)
	_tab_tween = _new_tween()
	_tab_tween.set_parallel(true)
	_tab_tween.tween_property(tab_indicator, "self_modulate", Color.WHITE, _duration(&"tab"))
	_tab_tween.tween_property(tab_indicator, "scale", Vector2.ONE, _duration(&"tab"))
	status_label.text = "当前页签：%s" % tab_name


func _on_reduced_motion_toggled(enabled: bool) -> void:
	_set_reduced_motion(enabled)
	status_label.text = "减少动态效果：%s" % ("开启" if enabled else "关闭")


func _on_replay_pressed() -> void:
	play_entrance()


func _on_feedback_pressed() -> void:
	play_feedback()


func _on_tab_overview_pressed() -> void:
	play_tab_switch("战况")


func _on_tab_units_pressed() -> void:
	play_tab_switch("部队")


func _on_tab_orders_pressed() -> void:
	play_tab_switch("军令")


func _set_reduced_motion(enabled: bool) -> void:
	reduced_motion_toggle.set_pressed_no_signal(enabled)
	for button: Node in get_tree().get_nodes_in_group(&"ui_motion_buttons"):
		if button.has_method("set_reduced_motion"):
			button.set_reduced_motion(enabled)


func _update_demo_pivot() -> void:
	demo_panel.pivot_offset = demo_panel.size * 0.5


func _duration(group: StringName) -> float:
	return motion_profile.duration_for(group, reduced_motion_toggle.button_pressed) if motion_profile != null else 0.18


func _new_tween() -> Tween:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	return tween


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
