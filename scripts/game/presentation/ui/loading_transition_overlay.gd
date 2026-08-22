extends Control

signal retry_requested
signal back_requested
signal transition_hidden

@export var motion_profile: Resource
@export var reduced_motion := false

@onready var backdrop: TextureRect = %Backdrop
@onready var fog_back: TextureRect = %FogBack
@onready var fog_front: TextureRect = %FogFront
@onready var loading_content: Control = %LoadingContent
@onready var seal_motion_root: Control = %SealMotionRoot
@onready var seal_glow: TextureRect = %SealGlow
@onready var progress_ring: TextureRect = %ProgressRing
@onready var status_label: Label = %StatusLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var progress_spark: ColorRect = %ProgressSpark
@onready var percent_label: Label = %PercentLabel
@onready var failure_veil: ColorRect = %FailureVeil
@onready var failure_layer: Control = %FailureLayer
@onready var failure_card: PanelContainer = %FailureCard
@onready var failure_title: Label = %FailureTitle
@onready var failure_message: Label = %FailureMessage
@onready var failure_detail: Label = %FailureDetail
@onready var retry_button: Button = %RetryButton
@onready var back_button: Button = %BackButton

var _transition_state: StringName = &"hidden"
var _entrance_tween: Tween
var _exit_tween: Tween
var _status_tween: Tween
var _failure_tween: Tween
var _failure_impact_tween: Tween
var _ring_tween: Tween
var _glow_tween: Tween
var _fog_back_tween: Tween
var _fog_front_tween: Tween
var _fog_back_origin := Vector2.ZERO
var _fog_front_origin := Vector2.ZERO
var _origins_ready := false


func _ready() -> void:
	resized.connect(_update_layout_pivots)
	_prepare_static_state()
	_cache_origins.call_deferred()


func start_loading(initial_status: String = "正在布设九路战场…") -> void:
	_stop_all_tweens()
	_cache_origins()
	visible = true
	_transition_state = &"loading"
	modulate = Color.WHITE
	loading_content.visible = true
	loading_content.modulate = Color(1, 1, 1, 0)
	failure_layer.visible = false
	failure_veil.visible = false
	set_progress(0.0)
	set_status(initial_status, true)
	_update_layout_pivots()
	backdrop.scale = Vector2(1.015, 1.015) if not reduced_motion else Vector2.ONE
	seal_motion_root.scale = Vector2.ONE
	seal_motion_root.modulate = Color(1, 1, 1, 0)
	_entrance_tween = _new_tween()
	_entrance_tween.set_parallel(true)
	_entrance_tween.tween_property(loading_content, "modulate", Color.WHITE, _duration(&"entrance"))
	_entrance_tween.tween_property(seal_motion_root, "modulate", Color.WHITE, _duration(&"entrance"))
	_entrance_tween.tween_property(backdrop, "scale", Vector2.ONE, _duration(&"entrance") * 1.8)
	_start_ambient_motion()


func set_status(text: String, immediate: bool = false) -> void:
	_kill_tween(_status_tween)
	if immediate or reduced_motion:
		status_label.modulate.a = 1.0
		status_label.text = text
		return
	_status_tween = _new_tween()
	_status_tween.tween_property(status_label, "modulate:a", 0.0, 0.08)
	_status_tween.tween_callback(func() -> void: status_label.text = text)
	_status_tween.tween_property(status_label, "modulate:a", 1.0, 0.18)


func set_progress(value: float) -> void:
	var clamped_value := clampf(value, progress_bar.min_value, progress_bar.max_value)
	progress_bar.value = clamped_value
	percent_label.text = "%d%%" % int(round(clamped_value))
	_update_progress_spark()


func show_failure(
	title: String = "加载失败",
	message: String = "未能抵达战场",
	detail: String = "场景资源响应超时，请重试。"
) -> void:
	if _transition_state == &"failure":
		return
	_transition_state = &"failure"
	_kill_tween(_ring_tween)
	_kill_tween(_failure_tween)
	_kill_tween(_failure_impact_tween)
	failure_title.text = title
	failure_message.text = message
	failure_detail.text = detail
	failure_veil.visible = true
	failure_layer.visible = true
	failure_veil.modulate.a = 0.0
	failure_layer.modulate.a = 0.0
	failure_card.scale = Vector2(0.94, 0.94) if not reduced_motion else Vector2.ONE
	_failure_tween = _new_tween(Tween.TRANS_BACK, Tween.EASE_OUT)
	_failure_tween.set_parallel(true)
	_failure_tween.tween_property(loading_content, "modulate:a", 0.62, _duration(&"feedback"))
	_failure_tween.tween_property(failure_veil, "modulate:a", 1.0, _duration(&"feedback"))
	_failure_tween.tween_property(failure_layer, "modulate:a", 1.0, _duration(&"feedback"))
	_failure_tween.tween_property(failure_card, "scale", Vector2.ONE, _duration(&"feedback"))
	_failure_tween.finished.connect(_play_failure_impact, CONNECT_ONE_SHOT)
	retry_button.grab_focus.call_deferred()


