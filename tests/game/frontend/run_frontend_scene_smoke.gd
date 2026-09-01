extends SceneTree

const CATALOG := preload("res://resources/game/levels/level_catalog.tres")
const START_SCENE := preload("res://scenes/game/frontend/start_screen.tscn")
const LEVEL_SCENE := preload("res://scenes/game/frontend/level_select.tscn")
const TEST_PROGRESS_PATH := "user://frontend-scene-smoke-progress.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(CATALOG.levels.size() == 21, "catalog must contain 18 tutorials and C1-C3")
	_expect(CATALOG.find_level("P0").available, "P0 must remain available")
	_expect(CATALOG.find_level("T1").unlock_after == "T0", "tutorial unlock chain changed")
	_expect(CATALOG.find_level("C1").category == "challenge", "C1 must remain a challenge")

	var start_root := START_SCENE.instantiate() as Control
	root.add_child(start_root)
	await process_frame
	_expect(start_root != null, "start screen failed to instantiate")
	if start_root != null:
		_expect(
			start_root.theme.resource_path == "res://resources/game/ui/themes/veilfront_ui_theme_v2.tres",
			"start screen must use the rebuilt unified theme",
		)
		var prompt := start_root.get_node("%EnterPrompt") as Label
		_expect(prompt != null and prompt.text == "点击任意位置继续", "opening prompt changed")
		var sequence := start_root.get_node("%SequencePlayer") as AnimationPlayer
		_expect(sequence != null and sequence.has_animation(&"opening_sequence"), "opening sequence is missing")
		if sequence != null and sequence.has_animation(&"opening_sequence"):
			_expect(is_equal_approx(sequence.get_animation(&"opening_sequence").length, 4.85), "opening timing changed")
		var overlay := start_root.get_node("%MenuOverlay") as Control
		_expect(
			overlay.theme.resource_path == "res://resources/game/ui/themes/veilfront_ui_theme_v2.tres",
			"menu overlay must use the rebuilt unified theme",
		)
		_expect(
			(overlay.get_node("SafeMargin/ContentRoot/MenuPanel") as PanelContainer).get_theme_stylebox(&"panel") is StyleBoxFlat,
			"main menu panel must be a scalable surface",
		)
	start_root.queue_free()
	await process_frame

	_remove_progress()
	var level_root := LEVEL_SCENE.instantiate() as Control
	level_root.test_all_levels_unlocked = true
	level_root.load_saved_progress = false
	level_root.progress_path = TEST_PROGRESS_PATH
	root.add_child(level_root)
	await process_frame
	(level_root.get_node("%FoundationRouteButton") as Button).pressed.emit()
	await process_frame
	_expect(level_root.get_node("%TutorialGrid").get_child_count() == 18, "foundation route module count changed")
	_expect(level_root.get_node("%ChallengeGrid").get_child_count() == 3, "challenge count changed")
	for card: Control in level_root.get_node("%TutorialGrid").get_children():
		_expect(not (card.get_node("%NodeButton") as Button).disabled, "unlocked tutorial card is disabled")
	for card: Control in level_root.get_node("%ChallengeGrid").get_children():
		_expect(not (card.get_node("%NodeButton") as Button).disabled, "unlocked challenge card is disabled")
	_expect((level_root.get_node("%DetailCode") as Label).text == "P0", "level details must begin at P0")
	_expect((level_root.get_node("%EnterButton") as Button).custom_minimum_size.y >= 44.0, "level enter action is too small")
	level_root.queue_free()
	await process_frame
	_remove_progress()
	_finish()


func _remove_progress() -> void:
	var absolute := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FRONTEND_SCENE_SMOKE_PASS catalog=21 pages=2 unified_theme=ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FRONTEND_SCENE_SMOKE_FAIL failures=%d" % _failures.size())
	quit(1)
