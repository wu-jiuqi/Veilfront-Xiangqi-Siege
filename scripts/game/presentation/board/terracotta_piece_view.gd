extends Node2D

@export var piece_textures: Dictionary = {}

@export_group("Piece Sizing")
@export_range(0.5, 1.5, 0.01) var base_width_cell_ratio: float = 0.88
@export_range(0.5, 2.0, 0.01) var base_height_cell_ratio: float = 0.88
@export_range(0.5, 1.0, 0.01) var board_safe_cell_ratio: float = 0.84
@export var piece_scale_multipliers: Dictionary = {}


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
