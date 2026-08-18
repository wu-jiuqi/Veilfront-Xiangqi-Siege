extends Control

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

const ROOK_COLOR := Color(0.2, 0.64, 1.0, 0.88)
const ELEPHANT_BLOCK_COLOR := Color(1.0, 0.78, 0.18, 0.9)

var _side: String = "red"
var _cell_size := Vector2(128.0, 128.0)
var _overlays: Dictionary = {
	"rook_paths": [],
	"elephant_reveal_zones": [],
	"elephant_block_fields": [],
}
var _group_count: int = 0
var _semantic_snapshot: Dictionary = {}


func render_public_overlays(overlays: Dictionary, side: String, cell_size: Vector2) -> void:
	_side = side
	_cell_size = cell_size
	_overlays = overlays.duplicate(true)
	_group_count = 0
	for field_name: String in ["rook_paths", "elephant_block_fields"]:
		for record: Variant in _overlays.get(field_name, []):
			if record is Dictionary and not record.get("cells", []).is_empty():
				_group_count += 1
	var block_cell_counts: Array[int] = []
	for record: Variant in _overlays.get("elephant_block_fields", []):
		if record is Dictionary:
			block_cell_counts.append(_valid_cell_count(record.get("cells", [])))
	_semantic_snapshot = {
		"rook_path_count": _valid_record_count(_overlays.get("rook_paths", [])),
		"elephant_field_count": _valid_record_count(_overlays.get("elephant_block_fields", [])),
		"ignored_reveal_cell_count": _total_valid_cell_count(
			_overlays.get("elephant_reveal_zones", [])
		),
		"rendered_reveal_count": 0,
		"elephant_block_cell_counts": block_cell_counts,
	}
	custom_minimum_size = Vector2(9.0 * _cell_size.x, 24.0 * _cell_size.y)
	size = custom_minimum_size
	queue_redraw()


func get_group_count() -> int:
	return _group_count


func get_semantic_snapshot() -> Dictionary:
	return _semantic_snapshot.duplicate(true)


func _draw() -> void:
	for record: Dictionary in _overlays.get("rook_paths", []):
		_draw_rook_path(record.get("cells", []))
	for record: Dictionary in _overlays.get("elephant_block_fields", []):
		_draw_field_outline(record.get("cells", []), ELEPHANT_BLOCK_COLOR, 5.0)


func _draw_rook_path(cells: Array) -> void:
	var points := PackedVector2Array()
	for value: Variant in cells:
		var cell: Vector2i = Mapper.coordinate_from_variant(value)
		if Mapper.is_authority_cell_valid(cell):
			points.append(Mapper.authority_to_world(cell, _side, _cell_size))
	if points.size() < 2:
		return
	draw_polyline(points, Color(ROOK_COLOR, 0.24), 18.0, true)
	draw_polyline(points, ROOK_COLOR, 5.0, true)


func _draw_field_outline(cells: Array, color: Color, width: float) -> void:
	var display_cells: Array[Vector2i] = []
	for value: Variant in cells:
		var authority_cell: Vector2i = Mapper.coordinate_from_variant(value)
		if Mapper.is_authority_cell_valid(authority_cell):
			display_cells.append(Mapper.authority_to_display(authority_cell, _side))
	if display_cells.is_empty():
		return
	var min_cell: Vector2i = display_cells[0]
	var max_cell: Vector2i = display_cells[0]
	for cell: Vector2i in display_cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	var top_left := (Vector2(min_cell) + Vector2(0.5, 0.5)) * _cell_size
	var bottom_right := (Vector2(max_cell) + Vector2(0.5, 0.5)) * _cell_size
	var outline := PackedVector2Array([
		top_left,
		Vector2(bottom_right.x, top_left.y),
		bottom_right,
		Vector2(top_left.x, bottom_right.y),
		top_left,
	])
	draw_polyline(outline, color, width, true)


func _valid_record_count(records: Array) -> int:
	var count: int = 0
	for record: Variant in records:
		if record is Dictionary and _valid_cell_count(record.get("cells", [])) > 0:
			count += 1
	return count


func _total_valid_cell_count(records: Array) -> int:
	var count: int = 0
	for record: Variant in records:
		if record is Dictionary:
			count += _valid_cell_count(record.get("cells", []))
	return count


func _valid_cell_count(cells: Array) -> int:
	var unique_cells: Dictionary = {}
	for value: Variant in cells:
		var cell: Vector2i = Mapper.coordinate_from_variant(value)
		if Mapper.is_authority_cell_valid(cell):
			unique_cells[cell] = true
	return unique_cells.size()
