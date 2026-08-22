extends Node2D

@export var flag_textures: Dictionary = {}

@export_group("Flag Sizing")
@export_range(0.85, 1.15, 0.01) var diameter_cell_ratio: float = 0.98


func configure_flag(flag: Dictionary, cell_size: Vector2) -> void:
	var artwork: Sprite2D = $Artwork
	var owner := str(flag.get("owner", ""))
	var texture_key := owner if owner in ["red", "black"] else "neutral"
	var texture: Texture2D = flag_textures.get(texture_key) as Texture2D
	artwork.texture = texture
	visible = texture != null
	set_meta("flag_owner", texture_key)
	if texture == null:
		return
	var texture_size := texture.get_size()
	var target_width: float = cell_size.x * diameter_cell_ratio
	var target_height: float = cell_size.y * diameter_cell_ratio
	var fit_scale: float = minf(
		target_width / maxf(texture_size.x, 1.0),
		target_height / maxf(texture_size.y, 1.0)
	)
	artwork.scale = Vector2.ONE * fit_scale
	# 圆旗以权威交点为圆心，直径略大于棋子的单格安全直径。
	artwork.position = Vector2.ZERO
	set_meta("display_diameter", minf(texture_size.x, texture_size.y) * fit_scale)
