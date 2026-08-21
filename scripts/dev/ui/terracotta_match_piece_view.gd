extends Node2D

@export var piece_textures: Dictionary = {}

@export_group("Piece Sizing")
@export_range(0.5, 1.5, 0.01) var base_width_cell_ratio: float = 0.88
@export_range(0.5, 2.0, 0.01) var base_height_cell_ratio: float = 1.32
@export var piece_scale_multipliers: Dictionary = {}


func configure_piece(piece: Dictionary, cell_size: Vector2) -> void:
	var shadow: Sprite2D = $Shadow
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
	# 棋子节点本身位于棋盘交点；把立绘底边锚到该交点，避免不同宽高素材
	# 因统一中心偏移而出现脚底落点不一致。
	artwork.position = Vector2(0.0, -texture_size.y * fit_scale * 0.5)
	var base_scale: float = cell_size.x / 128.0
	shadow.position = Vector2(0.0, cell_size.y * 0.08)
	shadow.scale = Vector2(0.3, 0.2) * base_scale * lerpf(1.0, piece_scale, 0.5)


func _canonical_piece_type(piece_type: String) -> String:
	return {
		"rook": "chariot",
		"horse": "cavalry",
		"elephant": "minister",
		"advisor": "guard",
		"cannon": "trebuchet",
		"pawn": "infantry",
	}.get(piece_type, piece_type)
