extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var level_id := "T0"
	var capture_state := "hud"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			level_id = argument.trim_prefix("--level=").to_upper()
		elif argument.begins_with("--state="):
			capture_state = argument.trim_prefix("--state=").to_lower()
	root.size = Vector2i(1280, 720)
	root.set_meta("veilfront_selected_level_id", level_id)
	var level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	root.add_child(level)
	for _frame: int in 12:
		await process_frame
	if capture_state == "pause":
		var pause_menu := level.get_node("TutorialPauseMenu") as Control
		pause_menu.call("open_menu")
		await process_frame
	elif capture_state == "completion":
		var overlay := level.get_node("TutorialOverlay") as Control
		overlay.render_public_step({
			"id": "completed",
			"title": "棋落交点 完成",
			"prompt": "本章检查点已记录。",
			"summary": [
				"棋子落在点线交点",
				"选中时右键先取消",
				"未选中时右键才能标注",
				"预览必须确认后才提交",
			],
			"step_index": 3,
			"step_count": 3,
		})
		await process_frame
		var stay_button := overlay.find_child("StayButton", true, false) as Button
		if stay_button != null:
			Input.warp_mouse(stay_button.global_position + stay_button.size * 0.5)
			await process_frame
	RenderingServer.force_draw()
	for _frame: int in 4:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var output_path := "res://evidence/ui/ui-rebuild-tutorial-%s-hud-1280x720.png" % level_id.to_lower()
	if capture_state == "completion":
		output_path = "res://evidence/ui/ui-rebuild-tutorial-%s-completion-1280x720.png" % level_id.to_lower()
	elif capture_state == "pause":
		output_path = "res://evidence/ui/ui-rebuild-tutorial-%s-pause-1280x720.png" % level_id.to_lower()
	var error: Error = root.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(output_path)
	)
	if error != OK:
		push_error("Could not save tutorial capture: %s" % error_string(error))
		quit(1)
		return
	print("TUTORIAL_VISUAL_CAPTURE_PASS path=%s" % ProjectSettings.globalize_path(output_path))
	quit(0)
