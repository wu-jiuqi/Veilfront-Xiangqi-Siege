extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var level_id := "T0"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			level_id = argument.trim_prefix("--level=").to_upper()
	root.size = Vector2i(1280, 720)
	root.set_meta("veilfront_selected_level_id", level_id)
	var level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	root.add_child(level)
	for _frame: int in 6:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var output_path := "user://tutorial-%s-visual.png" % level_id.to_lower()
	var error: Error = root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save tutorial capture: %s" % error_string(error))
		quit(1)
		return
	print("TUTORIAL_VISUAL_CAPTURE_PASS path=%s" % ProjectSettings.globalize_path(output_path))
	quit(0)
