extends SceneTree

const CODEX_SCENE: PackedScene = preload("res://scenes/game/ui/tutorial_codex.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var page_index := 0
	var capture_size := Vector2i(1280, 720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--page="):
			page_index = clampi(int(argument.trim_prefix("--page=")), 0, 17)
		elif argument == "--small":
			capture_size = Vector2i(960, 540)
	root.size = capture_size
	var codex := CODEX_SCENE.instantiate() as TutorialCodex
	root.add_child(codex)
	await process_frame
	codex.open_codex(page_index)
	for _frame: int in 180:
		if not str(codex.get_public_snapshot().get("image_path", "")).is_empty():
			break
		await process_frame
	for _frame: int in 4:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var output_path := "res://evidence/ui/tutorial-codex-v3-p%02d-%dx%d.png" % [
		page_index,
		capture_size.x,
		capture_size.y,
	]
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("当前渲染驱动没有提供战阵图鉴预览纹理。")
		quit(2)
		return
	var capture_image := viewport_texture.get_image()
	if capture_image == null:
		push_error("当前渲染驱动无法读取战阵图鉴预览图像。")
		quit(3)
		return
	var error := capture_image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("Could not save tutorial codex v3 capture: %s" % error_string(error))
		quit(1)
		return
	print("TUTORIAL_CODEX_V3_CAPTURE_PASS path=%s" % ProjectSettings.globalize_path(output_path))
	quit(0)
