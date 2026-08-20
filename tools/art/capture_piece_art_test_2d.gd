extends SceneTree

const TEST_SCENE := preload("res://scenes/dev/art/piece_art_test_2d.tscn")
const OUTPUTS := {
	&"overview": "res://evidence/gate2/art-samples/review/piece-art-test-2d-battlefield-v3-full-formation.png",
	&"red": "res://evidence/gate2/art-samples/review/piece-art-test-2d-battlefield-v3-red-camp.png",
	&"black": "res://evidence/gate2/art-samples/review/piece-art-test-2d-battlefield-v3-black-camp.png",
}


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("2D piece art capture requires a windowed rendering driver.")
		quit(2)
		return
	root.size = Vector2i(960, 1080)
	var scene := TEST_SCENE.instantiate()
	root.add_child(scene)
	for preset: StringName in [&"overview", &"red", &"black"]:
		scene.show_preset(preset, true)
		for frame_index: int in 5:
			await process_frame
		RenderingServer.force_draw(false)
		await process_frame
		var image := root.get_texture().get_image()
		if image == null or image.is_empty():
			push_error("2D piece art capture did not produce an image.")
			quit(3)
			return
		var output_path: String = OUTPUTS[preset]
		var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
		if save_error != OK:
			push_error("2D piece art capture failed: %s" % error_string(save_error))
			quit(4)
			return
		print("PIECE_ART_2D_CAPTURE_SAVED path=%s size=%dx%d" % [
			output_path, image.get_width(), image.get_height()
		])
	scene.queue_free()
	quit(0)
