class_name IncenseTurnClock
extends Control

signal timed_out(expected_action_index: int)
signal round_changed(current_round: int, chinese_round: String)

const MAX_INCENSE_HEIGHT_RATIO: float = 1.0
const EMBER_SIZE := Vector2(18.0, 14.0)
const SMOKE_SOURCE_VISIBLE_LENGTH: float = 330.0
const SMOKE_CROSS_SCALE: float = 0.18
const MIN_SMOKE_LENGTH: float = 56.0
const TIMER_SMOKE_TARGET_OFFSET := Vector2(32.0, -33.28)
const SCATTER_OUT_SECONDS: float = 0.24
const GATHER_IN_SECONDS: float = 0.34
const ROUND_TWEEN_SECONDS: float = 0.48
const CHINESE_DIGITS: PackedStringArray = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

@export_range(1.0, 600.0, 1.0) var turn_duration_seconds: float = 60.0
@export_range(1, 99, 1) var maximum_rounds: int = 50
@export var reduced_motion: bool = false

@onready var _timer_slot: Control = %TimerIncenseSlot
@onready var _stand_slot: Control = %IncenseStandSlot
@onready var _stand_base_art: TextureRect = %IncenseStandBaseArt
@onready var _stand_left_head: TextureRect = %IncenseStandLeftHead
@onready var _stand_right_head: TextureRect = %IncenseStandRightHead
@onready var _timer_clip: Control = %TimerBodyClip
@onready var _timer_body: TextureRect = %TimerBody
@onready var _timer_ember: TextureRect = %TimerEmber
@onready var _timer_smoke_visual: Node2D = %TimerSmokeVisual
@onready var _timer_smoke_frame: Sprite2D = %TimerSmokeFrame
@onready var _timer_smoke_animation: AnimationPlayer = %TimerSmokeAnimationPlayer
@onready var _round_slot: Control = %RoundIncenseSlot
@onready var _round_clip: Control = %RoundBodyClip
@onready var _round_body: TextureRect = %RoundBody
@onready var _round_ember: TextureRect = %RoundEmber
@onready var _round_display_slot: Control = %RoundDisplaySlot
@onready var _smoke_visual: Node2D = %SmokeVisual
@onready var _smoke_frame: Sprite2D = %SmokeFrame
@onready var _smoke_number: Label = %SmokeNumber
@onready var _smoke_animation: AnimationPlayer = %SmokeAnimationPlayer
@onready var _number_float_animation: AnimationPlayer = %NumberFloatAnimationPlayer

var _active_action_index: int = -1
var _remaining_seconds: float = 60.0
var _timer_running: bool = false
var _timeout_emitted: bool = false
var _current_round: int = 1
var _displayed_round: int = 0
var _round_progress: float = 0.0
var _round_tween: Tween
var _digit_tween: Tween
var _smoke_material: ShaderMaterial


func _ready() -> void:
	_smoke_material = _smoke_number.material as ShaderMaterial
	_remaining_seconds = turn_duration_seconds
	_set_scatter(0.0)
	_set_timer_ratio(1.0)
	_set_round_progress(0.0)
	_apply_round_text(1)
	set_reduced_motion(reduced_motion)
	set_process(false)
	call_deferred("refresh_layout")


func _process(delta: float) -> void:
	if not _timer_running:
		return
	_remaining_seconds = maxf(0.0, _remaining_seconds - delta)
	_set_timer_ratio(_remaining_seconds / maxf(turn_duration_seconds, 0.001))
	if _remaining_seconds <= 0.0 and not _timeout_emitted:
		_timeout_emitted = true
		_timer_running = false
		set_process(false)
		timed_out.emit(_active_action_index)


