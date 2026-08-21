class_name LevelCard
extends Control

signal level_selected(level: LevelDefinition)

@onready var _normal_state: TextureRect = %NormalState
@onready var _focus_state: TextureRect = %FocusState
@onready var _selected_state: TextureRect = %SelectedState
@onready var _completed_state: TextureRect = %CompletedState
@onready var _locked_state: TextureRect = %LockedState
@onready var _code_label: Label = %CodeLabel
@onready var _status_label: Label = %StatusLabel
@onready var _node_button: Button = %NodeButton

var _level: LevelDefinition
var _completed := false
var _selected := false
var _pointer_inside := false
var _focused := false


func configure(level: LevelDefinition, unlocked: bool, test_mode: bool = false, completed: bool = false) -> void:
	_level = level
	_completed = completed
	_code_label.text = level.level_id
	_node_button.disabled = not unlocked or not level.available
	if completed:
		_status_label.text = "已完成"
	elif test_mode and unlocked and level.available:
		_status_label.text = "测试开放"
	elif not level.available:
		_status_label.text = "内容不可用"
	elif unlocked:
		_status_label.text = "可进入"
	else:
		_status_label.text = "尚未解锁"
	_update_visual_state()


func set_selected(value: bool) -> void:
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
	_normal_state.visible = false
	_focus_state.visible = false
	_selected_state.visible = false
	_completed_state.visible = false
	_locked_state.visible = false
	if _node_button.disabled:
		_locked_state.visible = true
	elif _selected:
		_selected_state.visible = true
	elif _focused or _pointer_inside:
		_focus_state.visible = true
	elif _completed:
		_completed_state.visible = true
	else:
		_normal_state.visible = true
