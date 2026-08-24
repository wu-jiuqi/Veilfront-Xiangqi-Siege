class_name VfxEffectSlot
extends Node2D

@onready var _particles: GPUParticles2D = $Particles
@onready var _callout_label: Label = $CalloutLabel

var _definition: VfxCueDefinition
var _cue: Dictionary = {}
var _elapsed: float = 0.0
var _duration: float = 0.0
var _active: bool = false
var _reduced_motion: bool = false
var _overdraw_points: int = 0
var _review_hold: bool = false


func _ready() -> void:
	visible = false
	set_process(false)


func trigger(cue: Dictionary, definition: VfxCueDefinition) -> void:
	_definition = definition
	_cue = cue.duplicate(true)
	_reduced_motion = str(cue.get("motion_profile", "standard")) == "reduced"
	_duration = definition.duration_reduced if _reduced_motion \
		else definition.duration_standard
	_elapsed = _duration * 0.38 if _review_hold else 0.0
	_active = true
	_overdraw_points = definition.overdraw_points_reduced if _reduced_motion \
		else definition.overdraw_points_standard
	visible = true
	modulate = Color.WHITE
	_configure_particles()
	_configure_callout()
	set_process(true)
	queue_redraw()


func stop_immediately() -> void:
	_particles.emitting = false
	_callout_label.visible = false
	_active = false
	visible = false
	set_process(false)
	_cue.clear()
	_definition = null
	_overdraw_points = 0
	queue_redraw()


func set_review_hold(enabled: bool) -> void:
	_review_hold = enabled
	if enabled and _active and _duration > 0.0:
		_elapsed = _duration * 0.38
		queue_redraw()


func is_active_effect() -> bool:
	return _active


func cue_id() -> String:
	return str(_cue.get("cue_id", ""))


func cue_key() -> String:
	return str(_cue.get("cue_key", ""))


func concurrency_group() -> String:
	return str(_cue.get("concurrency_group", ""))


func priority_rank() -> int:
	return ["low", "normal", "high", "critical"].find(str(_cue.get("priority", "low")))


func overdraw_points() -> int:
	return _overdraw_points if _active else 0


func family() -> String:
	return _definition.family if _definition != null else ""


func effect_snapshot() -> Dictionary:
	return {
		"active": _active,
		"cue_id": cue_id(),
		"cue_key": cue_key(),
		"family": family(),
		"group": concurrency_group(),
		"priority_rank": priority_rank(),
		"overdraw_points": overdraw_points(),
		"reduced_motion": _reduced_motion,
		"particles_emitting": _particles.emitting,
		"particle_amount": _particles.amount,
		"review_hold": _review_hold,
		"callout_text": _callout_label.text if _callout_label.visible else "",
	}


func _process(delta: float) -> void:
	if not _active:
		return
	if _review_hold:
		_update_callout_visual()
		queue_redraw()
		return
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= _duration:
		stop_immediately()
		return
	_update_callout_visual()
	queue_redraw()


func _draw() -> void:
	if not _active or _definition == null or _duration <= 0.0:
		return
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var fade := 1.0 - progress
	var pulse := sin(progress * PI)
	var base := _faction_color(_definition.base_color)
	var accent := _faction_color(_definition.accent_color)
	base.a *= fade
	accent.a *= fade
	var radius: float = _definition.radius
	if _reduced_motion:
		_draw_reduced_family(_definition.family, base, accent, radius, fade)
		return
	match _definition.family:
		"selection":
			draw_arc(Vector2.ZERO, radius * (0.82 + 0.14 * pulse), 0.0, TAU, 48, accent, 4.0)
			draw_arc(Vector2.ZERO, radius * 0.58, -PI * 0.2, PI * (1.2 + eased), 28, base, 2.0)
		"move":
			var travel := Vector2(-radius * (1.2 - eased), radius * 0.22)
			draw_line(travel, Vector2(radius * 0.35, 0.0), base, 8.0)
			draw_line(travel + Vector2(0.0, 11.0), Vector2(radius * 0.1, 8.0), accent, 3.0)
			draw_circle(Vector2(radius * 0.36, 0.0), radius * 0.16 * fade, accent)
		"capture":
			draw_circle(Vector2.ZERO, radius * (0.18 + eased * 0.7), Color(base, 0.16 * fade))
			for index: int in 6:
				var angle := TAU * float(index) / 6.0 + eased * 0.35
				var inner := Vector2.from_angle(angle) * radius * 0.22
				var outer := Vector2.from_angle(angle) * radius * (0.48 + eased * 0.5)
				draw_line(inner, outer, accent, 4.0)
		"callout":
			draw_circle(Vector2(0.0, -radius * 0.78), radius * (0.52 + 0.08 * pulse), Color(base, 0.72 * fade))
			draw_arc(Vector2(0.0, -radius * 0.78), radius * (0.58 + 0.1 * eased), 0.0, TAU, 40, accent, 4.0)
		"bombardment":
			for ring: int in 3:
				var ring_phase := clampf(eased * 1.28 - float(ring) * 0.14, 0.0, 1.0)
				draw_arc(Vector2.ZERO, radius * (0.18 + ring_phase), 0.0, TAU, 56, Color(accent, fade * (0.9 - ring * 0.18)), 5.0 - ring)
			draw_line(Vector2(-radius, 0.0), Vector2(radius, 0.0), Color(base, fade * 0.72), 3.0)
			draw_line(Vector2(0.0, -radius), Vector2(0.0, radius), Color(base, fade * 0.72), 3.0)
		"resurrection":
			for ring: int in 2:
				var ring_radius := radius * (0.34 + eased * (0.36 + 0.18 * ring))
				draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, Color(accent, fade * (0.86 - ring * 0.22)), 4.0 - ring)
			for stroke: int in 5:
				var x := lerpf(-radius * 0.48, radius * 0.48, float(stroke) / 4.0)
				var rise := radius * (0.24 + eased * (0.72 + 0.08 * (stroke % 2)))
				draw_line(Vector2(x, radius * 0.34), Vector2(x * 0.5, radius * 0.34 - rise), Color(base, fade * 0.82), 3.0)
		"wall":
			var half_width := radius * 2.8
			draw_line(Vector2(-half_width, 0.0), Vector2(half_width, 0.0), Color(base, fade * 0.35), 15.0)
			draw_line(Vector2(-half_width * eased, -5.0), Vector2(half_width * eased, -5.0), accent, 4.0)
			for index: int in 9:
				var x := lerpf(-half_width, half_width, float(index) / 8.0)
				draw_circle(Vector2(x, 0.0), 5.0 + 3.0 * pulse, base)
		"flag":
			var diamond := PackedVector2Array([
				Vector2(0.0, -radius * (0.6 + 0.2 * pulse)),
				Vector2(radius * 0.52, 0.0),
				Vector2(0.0, radius * (0.6 + 0.2 * pulse)),
				Vector2(-radius * 0.52, 0.0),
			])
			draw_colored_polygon(diamond, Color(base, fade * 0.24))
			draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), accent, 4.0)
			draw_arc(Vector2.ZERO, radius * (0.7 + eased * 0.32), 0.0, TAU, 40, base, 2.0)
		"terminal":
			draw_circle(Vector2.ZERO, radius, Color(base, 0.13 * fade))
			draw_arc(Vector2.ZERO, radius * (0.72 + 0.18 * eased), 0.0, TAU, 80, Color(accent, 0.62 * fade), 8.0)
			for index: int in 12:
				var angle := TAU * float(index) / 12.0
				draw_line(Vector2.from_angle(angle) * radius * 0.62, Vector2.from_angle(angle) * radius * (0.82 + 0.12 * eased), Color(accent, 0.22 * fade), 4.0)


