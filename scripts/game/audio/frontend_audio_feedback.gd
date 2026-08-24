class_name FrontendAudioFeedback
extends Node

@export var control_root_path: NodePath = NodePath("..")
@export var dry_run: bool = false

@onready var _audio_root: VeilfrontAudioRoot = $AudioRoot

var _bound_buttons: Dictionary = {}
var _bound_dialogs: Dictionary = {}


func _ready() -> void:
	_audio_root.dry_run = dry_run
	get_tree().node_added.connect(_on_node_added)
	refresh_bindings.call_deferred()


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func play_cue(cue_key: String) -> bool:
	return _audio_root.play_local_cue(cue_key, [], "frontend")


func refresh_bindings() -> void:
	var control_root := get_node_or_null(control_root_path)
	if control_root == null:
		return
	_bind_candidate(control_root)
	for candidate: Node in control_root.find_children("*", "", true, false):
		_bind_candidate(candidate)


func audio_root() -> VeilfrontAudioRoot:
	return _audio_root


func _on_node_added(node: Node) -> void:
	var control_root := get_node_or_null(control_root_path)
	if control_root == null or (node != control_root and not control_root.is_ancestor_of(node)):
		return
	_bind_candidate.call_deferred(node)


func _bind_candidate(candidate: Node) -> void:
	if not is_instance_valid(candidate):
		return
	if candidate is BaseButton:
		_bind_button(candidate as BaseButton)
	if candidate is TerracottaModalDialog:
		_bind_dialog(candidate as TerracottaModalDialog)


func _bind_button(button: BaseButton) -> void:
	var instance_id := button.get_instance_id()
	if _bound_buttons.has(instance_id):
		return
	_bound_buttons[instance_id] = true
	button.focus_entered.connect(_on_button_focused.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))
	button.tree_exited.connect(_on_bound_button_exited.bind(instance_id), CONNECT_ONE_SHOT)


func _bind_dialog(dialog: TerracottaModalDialog) -> void:
	var instance_id := dialog.get_instance_id()
	if _bound_dialogs.has(instance_id):
		return
	_bound_dialogs[instance_id] = dialog.visible
	dialog.visibility_changed.connect(_on_dialog_visibility_changed.bind(dialog))
	dialog.tree_exited.connect(_on_bound_dialog_exited.bind(instance_id), CONNECT_ONE_SHOT)


func _on_button_focused(button: BaseButton) -> void:
	if button.disabled or not button.is_visible_in_tree():
		return
	play_cue("sfx.ui.focus")


func _on_button_pressed(button: BaseButton) -> void:
	if button.disabled:
		return
	play_cue(_cue_for_button(button))


func _on_dialog_visibility_changed(dialog: TerracottaModalDialog) -> void:
	var instance_id := dialog.get_instance_id()
	var was_visible: bool = bool(_bound_dialogs.get(instance_id, false))
	_bound_dialogs[instance_id] = dialog.visible
	if was_visible == dialog.visible:
		return
	play_cue("sfx.ui.modal_open" if dialog.visible else "sfx.ui.modal_close")


func _on_bound_button_exited(instance_id: int) -> void:
	_bound_buttons.erase(instance_id)


func _on_bound_dialog_exited(instance_id: int) -> void:
	_bound_dialogs.erase(instance_id)


func _cue_for_button(button: BaseButton) -> String:
	var semantic_name := str(button.name).to_lower()
	if semantic_name.contains("cancel") \
	or semantic_name.contains("back") \
	or semantic_name.contains("return") \
	or semantic_name.contains("close") \
	or semantic_name.contains("disconnect"):
		return "sfx.ui.cancel"
	if semantic_name.contains("confirm") \
	or semantic_name.contains("apply") \
	or semantic_name.contains("enter") \
	or semantic_name.contains("start") \
	or semantic_name.contains("ready") \
	or semantic_name.contains("host") \
	or semantic_name.contains("join"):
		return "sfx.ui.confirm"
	return "sfx.ui.activate"
