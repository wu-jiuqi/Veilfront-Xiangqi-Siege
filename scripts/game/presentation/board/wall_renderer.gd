extends Node2D

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

@export var wall_scene: PackedScene

var _rendered_count: int = 0
var _rendered_wall_count: int = 0
var _rendered_art_paths: Array[String] = []


func render(walls: Array, side: String, cell_size: Vector2) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_rendered_count = 0
	_rendered_wall_count = 0
	_rendered_art_paths.clear()
	if wall_scene == null:
		return
	for wall: Dictionary in walls:
		var wall_side: String = str(wall.get("side", ""))
		var authority_y: int = 4 if wall_side == "red" else 21
		var view: Node2D = wall_scene.instantiate() as Node2D
		view.position = Mapper.authority_to_world(Vector2i(5, authority_y), side, cell_size)
		view.set_meta("authority_wall_y", authority_y)
		if view.has_method("configure_wall"):
			view.call("configure_wall", wall, cell_size, wall_side == side)
		add_child(view)
		var artwork: Sprite2D = view.get_node_or_null("Artwork") as Sprite2D
		if artwork != null and artwork.texture != null:
			_rendered_art_paths.append(artwork.texture.resource_path)
		_rendered_wall_count += 1
		# Preserve the existing public segment metric: one wall spans all nine files.
		_rendered_count += 9


func get_rendered_count() -> int:
	return _rendered_count


func get_rendered_wall_count() -> int:
	return _rendered_wall_count


func get_rendered_art_paths() -> Array[String]:
	return _rendered_art_paths.duplicate()
