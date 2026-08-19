extends Control

const FormalLocalSession = preload("res://scripts/game/application/formal_local_session.gd")
const TutorialChapterCatalog = preload("res://scripts/game/tutorial/tutorial_chapter_catalog.gd")

@export var session_seed: int = 471001
@export var bootstrap_local_session: bool = true
@export var progress_path: String = "user://level_progress.cfg"

var _local_session: RefCounted
var _local_port: RefCounted
var _level_id: String = "T0"


func _ready() -> void:
	if not bootstrap_local_session:
		return
	_level_id = str(get_tree().root.get_meta("veilfront_selected_level_id", "T0"))
	var scenario: TutorialScenarioDefinition = TutorialChapterCatalog.authority(_level_id)
	var presentation: TutorialPresentationTrack = TutorialChapterCatalog.presentation(_level_id)
	if scenario == null or presentation == null:
		push_error("TutorialLevel could not resolve chapter %s" % _level_id)
		return
	$ApplicationHost.trusted_tutorial_scenario = scenario
	$TutorialDirector.configure(_level_id, presentation)
	$TutorialOverlay.configure_chapter(presentation)
	$MatchScreen.set_tutorial_panel_width(422.0)
	_bootstrap_local_session(scenario)


func _bootstrap_local_session(scenario: TutorialScenarioDefinition) -> void:
	_local_session = FormalLocalSession.create_tutorial(
		scenario,
		{"full_round_limit_hypothesis": 50}
	)
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


func return_to_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/game/frontend/level_select.tscn")


func record_level_completion(level_id: String) -> void:
	var config := ConfigFile.new()
	var load_error := config.load(progress_path)
	if load_error not in [OK, ERR_FILE_NOT_FOUND]:
		push_error("TutorialLevel could not load progress file: %s" % error_string(load_error))
		return
	var completed_ids: Array = []
	var saved_ids: Variant = config.get_value("progress", "completed_ids", [])
	if saved_ids is Array:
		completed_ids = saved_ids.duplicate()
	if level_id not in completed_ids:
		completed_ids.append(level_id)
		completed_ids.sort()
	config.set_value("progress", "completed_ids", completed_ids)
	var save_error := config.save(progress_path)
	if save_error != OK:
		push_error("TutorialLevel could not save progress file: %s" % error_string(save_error))


func get_layout_snapshot() -> Dictionary:
	var screen_snapshot: Dictionary = $MatchScreen.get_layout_snapshot()
	var tutorial: Control = $TutorialOverlay
	var tutorial_rect := Rect2(tutorial.global_position - global_position, tutorial.size)
	var buttons_inside := true
	for button_name: String in ["RetryButton", "SkipButton", "BackToLevelsButton", "HintButton"]:
		var button: Control = tutorial.find_child(button_name, true, false) as Control
		if button == null:
			buttons_inside = false
			continue
		var button_rect := Rect2(button.global_position - global_position, button.size)
		buttons_inside = buttons_inside \
			and button_rect.position.x >= -0.5 \
			and button_rect.position.y >= -0.5 \
			and button_rect.end.x <= size.x + 0.5 \
			and button_rect.end.y <= size.y + 0.5
	return {
		"board_rect": screen_snapshot.get("board_rect", Rect2()),
		"tutorial_rect": tutorial_rect,
		"buttons_inside": buttons_inside,
		"actions_scrollable": tutorial.get_node_or_null("Margin") is ScrollContainer,
	}
