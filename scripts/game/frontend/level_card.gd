class_name LevelCard
extends Control

signal level_selected(level: LevelDefinition)

@export var normal_texture: Texture2D
@export var focus_texture: Texture2D
@export var selected_texture: Texture2D
@export var completed_texture: Texture2D
@export var locked_texture: Texture2D

@onready var _state_texture: TextureRect = %StateTexture
@onready var _code_label: Label = %CodeLabel
@onready var _status_label: Label = %StatusLabel
@onready var _node_button: Button = %NodeButton

var _level: LevelDefinition
var _completed := false
var _progress_state := TutorialProgressStore.UNSEEN
var _selected := false
var _pointer_inside := false
var _focused := false


func configure(
	level: LevelDefinition,
	unlocked: bool,
	test_mode: bool = false,
	completed: bool = false,
	progress_state: String = TutorialProgressStore.UNSEEN
) -> void:
	_level = level
	_completed = completed
	_progress_state = progress_state
	_code_label.text = level.level_id
	_node_button.disabled = not unlocked or not level.available
	if progress_state == TutorialProgressStore.COMPLETED or completed:
		_status_label.text = "已掌握"
	elif progress_state == TutorialProgressStore.SKIPPED:
		_status_label.text = "已跳过"
	elif progress_state == TutorialProgressStore.ASSUMED:
		_status_label.text = "自报掌握"
	elif progress_state == TutorialProgressStore.NEEDS_REVIEW:
		_status_label.text = "建议复习"
	elif test_mode and unlocked and level.available:
		_status_label.text = "测试开放"
	elif not level.available:
		_status_label.text = "内容不可用"
	elif unlocked:
		_status_label.text = "可进入"
	else:
		_status_label.text = "尚未解锁"
	_status_label.visible = true
	_update_visual_state()


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_update_visual_state()


func get_level() -> LevelDefinition:
	return _level


func is_enterable() -> bool:
	return _level != null and not _node_button.disabled


func focus_play_button() -> void:
	_node_button.grab_focus()


func _on_pressed() -> void:
	if _level != null and not _node_button.disabled:
		level_selected.emit(_level)


func _on_focus_entered() -> void:
	_focused = true
	_update_visual_state()
	if _level != null and not _node_button.disabled:
		level_selected.emit(_level)


func _on_focus_exited() -> void:
	_focused = false
	_update_visual_state()


func _on_mouse_entered() -> void:
	_pointer_inside = true
	_update_visual_state()


func _on_mouse_exited() -> void:
	_pointer_inside = false
	_update_visual_state()


func _update_visual_state() -> void:
	if not is_node_ready():
		return
	var next_texture := normal_texture
	if _node_button.disabled:
		next_texture = locked_texture
	elif _selected:
		next_texture = selected_texture
	elif _focused or _pointer_inside:
		next_texture = focus_texture
	elif _completed:
		next_texture = completed_texture
	if _state_texture.texture != next_texture:
		_state_texture.texture = next_texture
	if _node_button.disabled:
		_node_button.theme_type_variation = &"SecondaryButton"
		_node_button.modulate = Color(0.62, 0.62, 0.58, 0.72)
	elif _selected:
		_node_button.theme_type_variation = &"PrimaryButton"
		_node_button.modulate = Color.WHITE
	elif _completed:
		_node_button.theme_type_variation = &"ConfirmButton"
		_node_button.modulate = Color.WHITE
	elif _focused or _pointer_inside:
		_node_button.theme_type_variation = &"PrimaryButton"
		_node_button.modulate = Color(1.06, 1.02, 0.9, 1.0)
	else:
		_node_button.theme_type_variation = &"SecondaryButton"
		_node_button.modulate = Color.WHITE
