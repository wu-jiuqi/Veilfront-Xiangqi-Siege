extends SceneTree

const START_SCREEN_SCENE := preload("res://scenes/game/frontend/start_screen.tscn")
const CAPTURE_TIMES := {
	"00_closed": 0.0,
	"01_brace": 0.52,
	"02_opening": 1.5,
	"03_fog_cover": 2.7,
	"04_title": 3.25,
	"05_black": 4.88,
}


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Start-sequence capture requires a windowed Godot session.")
		quit(2)
		return

	var output_dir := "user://start-sequence-captures"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.trim_prefix("--output-dir=")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	root.size = Vector2i(1280, 720)
	var start_screen := START_SCREEN_SCENE.instantiate() as Control
	root.add_child(start_screen)
	await process_frame
	await process_frame

	var sequence_player := start_screen.get_node("SequencePlayer") as AnimationPlayer
	var prompt_animation := start_screen.get_node("PromptAnimation") as AnimationPlayer
	var gate_mist := start_screen.get_node("Stage/FogLayer/GateMist") as GPUParticles2D
	prompt_animation.stop()
	sequence_player.play(&"opening_sequence")
	sequence_player.pause()

	for capture_name: String in CAPTURE_TIMES:
		var capture_time: float = CAPTURE_TIMES[capture_name]
		sequence_player.seek(capture_time, true)
		gate_mist.restart()
		gate_mist.emitting = capture_time >= 0.88 and capture_time <= 3.35
		if gate_mist.emitting:
			gate_mist.request_particles_process(maxf(capture_time - 0.88, 0.0))
		await process_frame
		RenderingServer.force_draw(false)
		await process_frame

		var image := root.get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Start-sequence capture did not produce an image.")
			quit(3)
			return
		var output_path := output_dir.path_join("%s.png" % capture_name)
		var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
		if save_error != OK:
			push_error("Start-sequence capture failed: %s" % error_string(save_error))
			quit(4)
			return
		print("START_SEQUENCE_CAPTURE_SAVED path=%s time=%.2f" % [output_path, capture_time])

	start_screen.queue_free()
	quit(0)
