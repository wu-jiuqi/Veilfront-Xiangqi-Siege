extends Control

const FrontendRoutes = preload("res://scripts/integration/frontend_routes.gd")
const LEVEL_CARD_SCENE := preload("res://scenes/game/frontend/level_card.tscn")
const CATALOG := preload("res://resources/game/levels/level_catalog.tres")
const TutorialChapterCatalog = preload("res://scripts/game/tutorial/tutorial_chapter_catalog.gd")
const TutorialProgressStore = preload("res://scripts/game/tutorial/tutorial_progress_store.gd")
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const CHALLENGE_NODE_POSITIONS: Array[Vector2] = [
	Vector2(102, 24), Vector2(309, 24), Vector2(514, 20),
]
const TUTORIAL_COLUMNS: int = 5
const TUTORIAL_COLUMN_STEP: float = 132.0
const TUTORIAL_ROW_STEP: float = 118.0
const TUTORIAL_GRID_ORIGIN := Vector2(12.0, 4.0)

@export var test_all_levels_unlocked: bool = false
@export var load_saved_progress: bool = true
@export var progress_path: String = "user://level_progress.cfg"

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
@onready var _foundation_route_button: Button = %FoundationRouteButton
@onready var _experienced_route_button: Button = %ExperiencedRouteButton
@onready var _route_summary: Label = %RouteSummary
@onready var _route_strip: HBoxContainer = %RouteStrip
@onready var _tutorial_codex: TutorialCodex = %TutorialCodex

var _transitioning := false
var _completed: Dictionary = {}
var _cards: Array[LevelCard] = []
var _selected_level: LevelDefinition
var _selected_card: LevelCard
var _progress_store: TutorialProgressStore
var _route: TutorialRouteDefinition


func _ready() -> void:
	_progress_store = TutorialProgressStore.new(progress_path, TutorialChapterCatalog.CATALOG)
	if load_saved_progress:
		_progress_store.load_progress()
		_load_progress()
	_route = _progress_store.selected_route()
	_reset_dialog.confirmed.connect(_clear_tutorial_progress)
	_foundation_route_button.pressed.connect(_select_route.bind("foundation"))
	_experienced_route_button.pressed.connect(_select_route.bind("xiangqi_experienced"))
	_rebuild_tutorial_grid()
	_build_level_grid(_challenge_grid, CATALOG.get_levels_for_category("challenge"))
	_update_progress_label()
	_sync_route_strip()
	_layout_design_canvas()
	resized.connect(_layout_design_canvas)
	_show_tutorial_category()
	_back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _reset_dialog.visible or _tutorial_codex.visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		_return_to_title_screen()
		get_viewport().set_input_as_handled()


func _build_level_grid(grid: Control, levels: Array[LevelDefinition]) -> void:
	for child in grid.get_children():
		_cards.erase(child)
		grid.remove_child(child)
		child.queue_free()
	for index: int in levels.size():
		var level: LevelDefinition = levels[index]
		var card := LEVEL_CARD_SCENE.instantiate() as LevelCard
		grid.add_child(card)
		card.position = _tutorial_node_position(index) \
			if level.category == "tutorial" else CHALLENGE_NODE_POSITIONS[index]
		_cards.append(card)
		var state := _module_state(level.level_id) if level.category == "tutorial" \
			else TutorialProgressStore.COMPLETED if bool(_completed.get(level.level_id, false)) \
			else TutorialProgressStore.UNSEEN
		card.configure(
			level,
			_is_unlocked(level),
			test_all_levels_unlocked,
			state == TutorialProgressStore.COMPLETED,
			state
		)
		card.level_selected.connect(_select_level)


func _is_unlocked(level: LevelDefinition) -> bool:
	if test_all_levels_unlocked:
		return true
	if level.category == "tutorial":
		if _route == null:
			return level.level_id == "P0"
		var module_ids := _route.module_ids()
		var index := module_ids.find(level.level_id)
		return index == 0 or index > 0 and _progress_store.module_is_resolved(module_ids[index - 1])
	return level.unlock_after.is_empty() or bool(_completed.get(level.unlock_after, false))


func _show_tutorial_category() -> void:
	_tabs.current_tab = 0
	_route_strip.show()
	_tutorial_category_button.set_pressed_no_signal(true)
	_select_first_level("tutorial")


