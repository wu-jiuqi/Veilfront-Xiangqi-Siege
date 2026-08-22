extends Node2D

@export var piece_textures: Dictionary = {}

@export_group("Piece Sizing")
@export_range(0.5, 1.5, 0.01) var base_width_cell_ratio: float = 0.88
@export_range(0.5, 2.0, 0.01) var base_height_cell_ratio: float = 0.88
@export_range(0.5, 1.0, 0.01) var board_safe_cell_ratio: float = 0.84
@export var piece_scale_multipliers: Dictionary = {}

const MOVE_DURATION: float = 0.28
const DROP_DURATION: float = 0.34
const CAPTURED_DURATION: float = 0.24
const CAPTURE_WINDUP: float = 0.06

var _motion_tween: Tween
var _effect_tween: Tween
var _selection_tween: Tween
var _animation_kind: String = "idle"


func configure_piece(piece: Dictionary, cell_size: Vector2) -> void:
	var shadow: Polygon2D = $Shadow
	var artwork: Sprite2D = $Artwork
	var side := str(piece.get("side", ""))
	var game_piece_type := str(piece.get("piece_type", ""))
	var piece_type := _canonical_piece_type(game_piece_type)
	var texture: Texture2D = piece_textures.get("%s:%s" % [side, piece_type]) as Texture2D
	artwork.texture = texture
	visible = texture != null
	if texture == null:
		return
	var texture_size := texture.get_size()
	var target_width: float = cell_size.x * base_width_cell_ratio
	var target_height: float = cell_size.y * base_height_cell_ratio
	var fit_scale: float = minf(
		target_width / maxf(texture_size.x, 1.0),
		target_height / maxf(texture_size.y, 1.0)
	)
	var piece_scale: float = maxf(
		float(piece_scale_multipliers.get(game_piece_type, 1.0)), 0.1
	)
	fit_scale *= piece_scale
	# 圆形棋子必须完整落在所属格的安全框内；倍率只能缩小，不能突破安全框。
	var safe_scale: float = minf(
		cell_size.x * board_safe_cell_ratio / maxf(texture_size.x, 1.0),
		cell_size.y * board_safe_cell_ratio / maxf(texture_size.y, 1.0)
	)
	fit_scale = minf(fit_scale, safe_scale)
	artwork.scale = Vector2.ONE * fit_scale
	# 根节点继续固定在权威交点；视觉居中后，顶部第一排不会进入棋盘负坐标。
	artwork.position = Vector2.ZERO
	var base_scale: float = cell_size.x / 128.0
	shadow.position = Vector2(0.0, cell_size.y * 0.08)
	shadow.scale = Vector2.ONE * base_scale * 1.45 * lerpf(1.0, piece_scale, 0.25)


func contains_local_point(local_point: Vector2) -> bool:
	var artwork: Sprite2D = $Artwork
	if not visible or artwork.texture == null:
		return false
	var artwork_point := artwork.transform.affine_inverse() * local_point
	return artwork.get_rect().has_point(artwork_point)


func set_selected(selected: bool) -> void:
	var halo: Line2D = $SelectionHalo
	if halo.visible == selected:
		if not selected or (_selection_tween != null \
		and _selection_tween.is_valid() and _selection_tween.is_running()):
			return
	if _selection_tween != null and _selection_tween.is_valid():
		_selection_tween.kill()
	_selection_tween = null
	halo.visible = selected
	halo.scale = Vector2.ONE
	halo.modulate = Color.WHITE
	if not selected:
		return
	_selection_tween = create_tween().set_loops()
	_selection_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_selection_tween.tween_property(halo, "scale", Vector2.ONE * 1.12, 0.42)
	_selection_tween.parallel().tween_property(halo, "modulate:a", 0.38, 0.42)
	_selection_tween.tween_property(halo, "scale", Vector2.ONE, 0.42)
	_selection_tween.parallel().tween_property(halo, "modulate:a", 1.0, 0.42)


