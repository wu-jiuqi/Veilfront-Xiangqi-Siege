extends Control

const Mapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")

var _side: String = "red"
var _cell_size := Vector2(128.0, 128.0)
var _markers: Dictionary = {}
var _marker_assets: Dictionary = {}


func configure(side: String, cell_size: Vector2, marker_assets: Dictionary = {}) -> void:
	_side = side
	_cell_size = cell_size
	_marker_assets = marker_assets.duplicate()
	custom_minimum_size = Vector2(9.0 * _cell_size.x, 24.0 * _cell_size.y)
	size = custom_minimum_size
	queue_redraw()


func set_marker(cell: Vector2i, marker_type: String) -> void:
	if not Mapper.is_authority_cell_valid(cell) or marker_type not in ["circle", "cross", "square"]:
		return
	_markers[_cell_key(cell)] = {"cell": cell, "type": marker_type}
	queue_redraw()


func clear_marker(cell: Vector2i) -> void:
	_markers.erase(_cell_key(cell))
	queue_redraw()


func has_marker(cell: Vector2i) -> bool:
	return _markers.has(_cell_key(cell))


func clear_all() -> void:
	_markers.clear()
	queue_redraw()


func get_marker_count() -> int:
	return _markers.size()


func get_marker_asset_count() -> int:
	return _marker_assets.size()


func _draw() -> void:
	for marker: Dictionary in _markers.values():
		var cell: Vector2i = marker.get("cell", Vector2i.ZERO)
		var center: Vector2 = Mapper.authority_to_world(cell, _side, _cell_size)
		var marker_type: String = str(marker.get("type", ""))
		var texture: Texture2D = _marker_assets.get(marker_type) as Texture2D
		if texture != null:
			var icon_size := Vector2.ONE * minf(_cell_size.x, _cell_size.y) * 0.64
			draw_texture_rect(
				texture,
				Rect2(center - icon_size * 0.5, icon_size),
				false,
				Color(1.42, 1.3, 1.5, 1.0)
			)
			continue
		var radius: float = minf(_cell_size.x, _cell_size.y) * 0.22
		var color := Color(0.76, 0.38, 1.0, 0.9)
		match marker_type:
			"circle":
				draw_arc(center, radius, 0.0, TAU, 32, color, 7.0, true)
			"cross":
				draw_line(center - Vector2(radius, radius), center + Vector2(radius, radius), color, 7.0, true)
				draw_line(center + Vector2(radius, -radius), center + Vector2(-radius, radius), color, 7.0, true)
			"square":
				draw_rect(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color, false, 7.0, true)


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
