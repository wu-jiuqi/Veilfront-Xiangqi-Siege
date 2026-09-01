extends SceneTree

const OVERLAY_SCENE := preload("res://scenes/game/ui/loading_transition_overlay.tscn")
const LAB_SCENE := preload("res://scenes/dev/ui/loading_transition_motion_lab.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay := OVERLAY_SCENE.instantiate() as Control
	root.add_child(overlay)
	await process_frame
	await process_frame
	_expect(overlay != null, "loading overlay did not instantiate")
	if overlay == null:
		_finish()
		return
	_expect(
		overlay.theme.resource_path == "res://resources/game/ui/themes/veilfront_ui_theme_v2.tres",
		"loading overlay must use the rebuilt unified theme",
	)
	var source := FileAccess.get_file_as_string("res://scenes/game/ui/loading_transition_overlay.tscn")
	_expect(not source.contains("failure_retry_button_v1.png"), "retry action still depends on fixed PNG geometry")
	_expect(not source.contains("failure_back_button_v1.png"), "back action still depends on fixed PNG geometry")
	for method_name: StringName in [&"start_loading", &"set_progress", &"show_failure", &"set_reduced_motion"]:
		_expect(overlay.has_method(method_name), "loading overlay is missing %s" % method_name)

	var fog_back := overlay.get_node("%FogBack") as TextureRect
	var fog_front := overlay.get_node("%FogFront") as TextureRect
	var fog_back_origin := fog_back.position
	var fog_front_origin := fog_front.position
	overlay.call("start_loading", "正在布设九路战场…")
	overlay.call("set_progress", 67.0)
	await process_frame
	var status := overlay.get_node("%StatusLabel") as Label
	var progress := overlay.get_node("%ProgressBar") as ProgressBar
	var glow := overlay.get_node("%ProgressGlow") as ProgressBar
	var fill_clip := overlay.get_node("%ProgressFillClip") as Control
	var cursor := overlay.get_node("%ProgressSpark") as TextureRect
	var percent := overlay.get_node("%PercentLabel") as Label
	_expect(status.text == "正在布设九路战场…", "loading status did not update")
	_expect(progress.size.x > 300.0 and progress.size.y >= 16.0, "loading progress layout is invalid")
	_expect(progress.get_theme_stylebox(&"background") is StyleBoxFlat, "progress track must be scalable")
	_expect(progress.get_theme_stylebox(&"fill") is StyleBoxFlat, "progress fill must be scalable")
	_expect(is_equal_approx(progress.value, 67.0) and is_equal_approx(glow.value, 67.0), "progress layers are out of sync")
	_expect(absf(fill_clip.size.x - progress.size.x * 0.67) <= 1.0, "progress sheen clip is out of sync")
	_expect(
		absf(cursor.get_global_rect().get_center().x - (progress.global_position.x + progress.size.x * 0.67)) <= 1.0,
		"progress cursor is not attached to the fill endpoint",
	)
	_expect(percent.text == "67%", "loading percentage did not update")

	overlay.call("show_failure", "加载失败", "未能抵达战场", "场景资源响应超时，请重试。")
	await create_timer(0.5).timeout
	var failure_layer := overlay.get_node("%FailureLayer") as Control
	var failure_card := overlay.get_node("%FailureCard") as PanelContainer
	_expect(failure_layer.visible, "failure layer did not open")
	_expect(failure_card.get_theme_stylebox(&"panel") is StyleBoxFlat, "failure card must use a scalable surface")
	_expect(_inside(failure_card.get_global_rect(), overlay.get_global_rect()), "failure card is outside the viewport")
	for button_name: String in ["RetryButton", "BackButton"]:
		var button := overlay.get_node("%%%s" % button_name) as Button
		_expect(button.custom_minimum_size.y >= 44.0, "%s is below the interaction target" % button_name)
		_expect(button.has_method("set_reduced_motion"), "%s must use the reusable motion button" % button_name)
		_expect(button.get_theme_stylebox(&"normal") is StyleBoxFlat, "%s must use the unified scalable surface" % button_name)
	_expect(overlay.call("get_transition_state") == &"failure", "failure state did not persist")

	overlay.call("set_reduced_motion", true)
	_expect(overlay.call("is_reduced_motion_enabled"), "reduced motion did not enable")
	_expect(fog_back.position.is_equal_approx(fog_back_origin), "rear fog did not reset")
	_expect(fog_front.position.is_equal_approx(fog_front_origin), "front fog did not reset")
	overlay.queue_free()
	await process_frame

	var lab := LAB_SCENE.instantiate() as Control
	root.add_child(lab)
	await process_frame
	_expect(lab.get_node_or_null("LoadingOverlay") != null, "loading motion lab lost its preset overlay")
	_expect(lab.get_node_or_null("LabHintPanel/Margin/LabHint") != null, "loading motion lab lost its help panel")
	lab.queue_free()
	await process_frame
	_finish()


func _inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.encloses(inner)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("LOADING_TRANSITION_MOTION_LAB_CONTRACT_PASS progress=67 unified_failure=true reduced_motion=true")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("LOADING_TRANSITION_MOTION_LAB_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)