func play_move_to(target: Vector2, captures_piece: bool = false) -> void:
	_cancel_motion_effects()
	_animation_kind = "capture" if captures_piece else "move"
	z_index = 20
	var windup := CAPTURE_WINDUP if captures_piece else 0.0
	_motion_tween = create_tween()
	if windup > 0.0:
		_motion_tween.tween_interval(windup)
	_motion_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "position", target, MOVE_DURATION)
	_effect_tween = create_tween()
	if windup > 0.0:
		_effect_tween.tween_interval(windup)
	_effect_tween.tween_property(self, "scale", Vector2.ONE * 1.06, MOVE_DURATION * 0.42) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_effect_tween.tween_property(self, "scale", Vector2.ONE, MOVE_DURATION * 0.58) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if captures_piece:
		_effect_tween.tween_property(self, "scale", Vector2.ONE * 1.16, 0.07) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_effect_tween.tween_property(self, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var effect_tween := _effect_tween
	effect_tween.finished.connect(func() -> void:
		if _effect_tween == effect_tween:
			_effect_tween = null
			_animation_kind = "idle"
			z_index = 0
			scale = Vector2.ONE
	)


func play_drop(target: Vector2, cell_size: Vector2) -> void:
	_cancel_motion_effects()
	_animation_kind = "land"
	z_index = 20
	position = target - Vector2(0.0, cell_size.y * 0.38)
	scale = Vector2.ONE * 1.22
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.tween_property(self, "position", target, DROP_DURATION) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "scale", Vector2.ONE, DROP_DURATION * 0.82) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "modulate:a", 1.0, DROP_DURATION * 0.42) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion_tween.chain().tween_callback(func() -> void:
		_animation_kind = "idle"
		z_index = 0
		position = target
		scale = Vector2.ONE
		modulate = Color.WHITE
	)


func play_captured(impact_direction: Vector2 = Vector2.UP) -> void:
	_cancel_motion_effects()
	set_selected(false)
	_animation_kind = "captured"
	z_index = 30
	var direction := impact_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.tween_property(
		self, "position", position + direction * 22.0 - Vector2(0.0, 12.0), CAPTURED_DURATION
	)
	_motion_tween.tween_property(self, "scale", Vector2.ONE * 0.18, CAPTURED_DURATION)
	_motion_tween.tween_property(
		self, "rotation", direction.x * 0.34, CAPTURED_DURATION
	)
	_motion_tween.tween_property(self, "modulate:a", 0.0, CAPTURED_DURATION * 0.86)
	_motion_tween.chain().tween_callback(queue_free)


func play_hidden() -> void:
	_cancel_motion_effects()
	set_selected(false)
	_animation_kind = "hidden"
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_motion_tween.tween_property(self, "scale", Vector2.ONE * 0.92, 0.12)
	_motion_tween.chain().tween_callback(queue_free)


func get_animation_snapshot() -> Dictionary:
	return {
		"kind": _animation_kind,
		"selected": bool($SelectionHalo.visible),
		"motion_active": _motion_tween != null \
			and _motion_tween.is_valid() and _motion_tween.is_running(),
		"effect_active": _effect_tween != null \
			and _effect_tween.is_valid() and _effect_tween.is_running(),
	}


func stop_animations() -> void:
	_cancel_motion_effects()
	set_selected(false)
	_animation_kind = "idle"


func _cancel_motion_effects() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	if _effect_tween != null and _effect_tween.is_valid():
		_effect_tween.kill()
	_motion_tween = null
	_effect_tween = null
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE
	z_index = 0


func _canonical_piece_type(piece_type: String) -> String:
	return {
		"rook": "chariot",
		"horse": "cavalry",
		"elephant": "minister",
		"advisor": "guard",
		"cannon": "trebuchet",
		"pawn": "infantry",
		"soldier": "infantry",
	}.get(piece_type, piece_type)
