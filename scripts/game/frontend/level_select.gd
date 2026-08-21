extends Control

const MAIN_MENU_SCENE := "res://scenes/game/frontend/main_menu.tscn"
const LEVEL_CARD_SCENE := preload("res://scenes/game/frontend/level_card.tscn")
const CATALOG := preload("res://resources/game/levels/level_catalog.tres")

@export var test_all_levels_unlocked: bool = true

@onready var _back_button: Button = %BackButton
@onready var _tutorial_grid: GridContainer = %TutorialGrid
@onready var _challenge_grid: GridContainer = %ChallengeGrid
@onready var _progress_label: Label = %ProgressLabel
@onready var _progress_bar: ProgressBar = %TutorialProgress
@onready var _progress_fraction: Label = %ProgressFraction
@onready var _tabs: TabContainer = %CategoryTabs
@onready var _tutorial_category_button: Button = %TutorialCategoryButton
@onready var _challenge_category_button: Button = %ChallengeCategoryButton
@onready var _enter_button: Button = %EnterButton
@onready var _detail_code: Label = %DetailCode
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_summary: Label = %DetailSummary
@onready var _detail_objective: Label = %DetailObjective
@onready var _detail_status: Label = %DetailStatus
@onready var _status_label: Label = %StatusLabel
@onready var _reset_dialog: ConfirmationDialog = %ResetDialog

var _transitioning := false
var _completed: Dictionary = {}
var _cards: Array[LevelCard] = []
var _selected_level: LevelDefinition


func _ready() -> void:
	_load_progress()
	_reset_dialog.confirmed.connect(_clear_tutorial_progress)
	_build_level_grid(_tutorial_grid, CATALOG.get_levels_for_category("tutorial"))
	_build_level_grid(_challenge_grid, CATALOG.get_levels_for_category("challenge"))
	_update_progress_label()
	_update_grid_columns()
	resized.connect(_update_grid_columns)
	_show_tutorial_category()
	_back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_return_to_main_menu()
		get_viewport().set_input_as_handled()


func _build_level_grid(grid: GridContainer, levels: Array[LevelDefinition]) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for level: LevelDefinition in levels:
		var card := LEVEL_CARD_SCENE.instantiate() as LevelCard
		grid.add_child(card)
		_cards.append(card)
		card.configure(level, _is_unlocked(level), test_all_levels_unlocked, bool(_completed.get(level.level_id, false)))
		card.level_selected.connect(_select_level)


func _is_unlocked(level: LevelDefinition) -> bool:
	if test_all_levels_unlocked:
		return true
	return level.unlock_after.is_empty() or bool(_completed.get(level.unlock_after, false))


func _show_tutorial_category() -> void:
	_tabs.current_tab = 0
	_tutorial_category_button.set_pressed_no_signal(true)
	_select_first_level("tutorial")


func _show_challenge_category() -> void:
	_tabs.current_tab = 1
	_challenge_category_button.set_pressed_no_signal(true)
	_select_first_level("challenge")


func _select_first_level(category: String) -> void:
	for card: LevelCard in _cards:
		var level := card.get_level()
		if level != null and level.category == category:
			_select_level(level)
			return


func _select_level(level: LevelDefinition) -> void:
	_selected_level = level
	for card: LevelCard in _cards:
		card.set_selected(card.get_level() == level)
	_detail_code.text = level.level_id
	_detail_title.text = level.title
	_detail_summary.text = level.summary
	_detail_objective.text = level.objective_text
	var enterable := _is_unlocked(level) and level.available
	_enter_button.disabled = not enterable
	_enter_button.text = "进入关卡" if enterable else "尚未解锁"
	if bool(_completed.get(level.level_id, false)):
		_detail_status.text = "军令状态：已完成，可再次演练"
	elif test_all_levels_unlocked and level.available:
		_detail_status.text = "军令状态：测试开放"
	elif enterable:
		_detail_status.text = "军令状态：可进入"
	elif not level.available:
		_detail_status.text = "军令状态：内容不可用"
	else:
		_detail_status.text = "军令状态：完成前置章节后解锁"


func _enter_selected_level() -> void:
	if _selected_level == null or _transitioning or not _selected_level.available or not _is_unlocked(_selected_level):
		return
	_transitioning = true
	get_tree().root.set_meta("veilfront_selected_level_id", _selected_level.level_id)
	var error := get_tree().change_scene_to_file(_selected_level.scene_path)
	if error != OK:
		_transitioning = false
		_status_label.text = "无法打开关卡：%s" % _selected_level.level_id


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
	_reset_dialog.popup_centered()


func _clear_tutorial_progress() -> void:
	_completed.clear()
	var config := ConfigFile.new()
	config.set_value("progress", "completed_ids", [])
	config.save("user://level_progress.cfg")
	_selected_level = null
	_cards.clear()
	_update_progress_label()
	_build_level_grid(_tutorial_grid, CATALOG.get_levels_for_category("tutorial"))
	_build_level_grid(_challenge_grid, CATALOG.get_levels_for_category("challenge"))
	_show_tutorial_category()


func _update_progress_label() -> void:
	var tutorial_levels := CATALOG.get_levels_for_category("tutorial")
	var completed_tutorials := 0
	for level: LevelDefinition in tutorial_levels:
		if bool(_completed.get(level.level_id, false)):
			completed_tutorials += 1
	_progress_label.text = "教学进度 %d / %d" % [completed_tutorials, tutorial_levels.size()]
	_progress_fraction.text = "%d / %d" % [completed_tutorials, tutorial_levels.size()]
	_progress_bar.max_value = tutorial_levels.size()
	_progress_bar.value = completed_tutorials


func _update_grid_columns() -> void:
	var column_count := 4 if size.x >= 1600.0 else (2 if size.x <= 1050.0 else 3)
	_tutorial_grid.columns = column_count
	_challenge_grid.columns = column_count
