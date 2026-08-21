extends Node2D

@export var piece_textures: Dictionary = {}

func configure_piece(piece: Dictionary, cell_size: Vector2) -> void:
	var shadow: Sprite2D = $Shadow
	var artwork: Sprite2D = $Artwork
	var side := str(piece.get("side", ""))
	var piece_type := _canonical_piece_type(str(piece.get("piece_type", "")))
	var texture: Texture2D = piece_textures.get("%s:%s" % [side, piece_type]) as Texture2D
	artwork.texture = texture
	visible = texture != null
	if texture == null:
		return
	var texture_size := texture.get_size()
	var target_width: float = cell_size.x * 0.88
	var target_height: float = cell_size.y * 1.32
	var fit_scale: float = minf(
		target_width / maxf(texture_size.x, 1.0),
		target_height / maxf(texture_size.y, 1.0)
	)
	artwork.scale = Vector2.ONE * fit_scale
	artwork.position = Vector2(0.0, -cell_size.y * 0.34)
	var base_scale: float = cell_size.x / 128.0
	shadow.position = Vector2(0.0, cell_size.y * 0.08)
	shadow.scale = Vector2(0.3, 0.2) * base_scale


func _canonical_piece_type(piece_type: String) -> String:
	return {
		"rook": "chariot",
		"horse": "cavalry",
		"elephant": "minister",
		"advisor": "guard",
		"cannon": "trebuchet",
		"pawn": "infantry",
	}.get(piece_type, piece_type)
