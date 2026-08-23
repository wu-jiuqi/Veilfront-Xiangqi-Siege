extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.set_meta("veilfront_selected_level_id", "T10")
	var level: Control = LEVEL_SCENE.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var director: TutorialDirector = level.get_node("TutorialDirector")
	var overlay: Control = level.get_node("TutorialOverlay") as Control

	director.set("_assessment_actions_used", 8)
	director.consume_visible_events([{
		"visible_sequence": 1,
		"actor_side_public": "red",
	}])
	await process_frame
	_expect(director.get_public_state() == "FAILED", "ninth assessment action did not fail T10")
	_expect(
		str(overlay.get_public_snapshot().get("assessment_status", "")).contains("行动 9 / 8"),
		"assessment failure did not expose the exhausted action count"
	)

	director.configure("T10", director.presentation_track)
	for _index: int in director.presentation_track.steps.size():
		director._advance_current_step()
	await process_frame
	var snapshot: Dictionary = overlay.get_public_snapshot()
	var summary := str(snapshot.get("completion_summary", ""))
	for heading: String in ["侦察：", "路径判断：", "资源使用：", "无效操作："]:
		_expect(summary.contains(heading), "T10 completion summary is missing %s" % heading)
	_expect(float(snapshot.get("progress_value", 0.0)) >= 99.9, "T10 completion did not reach total progress")

	level.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TUTORIAL_COMPLETION_FAILURE_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
