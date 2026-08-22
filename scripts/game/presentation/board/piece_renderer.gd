extends Node2D

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

@export var piece_scene: PackedScene

var _rendered_count: int = 0
var _rendered_glyphs: Array[String] = []
var _rendered_cells: Array[Vector2i] = []
var _rendered_art_paths: Array[String] = []
var _views_by_id: Dictionary = {}
var _selected_cell := Vector2i.ZERO
var _has_rendered_piece_snapshot: bool = false
var _last_side: String = ""
var _last_animation_events: Array[Dictionary] = []


func render(pieces: Array, side: String, cell_size: Vector2) -> void:
	_rendered_count = 0
	_rendered_glyphs.clear()
	_rendered_cells.clear()
	_rendered_art_paths.clear()
	_last_animation_events.clear()
	if piece_scene == null:
		clear_immediately()
		return
	var incoming_by_id: Dictionary = {}
	var next_on_board: Dictionary = {}
	for piece_value: Variant in pieces:
		if not piece_value is Dictionary:
			continue
		var piece: Dictionary = piece_value
		var piece_id := str(piece.get("id", ""))
		if piece_id.is_empty():
			continue
		incoming_by_id[piece_id] = piece
		if not bool(piece.get("alive", false)) or bool(piece.get("in_reserve", false)):
			continue
		var cell: Vector2i = Mapper.coordinate_from_variant(piece.get("position", []))
		if not Mapper.is_authority_cell_valid(cell):
			continue
		next_on_board[piece_id] = {
			"piece": piece,
			"cell": cell,
			"position": Mapper.authority_to_world(cell, side, cell_size),
		}
	var animate_changes := _has_rendered_piece_snapshot \
		and (_last_side.is_empty() or _last_side == side)
	var moved_descriptors: Dictionary = {}
	for piece_id_value: Variant in next_on_board.keys():
		var piece_id := str(piece_id_value)
		if not _views_by_id.has(piece_id):
			continue
		var view := _views_by_id[piece_id] as Node2D
		if not is_instance_valid(view):
			continue
		var descriptor: Dictionary = next_on_board[piece_id]
		var old_cell := view.get_meta("authority_cell", Vector2i.ZERO) as Vector2i
		if old_cell != descriptor["cell"]:
			moved_descriptors[piece_id] = {
				"from_position": view.position,
				"target_position": descriptor["position"],
				"target_cell": descriptor["cell"],
				"piece_side": str((descriptor["piece"] as Dictionary).get("side", "")),
			}
	var capture_movers: Dictionary = {}
	for previous_id_value: Variant in _views_by_id.keys().duplicate():
		var previous_id := str(previous_id_value)
		if next_on_board.has(previous_id):
			continue
		var previous_view := _views_by_id[previous_id] as Node2D
		if not is_instance_valid(previous_view):
			_views_by_id.erase(previous_id)
			continue
		var previous_cell := previous_view.get_meta(
			"authority_cell", Vector2i.ZERO
		) as Vector2i
		var previous_side := str(previous_view.get_meta("piece_side", ""))
		var attacker_id := ""
		var impact_direction := Vector2.UP
		for mover_id_value: Variant in moved_descriptors.keys():
			var mover_id := str(mover_id_value)
			var movement: Dictionary = moved_descriptors[mover_id]
			if movement["target_cell"] == previous_cell \
			and str(movement["piece_side"]) != previous_side:
				attacker_id = mover_id
				impact_direction = (
					movement["target_position"] - movement["from_position"]
				).normalized()
				break
		var known_removed := false
		if incoming_by_id.has(previous_id):
			var incoming_piece: Dictionary = incoming_by_id[previous_id]
			known_removed = not bool(incoming_piece.get("alive", false)) \
				or bool(incoming_piece.get("in_reserve", false))
		var captured := known_removed or not attacker_id.is_empty()
		previous_view.set_meta("interactive", false)
		if captured and previous_view.has_method("play_captured"):
			previous_view.call("play_captured", impact_direction)
			_last_animation_events.append({"kind": "captured", "piece_id": previous_id})
		else:
			if previous_view.has_method("play_hidden"):
				previous_view.call("play_hidden")
			else:
				previous_view.queue_free()
			_last_animation_events.append({"kind": "hidden", "piece_id": previous_id})
		if not attacker_id.is_empty():
			capture_movers[attacker_id] = true
		_views_by_id.erase(previous_id)
	var ordered_ids: Array = next_on_board.keys()
	ordered_ids.sort()
	for piece_id_value: Variant in ordered_ids:
		var piece_id := str(piece_id_value)
		var descriptor: Dictionary = next_on_board[piece_id]
		var piece: Dictionary = descriptor["piece"]
		var cell: Vector2i = descriptor["cell"]
		var target_position: Vector2 = descriptor["position"]
		var view: Node2D
		var is_new := not _views_by_id.has(piece_id) \
			or not is_instance_valid(_views_by_id[piece_id])
		if is_new:
			view = piece_scene.instantiate() as Node2D
			view.position = target_position
			add_child(view)
			_views_by_id[piece_id] = view
		else:
			view = _views_by_id[piece_id] as Node2D
		view.set_meta("piece_id", piece_id)
		view.set_meta("authority_cell", cell)
		view.set_meta("piece_side", str(piece.get("side", "")))
		view.set_meta("interactive", true)
		var piece_side := str(piece.get("side", ""))
		var piece_glyph := _piece_glyph(str(piece.get("piece_type", "")), piece_side)
		if view.has_method("configure_piece"):
			view.call("configure_piece", piece, cell_size)
		else:
			_configure_graybox_piece(view, piece_side, piece_glyph)
		if is_new:
			if animate_changes and view.has_method("play_drop"):
				view.call("play_drop", target_position, cell_size)
				_last_animation_events.append({"kind": "land", "piece_id": piece_id})
			else:
				view.position = target_position
		elif moved_descriptors.has(piece_id):
			var captures_piece := capture_movers.has(piece_id)
			if animate_changes and view.has_method("play_move_to"):
				view.call("play_move_to", target_position, captures_piece)
				_last_animation_events.append({
					"kind": "capture" if captures_piece else "move",
					"piece_id": piece_id,
				})
			else:
				view.position = target_position
		var artwork: Sprite2D = view.get_node_or_null("Artwork") as Sprite2D
		if artwork != null and artwork.texture != null:
			_rendered_art_paths.append(artwork.texture.resource_path)
		_rendered_count += 1
		_rendered_glyphs.append(piece_glyph)
		_rendered_cells.append(cell)
	_last_side = side
	if not next_on_board.is_empty():
		_has_rendered_piece_snapshot = true
	_apply_selection()