func play_exit() -> Tween:
	_stop_ambient_motion()
	_kill_tween(_exit_tween)
	_transition_state = &"exiting"
	_exit_tween = _new_tween(Tween.TRANS_CUBIC, Tween.EASE_IN)
	_exit_tween.tween_property(self, "modulate:a", 0.0, _duration(&"entrance"))
	_exit_tween.tween_callback(_finish_exit)
	return _exit_tween


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	for button: Node in [retry_button, back_button]:
		if button.has_method("set_reduced_motion"):
			button.call("set_reduced_motion", enabled)
	_stop_ambient_motion()
	_cache_origins()
	progress_ring.rotation = 0.0
	seal_motion_root.scale = Vector2.ONE
	seal_glow.modulate.a = 0.18
	fog_back.position = _fog_back_origin
	fog_front.position = _fog_front_origin
	if _transition_state == &"loading":
		_start_ambient_motion()


func is_reduced_motion_enabled() -> bool:
	return reduced_motion


func get_transition_state() -> StringName:
	return _transition_state


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_back_pressed() -> void:
	back_requested.emit()


func _prepare_static_state() -> void:
	_transition_state = &"hidden"
	failure_layer.visible = false
	failure_veil.visible = false
	status_label.modulate.a = 1.0
	set_progress(0.0)
	_update_layout_pivots()


func _cache_origins() -> void:
	_fog_back_origin = fog_back.position
	_fog_front_origin = fog_front.position
	_origins_ready = true
	_update_layout_pivots()
	_update_progress_spark()


func _update_layout_pivots() -> void:
	backdrop.pivot_offset = backdrop.size * 0.5
	seal_motion_root.pivot_offset = seal_motion_root.size * 0.5
	progress_ring.pivot_offset = progress_ring.size * 0.5
	failure_card.pivot_offset = failure_card.size * 0.5
	_update_progress_spark()


func _update_progress_spark() -> void:
	if not is_instance_valid(progress_bar) or not is_instance_valid(progress_spark):
		return
	var ratio := 0.0
	if progress_bar.max_value > progress_bar.min_value:
		ratio = (progress_bar.value - progress_bar.min_value) / (progress_bar.max_value - progress_bar.min_value)
	var usable_width := maxf(0.0, progress_bar.size.x - progress_spark.size.x)
	progress_spark.position.x = progress_bar.position.x + usable_width * ratio
	progress_spark.position.y = progress_bar.position.y - 4.0


func _start_ambient_motion() -> void:
	_stop_ambient_motion()
	if reduced_motion or not _origins_ready:
		return
	_ring_tween = _new_tween(Tween.TRANS_LINEAR, Tween.EASE_IN_OUT).set_loops()
	progress_ring.rotation = 0.0
	_ring_tween.tween_property(progress_ring, "rotation", TAU, 12.0)

	_glow_tween = _new_tween(Tween.TRANS_SINE, Tween.EASE_IN_OUT).set_loops()
	_glow_tween.tween_property(seal_glow, "modulate:a", 0.22, 1.8)
	_glow_tween.tween_property(seal_glow, "modulate:a", 0.08, 1.8)

	_fog_back_tween = _new_tween(Tween.TRANS_SINE, Tween.EASE_IN_OUT).set_loops()
	_fog_back_tween.tween_property(fog_back, "position:x", _fog_back_origin.x + 46.0, 5.8)
	_fog_back_tween.tween_property(fog_back, "position:x", _fog_back_origin.x - 32.0, 5.8)

	_fog_front_tween = _new_tween(Tween.TRANS_SINE, Tween.EASE_IN_OUT).set_loops()
	_fog_front_tween.tween_property(fog_front, "position:x", _fog_front_origin.x - 58.0, 7.4)
	_fog_front_tween.tween_property(fog_front, "position:x", _fog_front_origin.x + 24.0, 7.4)


func _stop_ambient_motion() -> void:
	for tween: Tween in [_ring_tween, _glow_tween, _fog_back_tween, _fog_front_tween]:
		_kill_tween(tween)
	_ring_tween = null
	_glow_tween = null
	_fog_back_tween = null
	_fog_front_tween = null


func _play_failure_impact() -> void:
	if reduced_motion or _transition_state != &"failure":
		return
	_kill_tween(_failure_impact_tween)
	_failure_impact_tween = _new_tween(Tween.TRANS_BACK, Tween.EASE_OUT)
	_failure_impact_tween.tween_property(failure_card, "scale", Vector2(1.012, 1.012), 0.07)
	_failure_impact_tween.tween_property(failure_card, "scale", Vector2.ONE, 0.12)


func _finish_exit() -> void:
	visible = false
	_transition_state = &"hidden"
	transition_hidden.emit()


func _stop_all_tweens() -> void:
	for tween: Tween in [_entrance_tween, _exit_tween, _status_tween, _failure_tween, _failure_impact_tween]:
		_kill_tween(tween)
	_entrance_tween = null
	_exit_tween = null
	_status_tween = null
	_failure_tween = null
	_failure_impact_tween = null
	_stop_ambient_motion()


func _new_tween(
	transition: Tween.TransitionType = Tween.TRANS_CUBIC,
	ease: Tween.EaseType = Tween.EASE_OUT
) -> Tween:
	var tween := create_tween()
	tween.set_trans(transition)
	tween.set_ease(ease)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	return tween


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _duration(group: StringName) -> float:
	return motion_profile.duration_for(group, reduced_motion) if motion_profile != null else 0.24