func sync_player_view(view: Dictionary, timeout_enabled: bool) -> void:
	var round_number := maxi(1, int(view.get("full_round_index", 1)))
	var round_limit := maxi(1, int(view.get("round_limit_public", maximum_rounds)))
	set_round(round_number, round_limit, true)

	var action_index := int(view.get("action_index", -1))
	var is_local_turn := not bool(view.get("terminal", false)) \
		and str(view.get("active_side", "")) == str(view.get("viewer_side", ""))
	if action_index != _active_action_index:
		_active_action_index = action_index
		_remaining_seconds = turn_duration_seconds
		_timeout_emitted = false
		_set_timer_ratio(1.0)
	_timer_running = timeout_enabled and is_local_turn and not _timeout_emitted
	set_process(_timer_running)


func set_round(round_number: int, round_limit: int = 50, animate: bool = true) -> void:
	maximum_rounds = maxi(1, round_limit)
	_current_round = clampi(round_number, 1, maximum_rounds)
	var target_progress := float(_current_round) / float(maximum_rounds)
	if not is_node_ready():
		_round_progress = target_progress
		return
	if not animate or reduced_motion:
		_kill_round_tween()
		_kill_digit_tween()
		_set_round_progress(target_progress)
		_apply_round_text(_current_round)
		_set_scatter(0.0)
	else:
		_animate_round_progress(target_progress)
		if _displayed_round != _current_round:
			_animate_round_text(_current_round)
	round_changed.emit(_current_round, chinese_number(_current_round))


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if not is_node_ready():
		return
	if reduced_motion:
		_kill_round_tween()
		_kill_digit_tween()
		_set_round_progress(float(_current_round) / float(maximum_rounds))
		_apply_round_text(_current_round)
		_set_scatter(0.0)
		_smoke_animation.pause()
		_timer_smoke_animation.pause()
		_number_float_animation.pause()
	else:
		_smoke_animation.play(&"smoke_loop")
		_timer_smoke_animation.play(&"smoke_loop")
		_number_float_animation.play(&"number_float")


func refresh_layout() -> void:
	if not is_node_ready():
		return
	var vertical_scale := _stand_slot.size.y / 40.0
	var base_height := _stand_slot.size.x / (1774.0 / 124.0)
	_stand_base_art.position = Vector2(0.0, _stand_slot.size.y - base_height)
	_stand_base_art.size = Vector2(_stand_slot.size.x, base_height)
	var head_size := Vector2(180.0, 164.4) * vertical_scale
	var left_socket_offset := head_size.x * (138.0 / 300.0)
	var right_socket_offset := head_size.x * (162.0 / 300.0)
	var left_target_x := _timer_slot.position.x + _timer_slot.size.x * 0.5 - _stand_slot.position.x
	var right_target_x := _round_slot.position.x + _round_slot.size.x * 0.5 - _stand_slot.position.x
	_stand_left_head.position = Vector2(
		left_target_x - left_socket_offset,
		_stand_slot.size.y - head_size.y
	)
	_stand_left_head.size = head_size
	_stand_right_head.position = Vector2(
		right_target_x - right_socket_offset,
		_stand_slot.size.y - head_size.y
	)
	_stand_right_head.size = head_size
	_set_timer_ratio(_remaining_seconds / maxf(turn_duration_seconds, 0.001))
	_set_round_progress(_round_progress)


func set_timer_remaining_for_test(seconds: float, running: bool = false) -> void:
	_remaining_seconds = clampf(seconds, 0.0, turn_duration_seconds)
	_timer_running = running
	_timeout_emitted = _remaining_seconds <= 0.0
	set_process(_timer_running)
	if is_node_ready():
		_set_timer_ratio(_remaining_seconds / maxf(turn_duration_seconds, 0.001))


