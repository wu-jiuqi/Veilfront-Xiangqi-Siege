class_name TurnProgressIncense
extends Control

signal turn_changed(current_turn: int, chinese_turn: String)

const BODY_LEFT: float = 62.0
const BODY_TOP: float = 16.0
const BODY_HEIGHT: float = 15.0
const MAX_BODY_WIDTH: float = 330.0
const EMBER_SIZE := Vector2(20.0, 16.0)
const SMOKE_BASE_Y: float = 13.0
const SMOKE_CONNECT_X: float = 425.0
const SMOKE_SOURCE_VISIBLE_WIDTH: float = 330.0
const SMOKE_VERTICAL_SCALE: float = 0.24
const MIN_SMOKE_LENGTH: float = 72.0
const PROGRESS_TWEEN_SECONDS: float = 0.48
const SCATTER_OUT_SECONDS: float = 0.24
const GATHER_IN_SECONDS: float = 0.34
const CHINESE_DIGITS: PackedStringArray = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

@export_range(1, 99, 1) var maximum_turns: int = 50
@export_range(1, 99, 1) var initial_turn: int = 1
@export var reduced_motion: bool = false

@onready var _body_clip: Control = %BodyClip
@onready var _ember: TextureRect = %Ember
@onready var _smoke_visual: Node2D = %SmokeVisual
@onready var _smoke_frame: Sprite2D = %SmokeFrame
@onready var _smoke_number: Label = %SmokeNumber
@onready var _smoke_animation: AnimationPlayer = %SmokeAnimationPlayer
@onready var _number_float_animation: AnimationPlayer = %NumberFloatAnimationPlayer

var _current_turn: int = 0
var _displayed_turn: int = 0
var _visual_progress: float = 0.0
var _progress_tween: Tween
var _digit_tween: Tween
var _smoke_material: ShaderMaterial


func _ready() -> void:
	_smoke_material = _smoke_number.material as ShaderMaterial
	_set_scatter(0.0)
	set_reduced_motion(reduced_motion)
	set_turn(initial_turn, maximum_turns, false)


func set_turn(turn_number: int, round_limit: int = 50, animate: bool = true) -> void:
	var normalized_limit := maxi(1, round_limit)
	var normalized_turn := clampi(turn_number, 1, normalized_limit)
	initial_turn = normalized_turn
	maximum_turns = normalized_limit
	_current_turn = normalized_turn
	if not is_node_ready():
		return

	var target_progress := 1.0 - remaining_ratio_for_turn(normalized_turn, normalized_limit)
	if not animate or reduced_motion:
		_kill_progress_tween()
		_kill_digit_tween()
		_set_visual_progress(target_progress)
		_apply_turn_text(normalized_turn)
		_set_scatter(0.0)
	else:
		_animate_progress_to(target_progress)
		if normalized_turn != _displayed_turn:
			_animate_turn_text(normalized_turn)

	turn_changed.emit(normalized_turn, chinese_number(normalized_turn))


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if not is_node_ready():
		return
	if reduced_motion:
		_kill_progress_tween()
		_kill_digit_tween()
		if _current_turn > 0:
			_set_visual_progress(1.0 - remaining_ratio_for_turn(_current_turn, maximum_turns))
			_apply_turn_text(_current_turn)
			_set_scatter(0.0)
		_smoke_animation.pause()
		_number_float_animation.pause()
	else:
		_smoke_animation.play(&"smoke_loop")
		_number_float_animation.play(&"number_float")


func get_state_snapshot() -> Dictionary:
	var remaining_ratio := 1.0 - _visual_progress
	var body_width := MAX_BODY_WIDTH * remaining_ratio
	var smoke_length := maxf(MIN_SMOKE_LENGTH, SMOKE_CONNECT_X - (BODY_LEFT + body_width))
	return {
		"current_turn": _current_turn,
		"maximum_turns": maximum_turns,
		"displayed_turn": _displayed_turn,
		"chinese_turn": _smoke_number.text,
		"progress": _visual_progress,
		"remaining_ratio": remaining_ratio,
		"body_width": body_width,
		"smoke_length": smoke_length,
		"ember_alpha": _ember.modulate.a,
		"smoke_frame_count": _smoke_frame.hframes * _smoke_frame.vframes,
		"smoke_animation": _smoke_animation.current_animation,
		"number_float_animation": _number_float_animation.current_animation,
		"scatter": _get_scatter(),
	}


static func remaining_ratio_for_turn(turn_number: int, round_limit: int = 50) -> float:
	var normalized_limit := maxi(1, round_limit)
	var normalized_turn := clampi(turn_number, 0, normalized_limit)
	return 1.0 - float(normalized_turn) / float(normalized_limit)


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


func _animate_progress_to(target_progress: float) -> void:
	_kill_progress_tween()
	_progress_tween = create_tween()
	_progress_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_progress_tween.tween_method(_set_visual_progress, _visual_progress, target_progress, PROGRESS_TWEEN_SECONDS)


func _animate_turn_text(turn_number: int) -> void:
	_kill_digit_tween()
	var scatter_from := _get_scatter()
	_digit_tween = create_tween()
	_digit_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_digit_tween.tween_method(_set_scatter, scatter_from, 1.0, SCATTER_OUT_SECONDS)
	_digit_tween.tween_callback(_apply_turn_text.bind(turn_number))
	_digit_tween.tween_method(_set_scatter, 1.0, 0.0, GATHER_IN_SECONDS)


func _set_visual_progress(value: float) -> void:
	_visual_progress = clampf(value, 0.0, 1.0)
	var remaining_ratio := 1.0 - _visual_progress
	var body_width := MAX_BODY_WIDTH * remaining_ratio
	_body_clip.size = Vector2(body_width, BODY_HEIGHT)
	_body_clip.visible = body_width > 0.05

	var ember_left := BODY_LEFT + body_width - EMBER_SIZE.x * 0.5
	_ember.position = Vector2(ember_left, BODY_TOP - 1.0)
	var ember_color := _ember.modulate
	ember_color.a = 1.0 - smoothstep(0.96, 1.0, _visual_progress)
	_ember.modulate = ember_color

	var smoke_origin_x := BODY_LEFT + body_width
	var smoke_length := maxf(MIN_SMOKE_LENGTH, SMOKE_CONNECT_X - smoke_origin_x)
	_smoke_visual.position = Vector2(smoke_origin_x, SMOKE_BASE_Y)
	_smoke_visual.scale = Vector2(smoke_length / SMOKE_SOURCE_VISIBLE_WIDTH, SMOKE_VERTICAL_SCALE)
	var smoke_color := _smoke_visual.modulate
	smoke_color.a = lerpf(0.76, 0.96, _visual_progress)
	_smoke_visual.modulate = smoke_color


func _apply_turn_text(turn_number: int) -> void:
	_displayed_turn = turn_number
	_smoke_number.text = chinese_number(turn_number)
	_smoke_number.tooltip_text = "第%s回合，共%s回合" % [chinese_number(turn_number), chinese_number(maximum_turns)]


func _set_scatter(value: float) -> void:
	if _smoke_material != null:
		_smoke_material.set_shader_parameter(&"scatter", clampf(value, 0.0, 1.0))


func _get_scatter() -> float:
	if _smoke_material == null:
		return 0.0
	return float(_smoke_material.get_shader_parameter(&"scatter"))


func _kill_progress_tween() -> void:
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = null


func _kill_digit_tween() -> void:
	if _digit_tween != null and _digit_tween.is_valid():
		_digit_tween.kill()
	_digit_tween = null
