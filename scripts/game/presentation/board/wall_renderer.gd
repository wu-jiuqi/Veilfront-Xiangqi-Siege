extends Node2D

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

@export var wall_scene: PackedScene

var _rendered_count: int = 0


func render(walls: Array, side: String, cell_size: Vector2) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_rendered_count = 0
	if wall_scene == null:
		return
	for wall: Dictionary in walls:
		var wall_side: String = str(wall.get("side", ""))
		var authority_y: int = 4 if wall_side == "red" else 21
		for authority_x: int in range(1, 10):
			var view: Node2D = wall_scene.instantiate() as Node2D
			view.position = Mapper.authority_to_world(
				Vector2i(authority_x, authority_y), side, cell_size
			)
			view.scale = Vector2(cell_size.x / 128.0, cell_size.y / 128.0)
			var body: Polygon2D = view.get_node_or_null("WallBody") as Polygon2D
			if body != null:
				var intact: bool = str(wall.get("status", "")) == "INTACT"
				body.color = _wall_color(wall_side, intact)
				if not intact:
					body.scale.y = 0.35
			add_child(view)
			_rendered_count += 1


func get_rendered_count() -> int:
	return _rendered_count


func _wall_color(wall_side: String, intact: bool) -> Color:
	if not intact:
		return Color(0.32, 0.29, 0.27, 0.55)
	return Color(0.78, 0.25, 0.18, 1.0) if wall_side == "red" \
		else Color(0.18, 0.23, 0.31, 1.0)
