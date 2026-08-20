extends SceneTree

const TEST_SCENE := preload("res://scenes/dev/art/piece_art_test_3d.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Piece art capture requires a windowed rendering driver.")
		quit(2)
		return
	var capture_size := Vector2i(1920, 1080)
	var output_path := "res://evidence/gate2/art-samples/review/piece-art-test-3d-full-formation-v1.png"
	var camera_preset := "overview"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--size="):
			var size_parts := argument.trim_prefix("--size=").to_lower().split("x")
			if size_parts.size() == 2:
				capture_size = Vector2i(int(size_parts[0]), int(size_parts[1]))
		elif argument.begins_with("--preset="):
			camera_preset = argument.trim_prefix("--preset=")
	root.size = capture_size
	var scene := TEST_SCENE.instantiate()
	root.add_child(scene)
	var camera_rig := scene.get_node("CameraRig")
	camera_rig.show_preset(camera_preset, true)
	for frame_index in 4:
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Piece art capture did not produce an image.")
		quit(3)
		return
	var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error("Piece art capture save failed: %s" % error_string(save_error))
		quit(4)
		return
	print("PIECE_ART_CAPTURE_SAVED path=%s size=%dx%d" % [output_path, image.get_width(), image.get_height()])
	quit(0)