func _show_challenge_category() -> void:
	_tabs.current_tab = 1
	_route_strip.hide()
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
	if config.load(progress_path) != OK:
		return
	var saved_ids: Variant = config.get_value("progress", "completed_ids", [])
	if saved_ids is Array:
		for level_id: Variant in saved_ids:
			var definition := CATALOG.find_level(str(level_id))
			if definition != null:
				_completed[definition.level_id] = true
	for level_id: String in _progress_store.completed_module_ids():
		_completed[level_id] = true


func _on_reset_progress() -> void:
	_reset_dialog.popup_centered()


func _clear_tutorial_progress() -> void:
	_progress_store.reset_tutorial_progress()
	_route = null
	_completed.clear()
	_load_progress()
	_selected_level = null
	_selected_card = null
	_cards.clear()
	_update_progress_label()
	_rebuild_tutorial_grid()
	_build_level_grid(_challenge_grid, CATALOG.get_levels_for_category("challenge"))
	_sync_route_strip()
	_show_tutorial_category()


func _update_progress_label() -> void:
	var module_ids := _active_module_ids()
	var resolved := 0
	for module_id: String in module_ids:
		if _progress_store.module_is_resolved(module_id):
			resolved += 1
	_progress_label.text = "核心就绪" if _progress_store.is_core_ready() else "教学进度"
	_progress_fraction.text = "%d / %d" % [resolved, module_ids.size()]
	_progress_bar.max_value = maxi(1, module_ids.size())
	_progress_bar.value = resolved


func _select_route(route_id: String) -> void:
	if not _progress_store.select_route(route_id):
		_status_label.text = "无法保存学习路线。"
		return
	_route = _progress_store.selected_route()
	_selected_level = null
	_selected_card = null
	_rebuild_tutorial_grid()
	_update_progress_label()
	_sync_route_strip()
	_select_first_level("tutorial")


func _rebuild_tutorial_grid() -> void:
	var levels: Array[LevelDefinition] = []
	for module_id: String in _active_module_ids():
		var definition := CATALOG.find_level(module_id)
		if definition != null:
			levels.append(definition)
	_build_level_grid(_tutorial_grid, levels)


func _active_module_ids() -> Array[String]:
	if _route != null:
		return _route.module_ids()
	var onboarding_ids: Array[String] = ["P0"]
	return onboarding_ids


func _module_state(module_id: String) -> String:
	if module_id in _progress_store.completed_module_ids():
		return TutorialProgressStore.COMPLETED
	if module_id in _progress_store.skipped_module_ids():
		return TutorialProgressStore.SKIPPED
	var module := TutorialChapterCatalog.module(module_id)
	if module != null:
		for capability_id: String in module.capability_ids:
			if _progress_store.capability_state(capability_id) == TutorialProgressStore.NEEDS_REVIEW:
				return TutorialProgressStore.NEEDS_REVIEW
			if _progress_store.capability_state(capability_id) == TutorialProgressStore.ASSUMED:
				return TutorialProgressStore.ASSUMED
	return TutorialProgressStore.UNSEEN


func _sync_route_strip() -> void:
	var route_id := _route.route_id if _route != null else ""
	_foundation_route_button.set_pressed_no_signal(route_id == "foundation")
	_experienced_route_button.set_pressed_no_signal(route_id == "xiangqi_experienced")
	_route_summary.text = "完成 P0 后选路线；进度会合并。" \
		if _route == null else "%s · 核心%s · 毕业%s" % [
			_route.title,
			"已就绪" if _progress_store.is_core_ready() else "学习中",
			"已完成" if _progress_store.is_complete_ready() else "未完成",
		]
	_route_summary.tooltip_text = _route.description if _route != null \
		else "两条路线复用同一套正式规则课程，可随时切换。"


func _tutorial_node_position(index: int) -> Vector2:
	return TUTORIAL_GRID_ORIGIN + Vector2(
		float(index % TUTORIAL_COLUMNS) * TUTORIAL_COLUMN_STEP,
		float(index / TUTORIAL_COLUMNS) * TUTORIAL_ROW_STEP
	)


func _layout_design_canvas() -> void:
	if not is_instance_valid(_design_canvas):
		return
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_design_canvas.scale = Vector2.ONE * factor
	_design_canvas.position = (size - DESIGN_SIZE * factor) * 0.5
