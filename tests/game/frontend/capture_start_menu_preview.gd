extends SceneTree

const START_SCREEN_SCENE := preload("res://scenes/game/frontend/start_screen.tscn")
const FrontendRoutes := preload("res://scripts/integration/frontend_routes.gd")
const OUTPUT_PATH := "res://evidence/ui/ui-rebuild-start-menu-1280x720.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	FrontendRoutes.request_start_menu_ready()
	var start_screen := START_SCREEN_SCENE.instantiate() as Control
	root.add_child(start_screen)
	for _frame: int in 8:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("当前渲染驱动没有提供标题页预览纹理。")
		quit(2)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("当前渲染驱动没有提供标题页预览图像。")
		quit(3)
		return
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("START_MENU_PREVIEW_%s path=%s" % ["PASS" if result == OK else "FAIL", OUTPUT_PATH])
	start_screen.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