func get_state_snapshot() -> Dictionary:
	return {
		"action_index": _active_action_index,
		"remaining_seconds": _remaining_seconds,
		"turn_duration_seconds": turn_duration_seconds,
		"timer_ratio": _remaining_seconds / maxf(turn_duration_seconds, 0.001),
		"timer_running": _timer_running,
		"timeout_emitted": _timeout_emitted,
		"current_round": _current_round,
		"maximum_rounds": maximum_rounds,
		"round_progress": _round_progress,
		"round_remaining_ratio": 1.0 - _round_progress,
		"chinese_round": _smoke_number.text,
		"smoke_length": _current_smoke_length(),
		"smoke_frame_count": _smoke_frame.hframes * _smoke_frame.vframes,
		"smoke_animation": _smoke_animation.current_animation,
		"timer_smoke_length": _current_timer_smoke_length(),
		"timer_smoke_frame_count": _timer_smoke_frame.hframes * _timer_smoke_frame.vframes,
		"timer_smoke_animation": _timer_smoke_animation.current_animation,
		"timer_smoke_mirrored": _timer_smoke_visual.scale.y < 0.0,
		"number_float_animation": _number_float_animation.current_animation,
		"scatter": _get_scatter(),
		"timer_behind_stand": _timer_slot.z_index < _stand_slot.z_index,
		"timer_z_index": _timer_slot.z_index,
		"stand_z_index": _stand_slot.z_index,
	}


static func chinese_number(value: int) -> String:
	var normalized := maxi(0, value)
	if normalized < 10:
		return CHINESE_DIGITS[normalized]
	if normalized == 10:
		return "十"
	if normalized < 20:
		return "十%s" % CHINESE_DIGITS[normalized % 10]
	if normalized < 100:
		var tens := floori(float(normalized) / 10.0)
		var ones := normalized % 10
		return "%s十%s" % [CHINESE_DIGITS[tens], "" if ones == 0 else CHINESE_DIGITS[ones]]
	return str(normalized)


func _set_timer_ratio(value: float) -> void:
	var remaining_ratio := clampf(value, 0.0, MAX_INCENSE_HEIGHT_RATIO)
	_apply_vertical_incense(
		_timer_slot,
		_timer_clip,
		_timer_body,
		_timer_ember,
		remaining_ratio
	)
	_update_timer_smoke(remaining_ratio)


func _set_round_progress(value: float) -> void:
	_round_progress = clampf(value, 0.0, 1.0)
	_apply_vertical_incense(
		_round_slot,
		_round_clip,
		_round_body,
		_round_ember,
		1.0 - _round_progress
	)
	_update_smoke_bridge()


func _apply_vertical_incense(
	slot: Control,
	clip: Control,
	body: TextureRect,
	ember: TextureRect,
	remaining_ratio: float
) -> void:
	var full_size := slot.size
	if full_size.x <= 0.0 or full_size.y <= 0.0:
		return
	var visible_height := full_size.y * clampf(remaining_ratio, 0.0, 1.0)
	var clipped_top := full_size.y - visible_height
	clip.position = Vector2(0.0, clipped_top)
	clip.size = Vector2(full_size.x, visible_height)
	clip.visible = visible_height > 0.05
	body.position = Vector2(0.0, -clipped_top)
	body.size = full_size
	ember.position = Vector2((full_size.x - EMBER_SIZE.x) * 0.5, clipped_top - EMBER_SIZE.y * 0.55)
	ember.size = EMBER_SIZE
	var ember_color := ember.modulate
	ember_color.a = smoothstep(0.0, 0.04, remaining_ratio)
	ember.modulate = ember_color


func _update_smoke_bridge() -> void:
	if not is_instance_valid(_smoke_visual) or _round_slot.size.y <= 0.0:
		return
	var remaining_ratio := 1.0 - _round_progress
	var source := _round_slot.position + Vector2(
		_round_slot.size.x * 0.5,
		_round_slot.size.y * (1.0 - remaining_ratio)
	)
	var target := _round_display_slot.position + Vector2(
		_round_display_slot.size.x * 0.5,
		_round_display_slot.size.y * 0.82
	)
	var bridge := target - source
	var bridge_length := maxf(MIN_SMOKE_LENGTH, bridge.length())
	_smoke_visual.position = source
	_smoke_visual.rotation = bridge.angle()
	_smoke_visual.scale = Vector2(bridge_length / SMOKE_SOURCE_VISIBLE_LENGTH, SMOKE_CROSS_SCALE)
	var smoke_color := _smoke_visual.modulate
	smoke_color.a = lerpf(0.76, 0.96, _round_progress)
	_smoke_visual.modulate = smoke_color


