extends SceneTree

const TARGET_SCENE_PATH := "res://scenes/game/frontend/start_screen.tscn"

var _completed_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var controller := root.get_node("SceneTransition") as SceneTransitionController
	assert(controller != null, "SceneTransition autoload must instantiate from its preset scene")
	controller.minimum_display_seconds = 0.0
	await process_frame

	var overlay := controller.get_node("LoadingOverlay") as Control
	assert(overlay != null, "transition controller must preset the loading overlay scene")
	assert(not overlay.visible, "loading overlay must start hidden")
	assert(controller.layer >= 100, "loading overlay must render above gameplay UI")
	assert(
		controller.change_scene("res://missing-scene.tscn", "测试无效路径") == ERR_FILE_NOT_FOUND,
		"missing targets must fail before opening the loading overlay"
	)
	assert(not overlay.visible, "invalid targets must not trap the player behind an overlay")

	controller.transition_completed.connect(_on_transition_completed)
	var change_error := controller.change_scene(TARGET_SCENE_PATH, "正在验证加载界面接入…")
	assert(change_error == OK, "valid scene transition request must start")
	assert(controller.is_transitioning(), "controller must lock duplicate transitions while loading")
	assert(overlay.visible, "valid transition must display the loading overlay")
	assert(
		controller.change_scene(TARGET_SCENE_PATH, "重复请求") == ERR_BUSY,
		"duplicate transition requests must be rejected"
	)

	var deadline_msec := Time.get_ticks_msec() + 10000
	while _completed_path.is_empty() and Time.get_ticks_msec() < deadline_msec:
		await process_frame

	assert(
		_completed_path == TARGET_SCENE_PATH,
		"threaded scene transition did not complete: busy=%s target=%s overlay=%s current=%s"
		% [
			controller.is_transitioning(),
			controller.get_target_scene_path(),
			overlay.call(&"get_transition_state"),
			current_scene.name if current_scene != null else "<null>",
		]
	)
	assert(current_scene != null and current_scene.name == "StartScreen", "target scene did not become current")
	assert(not controller.is_transitioning(), "transition lock must clear after scene activation")
	assert(not overlay.visible, "loading overlay must hide after the target scene is ready")
	var loaded_scene := current_scene
	current_scene = null
	loaded_scene.queue_free()
	for _frame: int in 3:
		await process_frame
	controller.queue_free()
	await process_frame
	print("SCENE_TRANSITION_CONTROLLER_CONTRACT_PASS threaded=true overlay=preset duplicate_guard=true")
	quit(0)


func _on_transition_completed(scene_path: String) -> void:
	_completed_path = scene_path
