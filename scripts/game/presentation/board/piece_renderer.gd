extends Node2D

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

@export var piece_scene: PackedScene

var _rendered_count: int = 0


func render(pieces: Array, side: String, cell_size: Vector2) -> void:
	_clear_views()
	_rendered_count = 0
	if piece_scene == null:
		return
	for piece: Dictionary in pieces:
		if not bool(piece.get("alive", false)) or bool(piece.get("in_reserve", false)):
			continue
		var cell: Vector2i = Mapper.coordinate_from_variant(piece.get("position", []))
		if not Mapper.is_authority_cell_valid(cell):
			continue
		var view: Node2D = piece_scene.instantiate() as Node2D
		view.position = Mapper.authority_to_world(cell, side, cell_size)
		view.set_meta("piece_id", str(piece.get("id", "")))
		view.set_meta("authority_cell", cell)
		var glyph: Label = view.get_node_or_null("Glyph") as Label
		if glyph != null:
			glyph.text = _piece_glyph(str(piece.get("piece_type", "")))
		var body: Polygon2D = view.get_node_or_null("Body") as Polygon2D
		if body != null:
			body.color = Color(0.72, 0.18, 0.12, 1.0) if piece.get("side") == "red" \
				else Color(0.12, 0.16, 0.22, 1.0)
		add_child(view)
		_rendered_count += 1


func get_rendered_count() -> int:
	return _rendered_count


func _clear_views() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


func _piece_glyph(piece_type: String) -> String:
	var glyphs: Dictionary = {
		"rook": "车",
		"horse": "马",
		"elephant": "相",
		"advisor": "士",
		"general": "将",
		"cannon": "炮",
		"soldier": "兵",
	}
	return str(glyphs.get(piece_type, "棋"))
