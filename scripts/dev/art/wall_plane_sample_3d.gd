@tool
extends Node3D

const VALID_STATES: PackedStringArray = ["INTACT", "BREACHED", "REPAIRING"]

@export_enum("INTACT", "BREACHED", "REPAIRING") var wall_state: String = "INTACT":
	set(value):
		wall_state = value if value in VALID_STATES else "INTACT"
		_apply_state_visibility()


func _ready() -> void:
	_apply_state_visibility()


func set_wall_state(value: String) -> void:
	wall_state = value


func _apply_state_visibility() -> void:
	var intact: Node3D = get_node_or_null("Intact") as Node3D
	var breached: Node3D = get_node_or_null("Breached") as Node3D
	var repairing: Node3D = get_node_or_null("Repairing") as Node3D
	if intact != null:
		intact.visible = wall_state == "INTACT"
	if breached != null:
		breached.visible = wall_state == "BREACHED"
	if repairing != null:
		repairing.visible = wall_state == "REPAIRING"
