extends Node2D

@export var piece_textures: Dictionary = {}

@export_group("Piece Sizing")
@export_range(0.5, 1.5, 0.01) var base_width_cell_ratio: float = 0.88
@export_range(0.5, 2.0, 0.01) var base_height_cell_ratio: float = 1.32
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
	artwork.scale = Vector2.ONE * fit_scale
	# 棋子根节点固定在权威交点，立绘底边对齐该点，避免不同素材高度造成漂移。
	artwork.position = Vector2(0.0, -texture_size.y * fit_scale * 0.5)
	var base_scale: float = cell_size.x / 128.0
	shadow.position = Vector2(0.0, cell_size.y * 0.08)
	shadow.scale = Vector2.ONE * base_scale * lerpf(1.0, piece_scale, 0.5)


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
