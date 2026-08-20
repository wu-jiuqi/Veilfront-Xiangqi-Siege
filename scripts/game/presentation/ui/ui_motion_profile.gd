class_name UiMotionProfile
extends Resource

@export_category("六组 UI 动效时长")
@export_range(0.0, 1.0, 0.01) var entrance_duration := 0.28
@export_range(0.0, 1.0, 0.01) var hover_duration := 0.14
@export_range(0.0, 1.0, 0.01) var press_duration := 0.08
@export_range(0.0, 1.0, 0.01) var focus_duration := 0.16
@export_range(0.0, 1.0, 0.01) var tab_duration := 0.18
@export_range(0.0, 1.0, 0.01) var feedback_duration := 0.22

@export_category("视觉幅度")
@export_range(1.0, 1.12, 0.001) var hover_scale := 1.035
@export_range(0.88, 1.0, 0.001) var pressed_scale := 0.965
@export_range(1.0, 1.08, 0.001) var focus_scale := 1.015
@export_range(0.0, 1.0, 0.01) var reduced_motion_duration_scale := 0.45


func duration_for(group: StringName, reduced_motion: bool = false) -> float:
	var duration := hover_duration
	match group:
		&"entrance": duration = entrance_duration
		&"hover": duration = hover_duration
		&"press": duration = press_duration
		&"focus": duration = focus_duration
		&"tab": duration = tab_duration
		&"feedback": duration = feedback_duration
		_: push_warning("未知 UI 动效组：%s" % group)
	return duration * (reduced_motion_duration_scale if reduced_motion else 1.0)
