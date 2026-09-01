class_name UiMotionButton
extends Button

## Semantic Button shell used by all formal screens.
## The Button root owns input, focus, text and accessibility. Every decorative
## layer is authored in ui_motion_button.tscn and ignores input. Motion is
## restricted to the visual subtree so Containers keep a stable layout rect.

@export var motion_profile: Resource
@export var reduced_motion := false
@export var semantic_role: StringName = &"primary"
@export_group("Visual Assets")
@export var normal_surface: Texture2D
@export var hover_surface: Texture2D
@export var pressed_surface: Texture2D
@export var disabled_surface: Texture2D
@export var art_texture: Texture2D
@export var hover_art_texture: Texture2D
@export var pressed_art_texture: Texture2D
@export var disabled_art_texture: Texture2D
@export var selected_art_texture: Texture2D
@export var semantic_mark_override := ""
@export var show_semantic_mark := true
@export var show_label := true

@onready var _visual_root := %VisualRoot as Control
@onready var _shadow := %Shadow as Panel
@onready var _surface := %Surface as NinePatchRect
@onready var _art_layer := %ArtLayer as TextureRect
@onready var _focus_frame := %FocusFrame as Panel
@onready var _icon_layer := %Icon as TextureRect
@onready var _button_label := %ButtonLabel as Label
@onready var _semantic_mark := %SemanticMark as Label

var _active_tween: Tween
var _pointer_inside := false
var _pressed_visual := false
var _visual_disabled := false
var _sync_queued := false
var _cached_text := ""
var _cached_icon: Texture2D
var _cached_disabled := false


func _ready() -> void:
	offset_transform_enabled = true
	offset_transform_visual_only = true
	offset_transform_pivot = Vector2.ZERO
	offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	_visual_root.offset_transform_enabled = true
	_visual_root.offset_transform_visual_only = true
	_visual_root.offset_transform_pivot = Vector2.ZERO
	_visual_root.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	sync_visual_state()


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAW or not is_node_ready() or _sync_queued:
		return
	if text == _cached_text and icon == _cached_icon and disabled == _cached_disabled:
		return
	_sync_queued = true
	call_deferred("_flush_visual_sync")


func sync_visual_state() -> void:
	if not is_node_ready():
		return
	_sync_queued = false
	_cached_text = text
	_cached_icon = icon
	_cached_disabled = disabled
	_visual_disabled = disabled
	_button_label.text = text
	_button_label.visible = show_label
	_button_label.horizontal_alignment = alignment
	_button_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if clip_text else TextServer.OVERRUN_NO_TRIMMING
	var semantic_font := get_theme_font(&"font")
	if semantic_font != null:
		_button_label.add_theme_font_override(&"font", semantic_font)
		_semantic_mark.add_theme_font_override(&"font", semantic_font)
	var semantic_font_size := get_theme_font_size(&"font_size")
	if semantic_font_size > 0:
		_button_label.add_theme_font_size_override(&"font_size", semantic_font_size)
		_semantic_mark.add_theme_font_size_override(&"font_size", semantic_font_size)
	_icon_layer.texture = icon
	_icon_layer.visible = icon != null
	_semantic_mark.text = semantic_mark_override if not semantic_mark_override.is_empty() else _role_mark()
	_semantic_mark.visible = show_semantic_mark
	_semantic_mark.modulate = _role_text_color()
	_button_label.modulate = _role_text_color()
	if accessibility_name.is_empty():
		accessibility_name = text
	if accessibility_description.is_empty():
		accessibility_description = _role_accessibility_description()
	_apply_visual_state(_resolved_state(), false)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	reset_motion()


func is_reduced_motion_enabled() -> bool:
	return reduced_motion


func is_visual_disabled() -> bool:
	return _visual_disabled


func preview_state(state: StringName) -> void:
	if not is_node_ready():
		# Contract tests and editor tools may preview immediately after instantiate().
		# Keep the semantic shell stable until the authored visual children are ready.
		offset_transform_scale = Vector2.ONE
		offset_transform_position = Vector2.ZERO
		self_modulate = Color.WHITE
		return
	if disabled or state == &"disabled":
		_apply_visual_state(&"disabled", true)
		return
	var target_state := state
	if state == &"release":
		target_state = _resolved_state()
	_apply_visual_state(target_state, true)


func reset_motion() -> void:
	_kill_active_tween()
	offset_transform_scale = Vector2.ONE
	offset_transform_position = Vector2.ZERO
	self_modulate = Color.WHITE
	if not is_node_ready():
		return
	_visual_root.offset_transform_scale = Vector2.ONE
	_visual_root.offset_transform_position = Vector2.ZERO
	_visual_root.self_modulate = Color.WHITE
	_apply_visual_state(_resolved_state(), false)


func _flush_visual_sync() -> void:
	if is_instance_valid(self):
		sync_visual_state()


func _on_mouse_entered() -> void:
	_pointer_inside = true
	if not disabled and not _pressed_visual:
		preview_state(&"hover")


func _on_mouse_exited() -> void:
	_pointer_inside = false
	_pressed_visual = false
	preview_state(&"release")


func _on_button_down() -> void:
	if disabled:
		return
	_pressed_visual = true
	preview_state(&"press")


func _on_button_up() -> void:
	_pressed_visual = false
	preview_state(&"release")


func _on_focus_entered() -> void:
	if not disabled and not _pointer_inside and not _pressed_visual:
		preview_state(&"focus")


func _on_focus_exited() -> void:
	if not _pointer_inside and not _pressed_visual:
		preview_state(&"release")


