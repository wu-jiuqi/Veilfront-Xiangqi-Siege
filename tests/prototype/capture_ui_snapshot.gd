extends SceneTree

const MAIN_SCENE := preload("res://scenes/prototype/gate1_logic_lab.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI snapshot requires a windowed Godot session.")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	var output_path: String = "user://gate1-ui-snapshot.png"
	var scroll_to_bottom: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument == "--scroll=bottom":
			scroll_to_bottom = true
	if scroll_to_bottom:
		var board_scroll := scene.get_node(
			"SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/BoardScroll"
		) as ScrollContainer
		board_scroll.scroll_vertical = int(board_scroll.get_v_scroll_bar().max_value)
		await process_frame
	var error: Error = root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("UI snapshot save failed: %s" % error_string(error))
		quit(1)
		return
	print("UI_SNAPSHOT_SAVED path=%s" % output_path)
	quit(0)
