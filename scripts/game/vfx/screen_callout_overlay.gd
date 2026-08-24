class_name ScreenCalloutOverlay
extends Control

signal callout_presented(cue_key: String)

const CueContract = preload("res://scripts/game/vfx/vfx_cue.gd")
const CALLOUT_PREFIX: String = "vfx.callout."
const STANDARD_DURATION: float = 1.08
const REDUCED_DURATION: float = 0.62
const STANDARD_INTRO_DURATION: float = 0.22
const STANDARD_FADE_DURATION: float = 0.28
const REDUCED_FADE_DURATION: float = 0.16
const DEDUP_CAPACITY: int = 64

@export var review_hold: bool = false

@onready var _backdrop: ColorRect = $Backdrop
@onready var _band: ColorRect = $CenterBand
@onready var _band_top: ColorRect = $CenterBand/TopEdge
@onready var _band_bottom: ColorRect = $CenterBand/BottomEdge
@onready var _center: Control = $CenterPivot
@onready var _seal: TextureRect = $CenterPivot/Seal
@onready var _callout_label: Label = $CenterPivot/CalloutLabel
@onready var _caption_label: Label = $CenterPivot/CaptionLabel
@onready var _particles: GPUParticles2D = $ScreenBurst

var _animation: Tween
var _active: bool = false
var _cue: Dictionary = {}
var _played_ids: Dictionary = {}
var _played_order: Array[String] = []


func _ready() -> void:
	visible = false
	_particles.emitting = false
	resized.connect(_sync_viewport_center)
	_sync_viewport_center()


func _exit_tree() -> void:
	_stop_animation()
	if is_instance_valid(_particles):
		_particles.emitting = false
	if resized.is_connected(_sync_viewport_center):
		resized.disconnect(_sync_viewport_center)


func play_batch(batch: Dictionary) -> int:
	if not CueContract.is_valid_batch(batch):
		return 0
	var candidates: Array[Dictionary] = []
	for cue_value: Variant in batch.get("cues", []):
		if not cue_value is Dictionary:
			continue
		var cue: Dictionary = cue_value
		var cue_id: String = str(cue.get("cue_id", ""))
		if _is_screen_callout(cue) and not _played_ids.has(cue_id):
			candidates.append(cue)
	if candidates.is_empty():
		return 0
	var selected: Dictionary = candidates[0]
	for cue: Dictionary in candidates:
		_remember(str(cue.get("cue_id", "")))
		if str(cue.get("cue_key", "")) == "vfx.callout.general":
			selected = cue
	trigger(selected)
	return 1


func trigger(cue: Dictionary) -> bool:
	if not CueContract.is_valid(cue) or not _is_screen_callout(cue):
		return false
	_stop_animation()
	_cue = cue.duplicate(true)
	_active = true
	visible = true
	_sync_viewport_center()
	_apply_palette()
	_reset_visual_state()
	if review_hold:
		_apply_review_state()
	else:
		_play_animation()
	callout_presented.emit(str(_cue.get("cue_key", "")))
	return true


func clear_all() -> void:
	_stop_animation()
	_particles.emitting = false
	_active = false
	_cue.clear()
	visible = false
	_played_ids.clear()
	_played_order.clear()


func set_review_hold(enabled: bool) -> void:
	review_hold = enabled
	if enabled and _active:
		_stop_animation()
		_apply_review_state()


func effect_snapshot() -> Dictionary:
	return {
		"active": _active,
		"cue_key": str(_cue.get("cue_key", "")),
		"callout_text": _callout_label.text if _active else "",
		"caption_text": _caption_label.text if _active else "",
		"spatial_mode": str(_cue.get("spatial_mode", "")),
		"screen_center": _center.position + _center.pivot_offset,
		"viewport_size": size,
		"band_width": _band.size.x,
		"label_font_size": _callout_label.get_theme_font_size("font_size"),
		"outline_size": _callout_label.get_theme_constant("outline_size"),
		"backdrop_opacity": _backdrop.color.a,
		"band_height": _band.size.y,
		"particles_emitting": _particles.emitting,
		"motion_profile": str(_cue.get("motion_profile", "")),
		"review_hold": review_hold,
		"dedup_count": _played_ids.size(),
	}


