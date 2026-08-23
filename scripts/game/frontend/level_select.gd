extends Control

const FrontendRoutes = preload("res://scripts/integration/frontend_routes.gd")
const LEVEL_CARD_SCENE := preload("res://scenes/game/frontend/level_card.tscn")
const CATALOG := preload("res://resources/game/levels/level_catalog.tres")
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const TUTORIAL_NODE_POSITIONS: Array[Vector2] = [
	Vector2(102, 24), Vector2(309, 24), Vector2(514, 20),
	Vector2(106, 156), Vector2(313, 156), Vector2(516, 156),
	Vector2(105, 286), Vector2(319, 286), Vector2(513, 285),
	Vector2(237, 397), Vector2(445, 397),
]
const CHALLENGE_NODE_POSITIONS: Array[Vector2] = [
	Vector2(102, 24), Vector2(309, 24), Vector2(514, 20),
]

@export var test_all_levels_unlocked: bool = true
@export var load_saved_progress: bool = true

@onready var _design_canvas: Control = %DesignCanvas
@onready var _back_button: Button = %BackButton
@onready var _tutorial_grid: Control = %TutorialGrid
@onready var _challenge_grid: Control = %ChallengeGrid
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
@onready var _status_label: Label = %StatusLabel
@onready var _reset_dialog: TerracottaModalDialog = %ResetDialog

var _transitioning := false
var _completed: Dictionary = {}
var _cards: Array[LevelCard] = []
var _selected_level: LevelDefinition
var _selected_card: LevelCard


func _ready() -> void:
	if load_saved_progress:
		_load_progress()
	_reset_dialog.confirmed.connect(_clear_tutorial_progress)
	_build_level_grid(_tutorial_grid, CATALOG.get_levels_for_category("tutorial"))
	_build_level_grid(_challenge_grid, CATALOG.get_levels_for_category("challenge"))
	_update_progress_label()
	_layout_design_canvas()
	resized.connect(_layout_design_canvas)
	_show_tutorial_category()
	_back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_return_to_title_screen()
		get_viewport().set_input_as_handled()


func _build_level_grid(grid: Control, levels: Array[LevelDefinition]) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var positions := TUTORIAL_NODE_POSITIONS if levels.size() > CHALLENGE_NODE_POSITIONS.size() else CHALLENGE_NODE_POSITIONS
	for index: int in levels.size():
		var level: LevelDefinition = levels[index]
		var card := LEVEL_CARD_SCENE.instantiate() as LevelCard
		grid.add_child(card)
		card.position = positions[index]
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
	if _selected_level == level:
		return
	var next_card: LevelCard
	for card: LevelCard in _cards:
		if card.get_level() == level:
			next_card = card
			break
	if _selected_card != null:
		_selected_card.set_selected(false)
	_selected_card = next_card
	if _selected_card != null:
		_selected_card.set_selected(true)
	_selected_level = level
	_detail_code.text = level.level_id
	_detail_title.text = level.title
	_detail_summary.text = level.summary
	_detail_objective.text = level.objective_text
	var enterable := _is_unlocked(level) and level.available
	_enter_button.disabled = not enterable
	_enter_button.text = "进入关卡" if enterable else "尚未解锁"


func _enter_selected_level() -> void:
	if _selected_level == null or _transitioning or not _selected_level.available or not _is_unlocked(_selected_level):
		return
	_transitioning = true
	get_tree().root.set_meta("veilfront_selected_level_id", _selected_level.level_id)
	_watch_transition_cancellation()
	var error := FrontendRoutes.navigate(
		get_tree(),
		_selected_level.scene_path,
		"正在布设%s…" % _selected_level.title
	)
	if error != OK:
		_unwatch_transition_cancellation()
		_transitioning = false
		_status_label.text = "无法打开关卡：%s" % _selected_level.level_id


func _return_to_title_screen() -> void:
	if _transitioning:
		return
	_transitioning = true
	_watch_transition_cancellation()
	var error := FrontendRoutes.navigate(
		get_tree(),
		FrontendRoutes.request_start_menu_ready(),
		"正在返回烽火关城…"
	)
	if error != OK:
		_unwatch_transition_cancellation()
		_transitioning = false
		_status_label.text = "无法返回标题页：%s" % error_string(error)


func _watch_transition_cancellation() -> void:
	var transition := FrontendRoutes.transition_service(get_tree())
	if transition == null:
		return
	transition.connect(
		&"transition_cancelled",
		_on_transition_cancelled,
		CONNECT_ONE_SHOT
	)


func _on_transition_cancelled(_scene_path: String) -> void:
	_transitioning = false


func _unwatch_transition_cancellation() -> void:
	var transition := FrontendRoutes.transition_service(get_tree())
	if (
		transition != null
		and transition.is_connected(&"transition_cancelled", _on_transition_cancelled)
	):
		transition.disconnect(&"transition_cancelled", _on_transition_cancelled)


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
	_selected_card = null
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
	_progress_label.text = "教学进度"
	_progress_fraction.text = "%d / %d" % [completed_tutorials, tutorial_levels.size()]
	_progress_bar.max_value = tutorial_levels.size()
	_progress_bar.value = completed_tutorials


func _layout_design_canvas() -> void:
	if not is_instance_valid(_design_canvas):
		return
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_design_canvas.scale = Vector2.ONE * factor
	_design_canvas.position = (size - DESIGN_SIZE * factor) * 0.5
