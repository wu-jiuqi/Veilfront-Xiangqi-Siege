extends Control

@onready var primary_button: Button = %PrimaryButton
@onready var secondary_button: Button = %SecondaryButton
@onready var danger_button: Button = %DangerButton
@onready var confirm_button: Button = %ConfirmButton
@onready var motion_status: Label = %MotionStatus

var _reduced_motion := false


func _ready() -> void:
	set_reduced_motion(false)
	primary_button.grab_focus.call_deferred()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	for button: Button in get_foundation_buttons():
		button.call("set_reduced_motion", enabled)
	motion_status.text = "减少动态：%s · 仅保留 80–120 ms 色变" % ("开启" if enabled else "关闭")


func is_reduced_motion_enabled() -> bool:
	return _reduced_motion


func get_foundation_buttons() -> Array[Button]:
	return [primary_button, secondary_button, danger_button, confirm_button]


func get_foundation_snapshot() -> Dictionary:
	var roles: Array[StringName] = []
	for button: Button in get_foundation_buttons():
		roles.append(button.get("semantic_role") as StringName)
	return {
		"roles": roles,
		"button_count": get_foundation_buttons().size(),
		"reduced_motion": _reduced_motion,
		"safe_rect": ($SafeMargin as Control).get_global_rect(),
		"panel_rect": ($SafeMargin/Center/FoundationPanel as Control).get_global_rect(),
	}