func _play_animation() -> void:
	var reduced: bool = str(_cue.get("motion_profile", "standard")) == "reduced"
	var duration := REDUCED_DURATION if reduced else STANDARD_DURATION
	var fade_duration := REDUCED_FADE_DURATION if reduced else STANDARD_FADE_DURATION
	var fade_delay := duration - fade_duration
	if not reduced:
		_particles.restart()
		_particles.emitting = true
	_animation = create_tween()
	_animation.set_parallel(true)
	_animation.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_animation.set_ignore_time_scale(true)
	_animation.tween_property(_backdrop, "modulate:a", 1.0, 0.1) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animation.tween_property(_band, "modulate:a", 1.0, 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if reduced:
		_center.scale = Vector2.ONE
		_center.rotation = 0.0
	else:
		_animation.tween_property(_center, "scale", Vector2.ONE, STANDARD_INTRO_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_animation.tween_property(_center, "rotation", 0.0, STANDARD_INTRO_DURATION) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_animation.tween_property(_center, "modulate:a", 1.0, 0.1)
	_animation.tween_property(_seal, "rotation", 0.0, 0.34) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_animation.tween_property(_backdrop, "modulate:a", 0.0, fade_duration).set_delay(fade_delay)
	_animation.tween_property(_band, "modulate:a", 0.0, fade_duration).set_delay(fade_delay)
	_animation.tween_property(_center, "modulate:a", 0.0, fade_duration).set_delay(fade_delay)
	_animation.tween_interval(duration)
	_animation.finished.connect(_finish_animation)


func _reset_visual_state() -> void:
	var reduced: bool = str(_cue.get("motion_profile", "standard")) == "reduced"
	_backdrop.modulate.a = 0.0
	_band.modulate.a = 0.0
	_center.modulate.a = 0.0
	_center.scale = Vector2.ONE if reduced else Vector2(2.35, 2.35)
	_center.rotation = 0.0 if reduced else -0.075
	_seal.rotation = 0.0 if reduced else 0.18
	_particles.emitting = false


func _apply_review_state() -> void:
	_backdrop.modulate.a = 1.0
	_band.modulate.a = 1.0
	_center.modulate.a = 1.0
	_center.scale = Vector2.ONE
	_center.rotation = 0.0
	_seal.rotation = 0.0
	_particles.emitting = false


func _apply_palette() -> void:
	var is_general: bool = str(_cue.get("cue_key", "")) == "vfx.callout.general"
	var accent := Color("ffd36b") if is_general else Color("f2c45f")
	var band_color := Color(0.28, 0.025, 0.02, 0.9) if is_general \
		else Color(0.19, 0.045, 0.025, 0.88)
	var outline := Color(0.1, 0.008, 0.006, 1.0)
	_callout_label.text = "将" if is_general else "吃"
	_caption_label.text = "主将告破" if is_general else "斩获敌军"
	_callout_label.add_theme_color_override("font_color", accent)
	_callout_label.add_theme_color_override("font_outline_color", outline)
	_callout_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
	_caption_label.add_theme_color_override("font_color", accent.lightened(0.16))
	_band.color = band_color
	_band_top.color = Color(accent, 0.78)
	_band_bottom.color = Color(accent, 0.5)
	_seal.modulate = Color(accent, 0.82)
	var material := _particles.process_material as ParticleProcessMaterial
	if material != null:
		material.color = Color(accent, 0.92)


func _sync_viewport_center() -> void:
	if not is_instance_valid(_center) or not is_instance_valid(_particles):
		return
	_particles.position = size * 0.5


func _finish_animation() -> void:
	_particles.emitting = false
	_active = false
	_cue.clear()
	visible = false
	_animation = null


func _stop_animation() -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()
	_animation = null


func _is_screen_callout(cue: Dictionary) -> bool:
	return str(cue.get("cue_key", "")).begins_with(CALLOUT_PREFIX) \
		and str(cue.get("spatial_mode", "")) == "global" \
		and (cue.get("position_public", []) as Array).is_empty()


func _remember(cue_id: String) -> void:
	if cue_id.is_empty() or _played_ids.has(cue_id):
		return
	_played_ids[cue_id] = true
	_played_order.append(cue_id)
	while _played_order.size() > DEDUP_CAPACITY:
		var expired: String = _played_order.pop_front()
		_played_ids.erase(expired)
