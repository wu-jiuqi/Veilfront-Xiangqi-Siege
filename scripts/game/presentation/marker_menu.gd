extends PopupPanel

signal marker_selected(cell: Vector2i, marker_type: String)

var _cell := Vector2i.ZERO

const MENU_SIZE := Vector2i(304, 64)
const POINT_GAP := 14.0
const SCREEN_MARGIN := 8.0


func _ready() -> void:
	$Choices/CircleButton.pressed.connect(_on_marker_pressed.bind("circle"))
	$Choices/CrossButton.pressed.connect(_on_marker_pressed.bind("cross"))
	$Choices/SquareButton.pressed.connect(_on_marker_pressed.bind("square"))
	$Choices/ClearButton.pressed.connect(_on_marker_pressed.bind(""))


func open_for_cell(
	cell: Vector2i,
	point_position: Vector2,
	available_rect: Rect2,
	has_marker: bool
) -> void:
	_cell = cell
	$Choices/ClearButton.disabled = not has_marker
	var popup_position := point_position + Vector2(POINT_GAP, -MENU_SIZE.y * 0.5)
	if popup_position.x + MENU_SIZE.x > available_rect.end.x - SCREEN_MARGIN:
		popup_position.x = point_position.x - MENU_SIZE.x - POINT_GAP
	popup_position.x = clampf(
		popup_position.x,
		available_rect.position.x + SCREEN_MARGIN,
		available_rect.end.x - MENU_SIZE.x - SCREEN_MARGIN
	)
	popup_position.y = clampf(
		popup_position.y,
		available_rect.position.y + SCREEN_MARGIN,
		available_rect.end.y - MENU_SIZE.y - SCREEN_MARGIN
	)
	popup(Rect2i(Vector2i(popup_position.round()), MENU_SIZE))
	# PopupPanel may grow beyond the requested size when the active Theme adds
	# content margins. Clamp once more against the actual native popup size.
	var actual_position := Vector2(position)
	var actual_size := Vector2(size)
	actual_position.x = clampf(
		actual_position.x,
		available_rect.position.x + SCREEN_MARGIN,
		available_rect.end.x - actual_size.x - SCREEN_MARGIN
	)
	actual_position.y = clampf(
		actual_position.y,
		available_rect.position.y + SCREEN_MARGIN,
		available_rect.end.y - actual_size.y - SCREEN_MARGIN
	)
	position = Vector2i(actual_position.round())


func get_cell() -> Vector2i:
	return _cell


func get_context_snapshot() -> Dictionary:
	return {
		"cell": _cell,
		"position": position,
		"size": size,
		"clear_enabled": not $Choices/ClearButton.disabled,
	}


func _on_marker_pressed(marker_type: String) -> void:
	marker_selected.emit(_cell, marker_type)
	hide()
