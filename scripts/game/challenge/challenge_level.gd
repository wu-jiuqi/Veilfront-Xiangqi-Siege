class_name ChallengeLevel
extends Control

const ChallengeCatalog = preload("res://scripts/game/challenge/challenge_catalog.gd")
const ChallengeSession = preload("res://scripts/game/challenge/challenge_session.gd")
const FrontendRoutes = preload("res://scripts/integration/frontend_routes.gd")
const TERMINAL_LEVEL_DESTINATION: String = "level_select"

@export var bootstrap_local_session: bool = true
@export var progress_path: String = "user://level_progress.cfg"

var _definition: ChallengeDefinition
var _local_session: RefCounted
var _local_port: RefCounted
var _level_id: String = "C1"
var _completion_recorded: bool = false


func _ready() -> void:
	$MatchScreen.set_level_navigation_enabled(true)
	if not bootstrap_local_session:
		return
	_level_id = str(get_tree().root.get_meta("veilfront_selected_level_id", "C1"))
	_definition = ChallengeCatalog.definition(_level_id)
	if _definition == null or not _definition.is_valid_definition():
		push_error("ChallengeLevel could not resolve level %s" % _level_id)
		return
	_local_session = ChallengeSession.create(_definition)
	if _local_session == null:
		push_error("ChallengeLevel failed to create ChallengeSession for %s" % _level_id)
		return
	_local_port = _local_session.create_client_port("red")
	var host: ApplicationHost = $ApplicationHost
	if _local_port == null or not host.bind_client_port(_local_port):
		push_error("ChallengeLevel failed to bind ChallengeSession for %s" % _level_id)
		return
	var publish_result: Dictionary = _local_port.publish_current()
	if not bool(publish_result.get("ok", false)):
		push_error("ChallengeLevel failed to publish initial PlayerView: %s" % str(publish_result))


func get_level_id() -> String:
	return _level_id


func _on_player_view_updated(player_view: Dictionary) -> void:
	if not bool(player_view.get("terminal", false)):
		return
	$MatchScreen.show_level_terminal(player_view)
	if not _completion_recorded and str(player_view.get("winner", "")) == "red":
		_completion_recorded = true
		_record_level_completion()


func _on_terminal_restart_requested() -> void:
	_completion_recorded = false
	$ApplicationHost.request_restart()


func _on_terminal_exit_requested(destination: String) -> void:
	if destination == TERMINAL_LEVEL_DESTINATION:
		return_to_level_select()


func return_to_level_select() -> void:
	get_tree().paused = false
	var error := FrontendRoutes.navigate(
		get_tree(),
		FrontendRoutes.level_select_scene(),
		"正在返回关卡战图…",
	)
	if error != OK:
		push_error("ChallengeLevel could not return to level select: %s" % error_string(error))


func _record_level_completion() -> void:
	var config := ConfigFile.new()
	var load_error := config.load(progress_path)
	if load_error not in [OK, ERR_FILE_NOT_FOUND]:
		push_error("ChallengeLevel could not load progress file: %s" % error_string(load_error))
		return
	var completed_ids: Array = []
	var saved_ids: Variant = config.get_value("progress", "completed_ids", [])
	if saved_ids is Array:
		completed_ids = saved_ids.duplicate()
	if _level_id not in completed_ids:
		completed_ids.append(_level_id)
		completed_ids.sort()
	config.set_value("progress", "completed_ids", completed_ids)
	var save_error := config.save(progress_path)
	if save_error != OK:
		push_error("ChallengeLevel could not save progress file: %s" % error_string(save_error))