func _resolved_state() -> StringName:
	if disabled:
		return &"disabled"
	if _pressed_visual:
		return &"press"
	if has_focus() and _pointer_inside:
		return &"focus_hover"
	if has_focus():
		return &"focus"
	if _pointer_inside:
		return &"hover"
	return &"normal"


func _apply_visual_state(state: StringName, animate: bool) -> void:
	_visual_disabled = state == &"disabled"
	_surface.texture = _texture_for_state(state)
	_art_layer.texture = _art_texture_for_state(state)
	_art_layer.visible = _art_layer.texture != null
	var focus_visible := state == &"focus" or state == &"focus_hover"
	var target_scale := 1.0
	var target_position := Vector2.ZERO
	match state:
		&"hover", &"focus_hover":
			target_scale = _hover_scale()
			target_position = Vector2(0.0, -1.5)
		&"press":
			target_scale = _pressed_scale()
			target_position = Vector2(0.0, 1.0)
		&"focus":
			target_scale = _focus_scale()
	var target_surface_modulate := _surface_modulate_for_state(state)
	var target_text_modulate := _text_modulate_for_state(state)
	if not animate:
		_kill_active_tween()
		_visual_root.offset_transform_scale = Vector2.ONE if reduced_motion else Vector2.ONE * target_scale
		_visual_root.offset_transform_position = Vector2.ZERO if reduced_motion else target_position
		_surface.self_modulate = target_surface_modulate
		_art_layer.self_modulate = target_surface_modulate
		_button_label.self_modulate = target_text_modulate
		_semantic_mark.self_modulate = target_text_modulate
		_focus_frame.self_modulate = Color(1, 1, 1, 1 if focus_visible else 0)
		_shadow.self_modulate = Color(1, 1, 1, 0.28 if state != &"disabled" else 0.12)
		return
	_animate_to(
		target_scale,
		target_position,
		target_surface_modulate,
		target_text_modulate,
		1.0 if focus_visible else 0.0,
		_duration_for_state(state)
	)


func _animate_to(
	target_scale: float,
	target_position: Vector2,
	target_surface_modulate: Color,
	target_text_modulate: Color,
	target_focus_alpha: float,
	duration: float
) -> void:
	_kill_active_tween()
	offset_transform_scale = Vector2.ONE
	offset_transform_position = Vector2.ZERO
	self_modulate = Color.WHITE
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.set_ignore_time_scale(true)
	if reduced_motion:
		_visual_root.offset_transform_scale = Vector2.ONE
		_visual_root.offset_transform_position = Vector2.ZERO
	else:
		_active_tween.tween_property(
			_visual_root, "offset_transform_scale", Vector2.ONE * target_scale, duration
		)
		_active_tween.tween_property(
			_visual_root, "offset_transform_position", target_position, duration
		)
	_active_tween.tween_property(_surface, "self_modulate", target_surface_modulate, duration)
	_active_tween.tween_property(_art_layer, "self_modulate", target_surface_modulate, duration)
	_active_tween.tween_property(_button_label, "self_modulate", target_text_modulate, duration)
	_active_tween.tween_property(_semantic_mark, "self_modulate", target_text_modulate, duration)
	_active_tween.tween_property(_focus_frame, "self_modulate:a", target_focus_alpha, duration)


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _texture_for_state(state: StringName) -> Texture2D:
	match state:
		&"disabled": return disabled_surface if disabled_surface != null else normal_surface
		&"press": return pressed_surface if pressed_surface != null else normal_surface
		&"hover", &"focus", &"focus_hover": return hover_surface if hover_surface != null else normal_surface
		_: return normal_surface


func _art_texture_for_state(state: StringName) -> Texture2D:
	var resting_art := selected_art_texture if toggle_mode and button_pressed and selected_art_texture != null else art_texture
	match state:
		&"disabled": return disabled_art_texture if disabled_art_texture != null else resting_art
		&"press": return pressed_art_texture if pressed_art_texture != null else resting_art
		&"hover", &"focus", &"focus_hover": return hover_art_texture if hover_art_texture != null else resting_art
		_: return resting_art


func _surface_modulate_for_state(state: StringName) -> Color:
	var role_color := _role_surface_color()
	match state:
		&"disabled": return role_color * Color(0.48, 0.48, 0.46, 0.72)
		&"press": return role_color * Color(0.84, 0.81, 0.72, 1)
		&"hover", &"focus", &"focus_hover": return role_color * Color(1.08, 1.04, 0.92, 1)
		_: return role_color


func _text_modulate_for_state(state: StringName) -> Color:
	return Color(0.56, 0.55, 0.51, 0.82) if state == &"disabled" else Color.WHITE


func _duration_for_state(state: StringName) -> float:
	match state:
		&"press": return _duration(&"press")
		&"focus", &"focus_hover": return _duration(&"focus")
		&"hover": return _duration(&"hover")
		_: return _release_duration()


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


func _role_surface_color() -> Color:
	match semantic_role:
		&"secondary": return Color(0.72, 0.79, 0.75, 1)
		&"danger": return Color(0.73, 0.31, 0.24, 1)
		&"confirm": return Color(0.95, 0.73, 0.32, 1)
		_: return Color.WHITE


func _role_text_color() -> Color:
	return Color(0.15, 0.105, 0.045, 1) if semantic_role == &"confirm" else Color(0.91, 0.87, 0.77, 1)


func _role_mark() -> String:
	match semantic_role:
		&"secondary": return "◇"
		&"danger": return "!"
		&"confirm": return "✓"
		_: return "◆"


func _role_accessibility_description() -> String:
	match semantic_role:
		&"secondary": return "次要操作"
		&"danger": return "危险操作"
		&"confirm": return "确认操作"
		_: return "主要操作"
