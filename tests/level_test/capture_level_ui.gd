extends SceneTree

const MAIN_SCENE := preload("res://scenes/level_test/level_test_lab.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("关卡界面截图需要窗口化 Godot 会话。")
		quit(2)
		return
	var output_path: String = "user://level-test-main.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	root.size = Vector2i(1280, 720)
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	var error: Error = root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("关卡界面截图保存失败：%s" % error_string(error))
		quit(1)
		return
	print("LEVEL_UI_SNAPSHOT_SAVED path=%s" % output_path)
	quit(0)
