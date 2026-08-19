extends Control

const MAIN_MENU_SCENE := "res://scenes/game/frontend/main_menu.tscn"
const LEVEL_CARD_SCENE := preload("res://scenes/game/frontend/level_card.tscn")
const CATALOG := preload("res://resources/game/levels/level_catalog.tres")

@onready var _back_button: Button = %BackButton
@onready var _tutorial_grid: GridContainer = %TutorialGrid
@onready var _challenge_grid: GridContainer = %ChallengeGrid
@onready var _progress_label: Label = %ProgressLabel
@onready var _tabs: TabContainer = %CategoryTabs
@onready var _reset_button: Button = %ResetButton
@onready var _status_label: Label = %StatusLabel
@onready var _reset_dialog: ConfirmationDialog = %ResetDialog

var _transitioning := false
var _completed: Dictionary = {}


func _ready() -> void:
	_load_progress()
	_back_button.pressed.connect(_return_to_main_menu)
	_reset_button.pressed.connect(_on_reset_progress)
	_build_level_grid(_tutorial_grid, CATALOG.get_levels_for_category("tutorial"))
	_build_level_grid(_challenge_grid, CATALOG.get_levels_for_category("challenge"))
	_update_progress_label()
	_back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_return_to_main_menu()
		get_viewport().set_input_as_handled()


func _build_level_grid(grid: GridContainer, levels: Array[LevelDefinition]) -> void:
	for child in grid.get_children():
		child.queue_free()
	for level: LevelDefinition in levels:
		var card: LevelCard = LEVEL_CARD_SCENE.instantiate()
		grid.add_child(card)
		card.configure(level, _is_unlocked(level))
		card.play_requested.connect(_on_level_play_requested)


func _is_unlocked(level: LevelDefinition) -> bool:
	return level.unlock_after.is_empty() or bool(_completed.get(level.unlock_after, false))


func _on_level_play_requested(level: LevelDefinition) -> void:
	if _transitioning or not level.available:
		return
	_transitioning = true
	var error := get_tree().change_scene_to_file(level.scene_path)
	if error != OK:
		_transitioning = false
		_status_label.text = "无法打开关卡：%s" % level.level_id


func _return_to_main_menu() -> void:
	if _transitioning:
		return
	_transitioning = true
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load("user://level_progress.cfg") != OK:
		return
	var saved_ids: Variant = config.get_value("progress", "completed_ids", [])
	if saved_ids is Array:
		for level_id: Variant in saved_ids:
			var definition := CATALOG.find_level(str(level_id))
			if definition != null:
				_completed[definition.level_id] = true


func _on_reset_progress() -> void:
	_reset_dialog.confirmed.connect(_clear_tutorial_progress, CONNECT_ONE_SHOT)
	_reset_dialog.popup_centered()


func _clear_tutorial_progress() -> void:
	_completed.clear()
	var config := ConfigFile.new()
	config.set_value("progress", "completed_ids", [])
	config.save("user://level_progress.cfg")
	_update_progress_label()
	_build_level_grid(_tutorial_grid, CATALOG.get_levels_for_category("tutorial"))
	_build_level_grid(_challenge_grid, CATALOG.get_levels_for_category("challenge"))


func _update_progress_label() -> void:
	var tutorial_levels := CATALOG.get_levels_for_category("tutorial")
	var completed_tutorials := 0
	for level: LevelDefinition in tutorial_levels:
		if bool(_completed.get(level.level_id, false)):
			completed_tutorials += 1
	_progress_label.text = "教学进度 %d / %d" % [completed_tutorials, tutorial_levels.size()]
