extends SceneTree

const GAME_APP_SCENE: PackedScene = preload("res://scenes/game/app/game_app.tscn")
const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")
const FixtureMatchClientPort = preload("res://tests/game/contracts/fixture_match_client_port.gd")
const RED_VIEW_PATH: String = "res://tests/game/contracts/fixtures/red_player_view_minimal_v1.json"
const BLACK_VIEW_PATH: String = "res://tests/game/contracts/fixtures/black_player_view_minimal_v1.json"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_parallel_session_isolation()
	await _check_tutorial_flow()
	await _check_tutorial_authority_rejections()
	await _check_tutorial_seat_rejection()
	_check_tutorial_authority_boundary()

	if _failures.is_empty():
		print("TUTORIAL_SHELL_SMOKE_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_SHELL_SMOKE_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_parallel_session_isolation() -> void:
	var red_app: Control = GAME_APP_SCENE.instantiate() as Control
	var black_app: Control = GAME_APP_SCENE.instantiate() as Control
	root.add_child(red_app)
	root.add_child(black_app)
	await process_frame

	var red_host: Node = red_app.get_node("ApplicationHost")
	var black_host: Node = black_app.get_node("ApplicationHost")
	var red_screen: Control = red_app.get_node("ScreenHost/MatchScreen") as Control
	var black_screen: Control = black_app.get_node("ScreenHost/MatchScreen") as Control
	var red_port: RefCounted = FixtureMatchClientPort.new(RED_VIEW_PATH)
	var black_port: RefCounted = FixtureMatchClientPort.new(BLACK_VIEW_PATH)

	_expect(red_host.has_method("bind_client_port"), "GameApp ApplicationHost is not implemented")
	if not red_host.has_method("bind_client_port"):
		red_app.queue_free()
		black_app.queue_free()
		await process_frame
		return
	_expect(red_host.bind_client_port(red_port), "red fixture port failed to bind")
	_expect(black_host.bind_client_port(black_port), "black fixture port failed to bind")
	_expect(bool(red_port.publish_fixture().get("ok", false)), "red fixture failed to publish")
	await process_frame
	var red_snapshot: Dictionary = red_screen.get_presentation_snapshot()
	var black_snapshot: Dictionary = black_screen.get_presentation_snapshot()
	_expect(str(red_snapshot.get("match_id", "")) == "fixture-red", "red session did not consume its PlayerView")
	_expect(str(black_snapshot.get("match_id", "")) == "", "red PlayerView crossed into black session")

	_expect(bool(black_port.publish_fixture().get("ok", false)), "black fixture failed to publish")
	await process_frame
	red_snapshot = red_screen.get_presentation_snapshot()
	black_snapshot = black_screen.get_presentation_snapshot()
	_expect(str(red_snapshot.get("match_id", "")) == "fixture-red", "black publish mutated red session")
	_expect(str(black_snapshot.get("match_id", "")) == "fixture-black", "black session did not consume its PlayerView")

	red_screen.request_action_previews("fixture-piece", "move")
	red_screen.prepare_action("fixture-preview")
	await process_frame
	_expect(red_screen.get_local_interaction_state() == "CONFIRMING", "prepared action did not enter CONFIRMING")
	red_screen.handle_cancel_or_marker(Vector2i(1, 1))
	await process_frame
	_expect(red_screen.get_local_interaction_state() == "IDLE", "prepared action cancel did not return to IDLE")
	_expect(red_port.count_request("request_action_previews") == 1, "preview request was not delegated once")
	_expect(red_port.count_request("prepare_action") == 1, "prepare request was not delegated once")
	_expect(red_port.count_request("cancel_prepared_action") == 1, "cancel request was not delegated once")
	_expect(red_port.count_request("confirm_prepared_action") == 0, "cancelled action was incorrectly confirmed")

	red_screen.prepare_action("fixture-preview")
	red_screen.confirm_prepared_action()
	await process_frame
	_expect(red_port.count_request("confirm_prepared_action") == 1, "confirm request was not delegated once")
	_expect(black_port.get_request_log().is_empty(), "red interaction crossed into black port")

	red_app.queue_free()
	black_app.queue_free()
	await process_frame


func _check_tutorial_flow() -> void:
	var tutorial_level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	tutorial_level.bootstrap_local_session = false
	root.add_child(tutorial_level)
	await process_frame
	var host: Node = tutorial_level.get_node("ApplicationHost")
	var screen: Control = tutorial_level.get_node("MatchScreen") as Control
	var director: Node = tutorial_level.get_node_or_null("TutorialDirector")
	var overlay: Control = tutorial_level.get_node("TutorialOverlay") as Control
	var port: RefCounted = FixtureMatchClientPort.new(RED_VIEW_PATH)

	_expect(director != null, "TutorialLevel is missing preset TutorialDirector")
	if director == null or not host.has_method("bind_client_port"):
		tutorial_level.queue_free()
		await process_frame
		return
	_expect(host.bind_client_port(port), "tutorial fixture port failed to bind")
	_expect(host.has_trusted_tutorial_scenario(), "tutorial authority Resource is not bound to ApplicationHost")
	_expect(bool(port.publish_fixture().get("ok", false)), "tutorial fixture failed to publish")
	await process_frame
	_expect(str(director.get_public_state()) == "PROMPTING", "visible fixture event did not open a tutorial prompt")
	_expect(str(overlay.get_public_snapshot().get("step_id", "")) == "observe_board", "tutorial overlay did not render public track step")

	screen.prepare_action("fixture-preview")
	await process_frame
	screen.handle_cancel_or_marker(Vector2i(1, 1))
	await process_frame
	_expect(str(director.get_public_state()) == "CANCELLED", "tutorial director did not observe prepared-action cancel")

	overlay.request_retry()
	await process_frame
	_expect(str(director.get_public_state()) == "RETRYING", "tutorial retry state was not entered")
	_expect(port.count_request("request_restart") == 1, "tutorial retry did not use MatchClientPort")
	overlay.request_skip()
	await process_frame
	_expect(str(director.get_public_state()) == "SKIPPED", "tutorial skip state was not entered")
	_expect(port.count_request("request_skip") == 1, "tutorial skip did not use MatchClientPort")
	overlay.request_exit()
	await process_frame
	_expect(str(director.get_public_state()) == "EXITED", "tutorial exit state was not entered")

	tutorial_level.queue_free()
	await process_frame


func _check_tutorial_authority_boundary() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/game/tutorial/tutorial_director.gd")
	_expect(FileAccess.get_open_error() == OK, "TutorialDirector source is missing")
	for forbidden: String in ["tutorials/authority", "TutorialScenarioDefinition", "trusted_tutorial_scenario"]:
		_expect(not source.contains(forbidden), "TutorialDirector references authority-only input: %s" % forbidden)
	_expect(
		ResourceLoader.exists("res://resources/game/tutorials/authority/tutorial_smoke_authority.tres"),
		"authority tutorial Resource is missing"
	)
	_expect(
		ResourceLoader.exists("res://resources/game/tutorials/presentation/tutorial_smoke_track.tres"),
		"presentation tutorial Resource is missing"
	)
	var presentation_source: String = FileAccess.get_file_as_string(
		"res://scripts/game/tutorial/tutorial_presentation_track.gd"
	)
	_expect(
		not presentation_source.contains("retry_allowed")
		and not presentation_source.contains("skip_allowed"),
		"presentation track must not own retry/skip authorization"
	)
	var scene_source: String = FileAccess.get_file_as_string(
		"res://scenes/game/tutorial/tutorial_level.tscn"
	)
	_expect(
		not scene_source.contains(
			'signal="skip_requested" from="MatchScreen" to="ApplicationHost"'
		),
		"MatchScreen skip must not bypass the tutorial authorization path"
	)


func _check_tutorial_authority_rejections() -> void:
	var tutorial_level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	tutorial_level.bootstrap_local_session = false
	root.add_child(tutorial_level)
	await process_frame
	var host: Node = tutorial_level.get_node("ApplicationHost")
	var screen: Control = tutorial_level.get_node("MatchScreen") as Control
	var director: Node = tutorial_level.get_node("TutorialDirector")
	var overlay: Control = tutorial_level.get_node("TutorialOverlay") as Control
	var denied_scenario: Resource = host.trusted_tutorial_scenario.duplicate(true)
	denied_scenario.restart_allowed = false
	denied_scenario.skip_allowed = false
	host.trusted_tutorial_scenario = denied_scenario
	var port: RefCounted = FixtureMatchClientPort.new(RED_VIEW_PATH)

	_expect(host.bind_client_port(port), "authority rejection fixture port failed to bind")
	_expect(bool(port.publish_fixture().get("ok", false)), "authority rejection fixture failed to publish")
	await process_frame
	_expect(str(director.get_public_state()) == "PROMPTING", "authority rejection baseline did not prompt")

	host.prepare_action("forbidden-preview")
	host.confirm_prepared_action("forbidden-preview")
	_expect(port.count_request("prepare_action") == 0, "forbidden tutorial preview was prepared")
	_expect(port.count_request("confirm_prepared_action") == 0, "forbidden tutorial preview was confirmed")
	host.prepare_action("fixture-preview")
	host.confirm_prepared_action("fixture-preview")
	_expect(port.count_request("prepare_action") == 1, "authority-allowed tutorial preview was not prepared")
	_expect(port.count_request("confirm_prepared_action") == 1, "authority-allowed tutorial preview was not confirmed")

	overlay.request_retry()
	overlay.request_skip()
	host.request_restart()
	host.request_skip()
	await process_frame
	_expect(port.count_request("request_restart") == 0, "authority denied tutorial restart was forwarded")
	_expect(port.count_request("request_skip") == 0, "authority denied tutorial skip was forwarded")
	_expect(str(director.get_public_state()) == "PROMPTING", "denied presentation request changed tutorial state")

	var screen_skip_targets_host: bool = false
	var screen_skip_targets_director: bool = false
	for connection: Dictionary in screen.skip_requested.get_connections():
		var callable: Callable = connection.get("callable", Callable())
		screen_skip_targets_host = screen_skip_targets_host or callable.get_object() == host
		screen_skip_targets_director = screen_skip_targets_director or callable.get_object() == director
	_expect(not screen_skip_targets_host, "MatchScreen skip still targets ApplicationHost directly")
	_expect(screen_skip_targets_director, "MatchScreen skip is not routed through TutorialDirector")

	tutorial_level.queue_free()
	await process_frame


func _check_tutorial_seat_rejection() -> void:
	var tutorial_level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	tutorial_level.bootstrap_local_session = false
	root.add_child(tutorial_level)
	await process_frame
	var host: Node = tutorial_level.get_node("ApplicationHost")
	var screen: Control = tutorial_level.get_node("MatchScreen") as Control
	var mismatched_scenario: Resource = host.trusted_tutorial_scenario.duplicate(true)
	mismatched_scenario.bound_seat = "black"
	host.trusted_tutorial_scenario = mismatched_scenario
	var port: RefCounted = FixtureMatchClientPort.new(RED_VIEW_PATH)

	_expect(host.bind_client_port(port), "seat rejection fixture port failed to bind")
	_expect(bool(port.publish_fixture().get("ok", false)), "seat rejection fixture failed to publish")
	await process_frame
	_expect(
		str(screen.get_presentation_snapshot().get("match_id", "")).is_empty(),
		"mismatched tutorial seat received PlayerView"
	)
	host.prepare_action("fixture-preview")
	host.confirm_prepared_action("fixture-preview")
	host.request_restart()
	host.request_skip()
	_expect(port.count_request("prepare_action") == 0, "mismatched tutorial seat prepared an action")
	_expect(port.count_request("confirm_prepared_action") == 0, "mismatched tutorial seat confirmed an action")
	_expect(port.count_request("request_restart") == 0, "mismatched tutorial seat restarted")
	_expect(port.count_request("request_skip") == 0, "mismatched tutorial seat skipped")

	tutorial_level.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