func get_rendered_count() -> int:
	return _rendered_count


func get_rendered_glyphs() -> Array[String]:
	return _rendered_glyphs.duplicate()


func get_rendered_cells() -> Array[Vector2i]:
	return _rendered_cells.duplicate()


func get_rendered_art_paths() -> Array[String]:
	return _rendered_art_paths.duplicate()


func set_selected_cell(cell: Vector2i) -> void:
	_selected_cell = cell
	_apply_selection()


func get_selected_piece_count() -> int:
	var count := 0
	for view_value: Variant in _views_by_id.values():
		var view := view_value as Node2D
		if is_instance_valid(view) and view.has_method("get_animation_snapshot"):
			var snapshot: Dictionary = view.call("get_animation_snapshot")
			if bool(snapshot.get("selected", false)):
				count += 1
	return count


func get_last_animation_events() -> Array[Dictionary]:
	return _last_animation_events.duplicate(true)


func get_piece_animation_snapshot(piece_id: String) -> Dictionary:
	if not _views_by_id.has(piece_id):
		return {}
	var view := _views_by_id[piece_id] as Node2D
	if not is_instance_valid(view) or not view.has_method("get_animation_snapshot"):
		return {}
	return view.call("get_animation_snapshot") as Dictionary


func find_piece_cell_at_world_position(world_position: Vector2) -> Vector2i:
	var local_position := transform.affine_inverse() * world_position
	var candidates: Array[Node2D] = []
	for child: Node in get_children():
		var view := child as Node2D
		if view == null or not view.visible or not view.has_meta("authority_cell") \
		or not bool(view.get_meta("interactive", true)):
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


func clear_immediately() -> void:
	for child: Node in get_children():
		if child.has_method("stop_animations"):
			child.call("stop_animations")
		remove_child(child)
		child.queue_free()
	_views_by_id.clear()
	_rendered_count = 0
	_rendered_glyphs.clear()
	_rendered_cells.clear()
	_rendered_art_paths.clear()
	_last_animation_events.clear()
	_selected_cell = Vector2i.ZERO
	_has_rendered_piece_snapshot = false
	_last_side = ""


func _apply_selection() -> void:
	for view_value: Variant in _views_by_id.values():
		var view := view_value as Node2D
		if not is_instance_valid(view) or not view.has_method("set_selected"):
			continue
		var cell := view.get_meta("authority_cell", Vector2i.ZERO) as Vector2i
		view.call("set_selected", Mapper.is_authority_cell_valid(_selected_cell) \
			and cell == _selected_cell)


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
