extends Node2D

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

@export var ghost_scene: PackedScene

var _rendered_count: int = 0


func render(ghosts: Array, side: String, cell_size: Vector2) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_rendered_count = 0
	if ghost_scene == null:
		return
	for ghost: Dictionary in ghosts:
		var cell: Vector2i = Mapper.coordinate_from_variant(ghost.get("position", []))
		if not Mapper.is_authority_cell_valid(cell):
			continue
		var view: Node2D = ghost_scene.instantiate() as Node2D
		view.position = Mapper.authority_to_world(cell, side, cell_size)
		view.set_meta("piece_id", str(ghost.get("piece_id", "")))
		add_child(view)
		_rendered_count += 1


func get_rendered_count() -> int:
	return _rendered_count
