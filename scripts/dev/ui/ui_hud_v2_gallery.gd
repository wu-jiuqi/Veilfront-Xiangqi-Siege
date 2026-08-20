class_name UiHudV2Gallery
extends PanelContainer

signal close_requested

@onready var close_button: Button = %CloseButton


func focus_close() -> void:
	close_button.grab_focus.call_deferred()


func _on_close_button_pressed() -> void:
	close_requested.emit()
