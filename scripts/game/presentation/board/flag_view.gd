extends Node2D

@export var flag_textures: Dictionary = {}

@export_group("Flag Sizing")
@export_range(0.5, 2.0, 0.01) var base_width_cell_ratio: float = 1.08
@export_range(0.5, 3.0, 0.01) var base_height_cell_ratio: float = 1.9


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
	var target_width: float = cell_size.x * base_width_cell_ratio
	var target_height: float = cell_size.y * base_height_cell_ratio
	var fit_scale: float = minf(
		target_width / maxf(texture_size.x, 1.0),
		target_height / maxf(texture_size.y, 1.0)
	)
	artwork.scale = Vector2.ONE * fit_scale
	# 旗帜根节点固定在权威交点，源图底边对齐交点以保留统一脚底线。
	artwork.position = Vector2(0.0, -texture_size.y * fit_scale * 0.5)
