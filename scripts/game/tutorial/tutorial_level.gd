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
		if _level_id in ["C1", "C2", "C3"]:
			_bootstrap_challenge_test_entry()
			return
		push_error("TutorialLevel could not resolve level %s" % _level_id)
		return
	$ApplicationHost.trusted_tutorial_scenario = scenario
	$TutorialDirector.configure(_level_id, presentation)
	$TutorialOverlay.configure_chapter(presentation, _load_completed_ids())
	$MatchScreen.set_tutorial_panel_width(422.0)
	$MatchScreen.set_tutorial_navigation_enabled(true)
	_bootstrap_local_session(scenario)


func _bootstrap_local_session(scenario: TutorialScenarioDefinition) -> void:
	_local_session = FormalLocalSession.create_tutorial(
		scenario,
		{"full_round_limit_hypothesis": 50}
	)
	if _local_session == null:
		push_error("TutorialLevel failed to create FormalLocalSession")
		return
	_bind_and_publish_local_session()


func _bootstrap_challenge_test_entry() -> void:
	$ApplicationHost.trusted_tutorial_scenario = null
	$TutorialDirector.presentation_track = null
	$TutorialOverlay.configure_graybox_entry(_level_id)
	$MatchScreen.set_tutorial_panel_width(422.0)
	$MatchScreen.set_tutorial_navigation_enabled(true)
	_local_session = FormalLocalSession.create(
		session_seed + int(_level_id.trim_prefix("C")),
		{
			"full_round_limit_hypothesis": 50,
			"scripted_opponent_pass": true,
		}
	)
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


func focus_tutorial_step(step: Dictionary) -> void:
	$MatchScreen.focus_tutorial_step(step)


func apply_tutorial_step_effect(step_id: String) -> void:
	call_deferred("_apply_tutorial_step_effect", step_id)


func _apply_tutorial_step_effect(step_id: String) -> void:
	if _local_port != null and _local_port.has_method("apply_tutorial_transition"):
		_local_port.apply_tutorial_transition(step_id)


func return_to_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/game/frontend/level_select.tscn")


func advance_to_next_level() -> void:
	var current_index := TutorialChapterCatalog.TUTORIAL_IDS.find(_level_id)
	if current_index < 0 or current_index >= TutorialChapterCatalog.TUTORIAL_IDS.size() - 1:
		return_to_level_select()
		return
	var next_level_id := TutorialChapterCatalog.TUTORIAL_IDS[current_index + 1]
	get_tree().root.set_meta("veilfront_selected_level_id", next_level_id)
	get_tree().change_scene_to_file("res://scenes/game/tutorial/tutorial_level.tscn")


func handle_level_skipped(_level_id_value: String) -> void:
	if not bootstrap_local_session:
		return
	call_deferred("advance_to_next_level")


func stay_on_completed_chapter() -> void:
	$TutorialOverlay.find_child("CompletionActions", true, false).visible = false


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


func _load_completed_ids() -> Array[String]:
	var completed_ids: Array[String] = []
	var config := ConfigFile.new()
	if config.load(progress_path) != OK:
		return completed_ids
	var saved_ids: Variant = config.get_value("progress", "completed_ids", [])
	if saved_ids is Array:
		for level_id: Variant in saved_ids:
			completed_ids.append(str(level_id))
	return completed_ids


func get_layout_snapshot() -> Dictionary:
	var screen_snapshot: Dictionary = $MatchScreen.get_layout_snapshot()
	var tutorial: Control = $TutorialOverlay
	var tutorial_rect := Rect2(tutorial.global_position - global_position, tutorial.size)
	var buttons_inside := true
	for button_name: String in ["RetryButton", "SkipButton", "BackToLevelsButton", "HintButton", "TutorialFoldable"]:
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
		"actions_scrollable": tutorial.get_node_or_null("TutorialFoldable/Margin") is ScrollContainer,
	}