func _draw_reduced_family(
	family_name: String,
	base: Color,
	accent: Color,
	radius: float,
	fade: float
) -> void:
	match family_name:
		"wall":
			draw_line(Vector2(-radius * 2.8, 0.0), Vector2(radius * 2.8, 0.0), Color(accent, 0.72 * fade), 5.0)
		"terminal":
			draw_circle(Vector2.ZERO, radius, Color(base, 0.10 * fade))
			draw_arc(Vector2.ZERO, radius * 0.78, 0.0, TAU, 64, Color(accent, 0.55 * fade), 6.0)
		"move":
			draw_line(Vector2(-radius * 0.5, 0.0), Vector2(radius * 0.5, 0.0), Color(accent, 0.7 * fade), 5.0)
		"flag":
			var points := PackedVector2Array([
				Vector2(0.0, -radius * 0.55), Vector2(radius * 0.45, 0.0),
				Vector2(0.0, radius * 0.55), Vector2(-radius * 0.45, 0.0), Vector2(0.0, -radius * 0.55),
			])
			draw_polyline(points, Color(accent, 0.7 * fade), 4.0)
		"callout":
			draw_circle(Vector2(0.0, -radius * 0.78), radius * 0.5, Color(base, 0.58 * fade))
			draw_arc(Vector2(0.0, -radius * 0.78), radius * 0.56, 0.0, TAU, 32, Color(accent, 0.72 * fade), 4.0)
		"resurrection":
			draw_arc(Vector2.ZERO, radius * 0.68, 0.0, TAU, 40, Color(accent, 0.72 * fade), 5.0)
			draw_line(Vector2(0.0, radius * 0.34), Vector2(0.0, -radius * 0.52), Color(base, 0.72 * fade), 4.0)
		_:
			draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 40, Color(accent, 0.72 * fade), 5.0)


func _configure_particles() -> void:
	_particles.emitting = false
	var amount: int = _definition.particles_reduced if _reduced_motion \
		else _definition.particles_standard
	_particles.amount = maxi(1, amount)
	_particles.lifetime = minf(_duration, 0.72)
	_particles.texture = _definition.particle_texture
	var material := _particles.process_material as ParticleProcessMaterial
	if material != null:
		material.color = _faction_color(_definition.accent_color)
	if amount <= 0:
		return
	_particles.restart()
	_particles.emitting = true


func _configure_callout() -> void:
	_callout_label.visible = _definition.family == "callout"
	if not _callout_label.visible:
		_callout_label.text = ""
		return
	_callout_label.text = "将" if cue_key() == "vfx.callout.general" else "吃"
	_update_callout_visual()


func _update_callout_visual() -> void:
	if not _callout_label.visible or _duration <= 0.0:
		return
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var rise := 0.0 if _reduced_motion else 18.0 * eased
	_callout_label.position = Vector2(-48.0, -98.0 - rise)
	var pop := 1.0 if _reduced_motion else 0.72 + 0.34 * sin(minf(progress * 2.0, 1.0) * PI * 0.5)
	_callout_label.scale = Vector2.ONE * pop
	_callout_label.modulate = Color(1.0, 1.0, 1.0, 1.0 - progress)


func _faction_color(source: Color) -> Color:
	match str(_cue.get("actor_side_public", "")):
		"red":
			return source.lerp(Color("c6533f"), 0.28)
		"black":
			return source.lerp(Color("4f8b7d"), 0.28)
	return source