func _update_timer_smoke(remaining_ratio: float) -> void:
	if not is_instance_valid(_timer_smoke_visual) or _timer_slot.size.y <= 0.0:
		return
	var source := _timer_slot.position + Vector2(
		_timer_slot.size.x * 0.5,
		_timer_slot.size.y * (1.0 - clampf(remaining_ratio, 0.0, 1.0))
	)
	var target := _timer_slot.position + Vector2(
		_timer_slot.size.x * 0.5,
		0.0
	) + TIMER_SMOKE_TARGET_OFFSET
	var bridge := target - source
	var bridge_length := maxf(MIN_SMOKE_LENGTH, bridge.length())
	_timer_smoke_visual.position = source
	_timer_smoke_visual.rotation = bridge.angle()
	_timer_smoke_visual.scale = Vector2(
		bridge_length / SMOKE_SOURCE_VISIBLE_LENGTH,
		-SMOKE_CROSS_SCALE
	)
	var smoke_color := _timer_smoke_visual.modulate
	smoke_color.a = lerpf(0.76, 0.96, 1.0 - remaining_ratio)
	_timer_smoke_visual.modulate = smoke_color


func _current_timer_smoke_length() -> float:
	if not is_instance_valid(_timer_slot):
		return 0.0
	var remaining_ratio := _remaining_seconds / maxf(turn_duration_seconds, 0.001)
	var source := _timer_slot.position + Vector2(
		_timer_slot.size.x * 0.5,
		_timer_slot.size.y * (1.0 - clampf(remaining_ratio, 0.0, 1.0))
	)
	var target := _timer_slot.position + Vector2(
		_timer_slot.size.x * 0.5,
		0.0
	) + TIMER_SMOKE_TARGET_OFFSET
	return maxf(MIN_SMOKE_LENGTH, source.distance_to(target))


func _current_smoke_length() -> float:
	if not is_instance_valid(_round_slot) or not is_instance_valid(_round_display_slot):
		return 0.0
	var source := _round_slot.position + Vector2(
		_round_slot.size.x * 0.5,
		_round_slot.size.y * _round_progress
	)
	var target := _round_display_slot.position + Vector2(
		_round_display_slot.size.x * 0.5,
		_round_display_slot.size.y * 0.82
	)
	return maxf(MIN_SMOKE_LENGTH, source.distance_to(target))


func _animate_round_progress(target_progress: float) -> void:
	_kill_round_tween()
	_round_tween = create_tween()
	_round_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_round_tween.tween_method(_set_round_progress, _round_progress, target_progress, ROUND_TWEEN_SECONDS)


func _animate_round_text(round_number: int) -> void:
	_kill_digit_tween()
	_digit_tween = create_tween()
	_digit_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_digit_tween.tween_method(_set_scatter, _get_scatter(), 1.0, SCATTER_OUT_SECONDS)
	_digit_tween.tween_callback(_apply_round_text.bind(round_number))
	_digit_tween.tween_method(_set_scatter, 1.0, 0.0, GATHER_IN_SECONDS)


func _apply_round_text(round_number: int) -> void:
	_displayed_round = round_number
	_smoke_number.text = chinese_number(round_number)
	_smoke_number.tooltip_text = "第%s回合，共%s回合" % [
		chinese_number(round_number), chinese_number(maximum_rounds),
	]


func _set_scatter(value: float) -> void:
	if _smoke_material != null:
		_smoke_material.set_shader_parameter(&"scatter", clampf(value, 0.0, 1.0))


func _get_scatter() -> float:
	if _smoke_material == null:
		return 0.0
	return float(_smoke_material.get_shader_parameter(&"scatter"))


func _kill_round_tween() -> void:
	if _round_tween != null and _round_tween.is_valid():
		_round_tween.kill()
	_round_tween = null


func _kill_digit_tween() -> void:
	if _digit_tween != null and _digit_tween.is_valid():
		_digit_tween.kill()
	_digit_tween = null
