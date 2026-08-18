extends PopupPanel

signal marker_selected(cell: Vector2i, marker_type: String)

var _cell := Vector2i.ZERO


func _ready() -> void:
	$Choices/CircleButton.pressed.connect(_on_marker_pressed.bind("circle"))
	$Choices/CrossButton.pressed.connect(_on_marker_pressed.bind("cross"))
	$Choices/SquareButton.pressed.connect(_on_marker_pressed.bind("square"))


func open_for_cell(cell: Vector2i) -> void:
	_cell = cell
	popup()


func _on_marker_pressed(marker_type: String) -> void:
	marker_selected.emit(_cell, marker_type)
	hide()
