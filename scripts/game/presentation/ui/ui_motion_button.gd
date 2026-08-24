class_name UiMotionButton
extends Button

@export var motion_profile: Resource
@export var reduced_motion := false
@export var semantic_role: StringName = &"primary"

var _active_tween: Tween
var _pointer_inside := false
var _pressed_visual := false


func _ready() -> void:
	offset_transform_enabled = true
	offset_transform_visual_only = true
	offset_transform_pivot = Vector2.ZERO
	offset_transform_pivot_ratio = Vector2(0.5, 0.5)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	reset_motion()


func is_reduced_motion_enabled() -> bool:
	return reduced_motion


func preview_state(state: StringName) -> void:
	if disabled or state == &"disabled":
		reset_motion()
		return
	match state:
		&"hover": _animate_to(
			_hover_scale(), Vector2(0, -1.5), Color(1.08, 1.04, 0.92, 1), _duration(&"hover")
		)
		&"press": _animate_to(
			_pressed_scale(), Vector2(0, 1.0), Color(0.86, 0.82, 0.72, 1), _duration(&"press")
		)
		&"focus": _animate_to(
			_focus_scale(), Vector2.ZERO, Color(1.12, 1.06, 0.9, 1), _duration(&"focus")
		)
		&"release": _animate_to(1.0, Vector2.ZERO, Color.WHITE, _release_duration())
		_: reset_motion()


func reset_motion() -> void:
	_kill_active_tween()
	offset_transform_scale = Vector2.ONE
	offset_transform_position = Vector2.ZERO
	self_modulate = Color.WHITE


func _on_mouse_entered() -> void:
	_pointer_inside = true
	if not disabled and not _pressed_visual:
		preview_state(&"hover")


func _on_mouse_exited() -> void:
	_pointer_inside = false
	_pressed_visual = false
	if has_focus() and not disabled:
		_animate_to(_focus_scale(), Vector2.ZERO, Color(1.12, 1.06, 0.9, 1), _release_duration())
	else:
		preview_state(&"release")


func _on_button_down() -> void:
	if disabled:
		return
	_pressed_visual = true
	preview_state(&"press")


func _on_button_up() -> void:
	_pressed_visual = false
	if disabled:
		reset_motion()
	elif _pointer_inside:
		_animate_to(
			_hover_scale(), Vector2(0, -1.5), Color(1.08, 1.04, 0.92, 1), _release_duration()
		)
	elif has_focus():
		_animate_to(
			_focus_scale(), Vector2.ZERO, Color(1.12, 1.06, 0.9, 1), _release_duration()
		)
	else:
		preview_state(&"release")


func _on_focus_entered() -> void:
	if not disabled and not _pointer_inside and not _pressed_visual:
		preview_state(&"focus")


func _on_focus_exited() -> void:
	if not _pointer_inside and not _pressed_visual:
		preview_state(&"release")


func _animate_to(
	target_scale: float,
	target_position: Vector2,
	target_modulate: Color,
	duration: float
) -> void:
	_kill_active_tween()
	if reduced_motion:
		# Accessibility contract: reduced motion keeps spatial transforms neutral.
		# The remaining 80-120 ms colour change preserves interaction feedback.
		offset_transform_scale = Vector2.ONE
		offset_transform_position = Vector2.ZERO
		_active_tween = create_tween()
		_active_tween.set_trans(Tween.TRANS_CUBIC)
		_active_tween.set_ease(Tween.EASE_OUT)
		_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_active_tween.set_ignore_time_scale(true)
		_active_tween.tween_property(self, "self_modulate", target_modulate, clampf(duration, 0.08, 0.12))
		return
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.set_ignore_time_scale(true)
	_active_tween.tween_property(
		self, "offset_transform_scale", Vector2.ONE * target_scale, duration
	)
	_active_tween.tween_property(
		self, "offset_transform_position", target_position, duration
	)
	_active_tween.tween_property(self, "self_modulate", target_modulate, duration)


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _duration(group: StringName) -> float:
	var duration: float = motion_profile.duration_for(group, reduced_motion) if motion_profile != null else 0.12
	return clampf(duration, 0.08, 0.12) if reduced_motion else duration


func _release_duration() -> float:
	return 0.12


func _hover_scale() -> float:
	return motion_profile.hover_scale if motion_profile != null else 1.035


func _pressed_scale() -> float:
	return motion_profile.pressed_scale if motion_profile != null else 0.965


func _focus_scale() -> float:
	return motion_profile.focus_scale if motion_profile != null else 1.015
