extends SceneTree

const TEST_SCENE := preload("res://scenes/dev/art/piece_art_test_3d.tscn")
const OUTPUT_OVERVIEW := "res://evidence/art/terracotta_battle_stage_overview.png"
const OUTPUT_RED := "res://evidence/art/terracotta_battle_stage_red_view.png"
const OUTPUT_BLACK := "res://evidence/art/terracotta_battle_stage_black_view.png"


func _initialize() -> void:
	var test_scene := TEST_SCENE.instantiate()
	root.add_child(test_scene)
	_capture_after_render.call_deferred(test_scene)


func _capture_after_render(test_scene: Node) -> void:
	for _frame: int in range(8):
		await process_frame
	var error := await _save_capture(OUTPUT_OVERVIEW)
	if error != OK:
		quit(1)
		return
	var camera_rig := test_scene.get_node("CameraRig")
	camera_rig.call("show_preset", &"red", true)
	for _frame: int in range(4):
		await process_frame
	error = await _save_capture(OUTPUT_RED)
	if error != OK:
		quit(1)
		return
	camera_rig.call("show_preset", &"black", true)
	for _frame: int in range(4):
		await process_frame
	error = await _save_capture(OUTPUT_BLACK)
	quit(0 if error == OK else 1)


func _save_capture(output_path: String) -> Error:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var absolute_output := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var error := image.save_png(absolute_output)
	if error != OK:
		push_error("无法保存兵马俑战场舞台截图：%s" % error_string(error))
		return error
	print("BATTLE_STAGE_CAPTURE=%s" % absolute_output)
	return OK
