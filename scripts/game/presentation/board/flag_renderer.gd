extends Node2D

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

@export var flag_scene: PackedScene

var _rendered_count: int = 0
var _first_flag_cell := Vector2i.ZERO
var _rendered_art_paths: Array[String] = []


func render(flags: Array, side: String, cell_size: Vector2) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_rendered_count = 0
	_first_flag_cell = Vector2i.ZERO
	_rendered_art_paths.clear()
	if flag_scene == null:
		return
	for flag: Dictionary in flags:
		if not bool(flag.get("discovered", false)):
			continue
		var cell: Vector2i = Mapper.coordinate_from_variant(flag.get("position", []))
		if not Mapper.is_authority_cell_valid(cell):
			continue
		var view: Node2D = flag_scene.instantiate() as Node2D
		view.position = Mapper.authority_to_world(cell, side, cell_size)
		view.set_meta("flag_id", str(flag.get("id", "")))
		view.set_meta("memory_visible", true)
		if view.has_method("configure_flag"):
			view.call("configure_flag", flag, cell_size)
		var artwork: Sprite2D = view.get_node_or_null("Artwork") as Sprite2D
		if artwork != null and artwork.texture != null:
			_rendered_art_paths.append(artwork.texture.resource_path)
		add_child(view)
		if _first_flag_cell == Vector2i.ZERO:
			_first_flag_cell = cell
		_rendered_count += 1


func get_rendered_count() -> int:
	return _rendered_count


func get_first_flag_cell() -> Vector2i:
	return _first_flag_cell


func get_rendered_art_paths() -> Array[String]:
	return _rendered_art_paths.duplicate()
