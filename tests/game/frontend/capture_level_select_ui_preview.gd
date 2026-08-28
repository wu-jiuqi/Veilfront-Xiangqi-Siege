extends SceneTree

const LEVEL_SELECT_SCENE := preload("res://scenes/game/frontend/level_select.tscn")
const OUTPUT_PATH := "res://evidence/ui/level-select-approved-master-v2-1280x720.png"
const CODEX_OUTPUT_PATH := "res://evidence/ui/level-select-codex-layout-v3-1280x720.png"
const TEST_PROGRESS_PATH := "user://level-select-layout-preview.cfg"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	_remove_test_progress()
	root.size = Vector2i(1280, 720)
	var level_select := LEVEL_SELECT_SCENE.instantiate() as Control
	level_select.load_saved_progress = false
	level_select.progress_path = TEST_PROGRESS_PATH
	root.add_child(level_select)
	await process_frame
	(level_select.get_node("%FoundationRouteButton") as Button).pressed.emit()
	for _frame: int in 6:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("当前渲染驱动没有提供关卡模式预览纹理。")
		quit(2)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("当前渲染驱动没有提供关卡模式预览图像。")
		quit(3)
		return
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("LEVEL_SELECT_PREVIEW_%s path=%s" % ["PASS" if result == OK else "FAIL", OUTPUT_PATH])
	var codex := level_select.get_node("%TutorialCodex") as TutorialCodex
	codex.open_codex()
	for _frame: int in 12:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var codex_image := root.get_texture().get_image()
	var codex_result := codex_image.save_png(ProjectSettings.globalize_path(CODEX_OUTPUT_PATH))
	print("LEVEL_SELECT_CODEX_PREVIEW_%s path=%s" % [
		"PASS" if codex_result == OK else "FAIL",
		CODEX_OUTPUT_PATH,
	])
	codex.close_codex()
	level_select.queue_free()
	await process_frame
	_remove_test_progress()
	quit(0 if result == OK and codex_result == OK else 1)


func _remove_test_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
