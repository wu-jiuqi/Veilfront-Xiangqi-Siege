extends Node2D

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

@export var piece_scene: PackedScene

var _rendered_count: int = 0
var _rendered_glyphs: Array[String] = []
var _rendered_cells: Array[Vector2i] = []
var _rendered_art_paths: Array[String] = []


func render(pieces: Array, side: String, cell_size: Vector2) -> void:
	_clear_views()
	_rendered_count = 0
	_rendered_glyphs.clear()
	_rendered_cells.clear()
	_rendered_art_paths.clear()
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
		var piece_side := str(piece.get("side", ""))
		var piece_glyph := _piece_glyph(str(piece.get("piece_type", "")), piece_side)
		if view.has_method("configure_piece"):
			view.call("configure_piece", piece, cell_size)
		else:
			_configure_graybox_piece(view, piece_side, piece_glyph)
		var artwork: Sprite2D = view.get_node_or_null("Artwork") as Sprite2D
		if artwork != null and artwork.texture != null:
			_rendered_art_paths.append(artwork.texture.resource_path)
		add_child(view)
		_rendered_count += 1
		_rendered_glyphs.append(piece_glyph)
		_rendered_cells.append(cell)


func get_rendered_count() -> int:
	return _rendered_count


func get_rendered_glyphs() -> Array[String]:
	return _rendered_glyphs.duplicate()


func get_rendered_cells() -> Array[Vector2i]:
	return _rendered_cells.duplicate()


func get_rendered_art_paths() -> Array[String]:
	return _rendered_art_paths.duplicate()


func find_piece_cell_at_world_position(world_position: Vector2) -> Vector2i:
	var local_position := transform.affine_inverse() * world_position
	var candidates: Array[Node2D] = []
	for child: Node in get_children():
		var view := child as Node2D
		if view == null or not view.visible or not view.has_meta("authority_cell"):
			continue
		candidates.append(view)
	candidates.sort_custom(func(left: Node2D, right: Node2D) -> bool:
		return left.position.y > right.position.y
	)
	for view: Node2D in candidates:
		var view_point := view.transform.affine_inverse() * local_position
		if view.has_method("contains_local_point") \
		and bool(view.call("contains_local_point", view_point)):
			return view.get_meta("authority_cell", Vector2i.ZERO) as Vector2i
	return Vector2i.ZERO


func _clear_views() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


func _configure_graybox_piece(view: Node2D, piece_side: String, piece_glyph: String) -> void:
	var glyph: Label = view.get_node_or_null("Glyph") as Label
	if glyph != null:
		glyph.text = piece_glyph
	var body: Polygon2D = view.get_node_or_null("Body") as Polygon2D
	if body != null:
		body.color = Color(0.62, 0.12, 0.1, 0.98) if piece_side == "red" \
			else Color(0.11, 0.2, 0.34, 0.98)
	var border: Line2D = view.get_node_or_null("Border") as Line2D
	if border != null:
		border.default_color = Color(1.0, 0.55, 0.4, 1.0) if piece_side == "red" \
			else Color(0.55, 0.78, 1.0, 1.0)


func _piece_glyph(piece_type: String, side: String) -> String:
	if side == "red":
		return {
			"rook": "车", "horse": "马", "elephant": "相", "advisor": "仕",
			"general": "帅", "cannon": "炮", "pawn": "兵",
		}.get(piece_type, "?")
	if side == "black":
		return {
			"rook": "车", "horse": "马", "elephant": "象", "advisor": "士",
			"general": "将", "cannon": "炮", "pawn": "卒",
		}.get(piece_type, "?")
	return "?"
