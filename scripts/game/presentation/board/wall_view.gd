extends Node2D

@export_group("Wall Sizing")
@export_range(7.5, 9.5, 0.01) var width_cell_ratio: float = 8.8
@export_range(1.0, 2.0, 0.01) var height_cell_ratio: float = 1.5


func configure_wall(wall: Dictionary, cell_size: Vector2, near_side: bool) -> void:
	var artwork: Sprite2D = $Artwork
	if artwork.texture == null:
		visible = false
		return
	visible = true
	var texture_size := artwork.texture.get_size()
	var fit_scale := minf(
		cell_size.x * width_cell_ratio / maxf(texture_size.x, 1.0),
		cell_size.y * height_cell_ratio / maxf(texture_size.y, 1.0)
	)
	var status := str(wall.get("status", "INTACT"))
	var height_scale := 1.0
	var alpha := 1.0
	if status == "BREACHED":
		height_scale = 0.58
		alpha = 0.56
	elif status == "REPAIRING":
		height_scale = 0.78
		alpha = 0.82
	artwork.scale = Vector2(fit_scale, fit_scale * height_scale)
	var rendered_height := texture_size.y * artwork.scale.y
	artwork.position = Vector2(
		0.0, -rendered_height * 0.5 if near_side else rendered_height * 0.5
	)
	var wall_side := str(wall.get("side", ""))
	var faction_tint := Color(1.0, 0.82, 0.76, alpha) if wall_side == "red" \
		else Color(0.68, 0.84, 0.75, alpha)
	artwork.modulate = faction_tint
	set_meta("wall_side", wall_side)
	set_meta("wall_status", status)
	set_meta("wall_texture_path", artwork.texture.resource_path)


func get_artwork_path() -> String:
	var artwork: Sprite2D = $Artwork
	return artwork.texture.resource_path if artwork.texture != null else ""
