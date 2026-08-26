extends Control

const FormalLocalSession = preload("res://scripts/game/application/formal_local_session.gd")
const FrontendRoutes = preload("res://scripts/integration/frontend_routes.gd")
const TutorialChapterCatalog = preload("res://scripts/game/tutorial/tutorial_chapter_catalog.gd")
const TutorialProgressStore = preload("res://scripts/game/tutorial/tutorial_progress_store.gd")
const TERMINAL_LEVEL_DESTINATION: String = "level_select"
const DEFAULT_ROUTE_ID: String = "foundation"

@export var bootstrap_local_session: bool = true
@export var progress_path: String = "user://level_progress.cfg"

var _local_session: RefCounted
var _local_port: RefCounted
var _level_id: String = "T0"
var _scenario: TutorialScenarioDefinition
var _progress_store: TutorialProgressStore
var _route_module_ids: Array[String] = []


func _ready() -> void:
	$MatchScreen.set_level_guide_layout_enabled(true)
	$MatchScreen.set_tutorial_navigation_enabled(true)
	if not bootstrap_local_session:
		return
	_level_id = str(get_tree().root.get_meta("veilfront_selected_level_id", "T0"))
	_progress_store = TutorialProgressStore.new(progress_path, TutorialChapterCatalog.CATALOG)
	if not _progress_store.load_progress():
		push_error("TutorialLevel could not load curriculum progress")
	if _progress_store.selected_route() == null:
		if _level_id == "P0":
			_route_module_ids = ["P0"]
		else:
			_progress_store.select_route(DEFAULT_ROUTE_ID)
	if _route_module_ids.is_empty():
		_route_module_ids = _progress_store.selected_route().module_ids()
	if _level_id not in _route_module_ids:
		_level_id = _route_module_ids.front()
		get_tree().root.set_meta("veilfront_selected_level_id", _level_id)
	_progress_store.set_current_module(_level_id)
	_scenario = TutorialChapterCatalog.authority(_level_id)
	var presentation: TutorialPresentationTrack = TutorialChapterCatalog.presentation(_level_id)
	if _scenario == null or presentation == null:
		push_error("TutorialLevel could not resolve level %s" % _level_id)
		return
	$ApplicationHost.trusted_tutorial_scenario = _scenario
	$TutorialDirector.configure(_level_id, presentation)
	$TutorialOverlay.configure_chapter(
		presentation,
		_progress_store.completed_module_ids(),
		_route_module_ids
	)
	_bootstrap_local_session(_scenario)


func _bootstrap_local_session(scenario: TutorialScenarioDefinition) -> void:
	_local_session = FormalLocalSession.create_tutorial(scenario)
	if _local_session == null:
		push_error("TutorialLevel failed to create FormalLocalSession")
		return
	_bind_and_publish_local_session()


func _bind_and_publish_local_session() -> void:
	if _local_session == null:
		push_error("TutorialLevel failed to create FormalLocalSession")
		return
	_local_port = _local_session.create_client_port("red")
	var host: ApplicationHost = $ApplicationHost
	if not host.bind_client_port(_local_port):
		push_error("TutorialLevel failed to bind FormalLocalSession")
		return
	var publish_result: Dictionary = _local_port.publish_current()
	if not bool(publish_result.get("ok", false)):
		push_error("TutorialLevel failed to publish initial PlayerView: %s" % str(publish_result))


func get_level_id() -> String:
	return _level_id


func _on_player_view_updated(player_view: Dictionary) -> void:
	if not _level_id.begins_with("C") or not bool(player_view.get("terminal", false)):
		return
	$MatchScreen.show_level_terminal(player_view)


func _on_terminal_restart_requested() -> void:
	if not _level_id.begins_with("C"):
		return
	$ApplicationHost.request_restart()


func _on_terminal_exit_requested(destination: String) -> void:
	if destination == TERMINAL_LEVEL_DESTINATION:
		return_to_level_select()


func focus_tutorial_step(step: Dictionary) -> void:
	$MatchScreen.focus_tutorial_step(step)


func apply_tutorial_step_effect(step_id: String) -> void:
	call_deferred("_apply_tutorial_step_effect", step_id)


func _apply_tutorial_step_effect(step_id: String) -> void:
	if _scenario == null or _scenario.effect_for_step(step_id).is_empty():
		return
	if _local_port != null and _local_port.has_method("apply_tutorial_transition"):
		_local_port.apply_tutorial_transition(step_id)


func return_to_level_select() -> void:
	get_tree().paused = false
	var error := FrontendRoutes.navigate(
		get_tree(),
		FrontendRoutes.level_select_scene(),
		"正在返回关卡战图…"
	)
	if error != OK:
		push_error("TutorialLevel could not return to level select: %s" % error_string(error))


func advance_to_next_level() -> void:
	var current_index := _route_module_ids.find(_level_id)
	if current_index < 0 or current_index >= _route_module_ids.size() - 1:
		return_to_level_select()
		return
	var next_level_id := _route_module_ids[current_index + 1]
	get_tree().root.set_meta("veilfront_selected_level_id", next_level_id)
	var error := FrontendRoutes.navigate(
		get_tree(),
		"res://scenes/game/tutorial/tutorial_level.tscn",
		"正在布设下一处战场…"
	)
	if error != OK:
		push_error("TutorialLevel could not advance to %s: %s" % [next_level_id, error_string(error)])


func handle_level_skipped(level_id_value: String) -> void:
	if not bootstrap_local_session:
		return
	if _progress_store != null:
		_progress_store.record_module_skipped(level_id_value)
	call_deferred("advance_to_next_level")


func stay_on_completed_chapter() -> void:
	$TutorialOverlay.hide_completion_actions()


func record_level_completion(level_id: String) -> void:
	if _progress_store != null and not _progress_store.record_module_completed(level_id):
		push_error("TutorialLevel could not record curriculum progress for %s" % level_id)


func get_layout_snapshot() -> Dictionary:
	var screen_snapshot: Dictionary = $MatchScreen.get_layout_snapshot()
	var ui_rects: Dictionary = screen_snapshot.get("ui_rects", {})
	var guide_layout: Dictionary = $TutorialOverlay.get_layout_snapshot()
	var tutorial_rect: Rect2 = guide_layout.get("guide_rect", Rect2())
	var tutorial_content_rect: Rect2 = guide_layout.get("guide_content_rect", Rect2())
	return {
		"board_rect": screen_snapshot.get("board_rect", Rect2()),
		"tutorial_rect": tutorial_rect,
		"tutorial_content_rect": tutorial_content_rect,
		"objective_rect": ui_rects.get("right-rail", Rect2()),
		"center_column_rect": ui_rects.get("center-column", Rect2()),
		"decision_rect": guide_layout.get("decision_rect", Rect2()),
		"buttons_inside": bool(guide_layout.get("buttons_inside", false)),
		"actions_scrollable": bool(guide_layout.get("actions_scrollable", false)),
	}
