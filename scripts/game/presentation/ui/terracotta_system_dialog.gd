extends AcceptDialog


func _ready() -> void:
	_apply_internal_theme()
	about_to_popup.connect(_apply_internal_theme)


func _apply_internal_theme() -> void:
	if theme == null:
		return
	for child: Node in get_children(true):
		_apply_theme_recursively(child)


func _apply_theme_recursively(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.theme = theme
		if control is Panel:
			control.theme_type_variation = &"DialogPanel"
			control.add_theme_stylebox_override(
				&"panel",
				theme.get_stylebox(&"panel", &"DialogPanel")
			)
		elif control is Label:
			control.theme_type_variation = &"DialogBodyLabel"
			control.add_theme_color_override(
				&"font_color",
				theme.get_color(&"font_color", &"DialogBodyLabel")
			)
			control.add_theme_font_size_override(
				&"font_size",
				theme.get_font_size(&"font_size", &"DialogBodyLabel")
			)
		elif control is Button:
			control.theme_type_variation = &"DialogButton"
	for child: Node in node.get_children(true):
		_apply_theme_recursively(child)
