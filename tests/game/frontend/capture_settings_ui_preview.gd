extends SceneTree

const SETTINGS_SCENE := preload("res://scenes/game/frontend/settings_screen.tscn")
const SettingsManagerScript := preload("res://scripts/game/settings/settings_manager.gd")
const OUTPUT_PATH := "res://evidence/ui/settings-screen-functional-1280x720.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var settings_manager := SettingsManagerScript.new("user://settings_capture.cfg", false)
	settings_manager.name = "SettingsManager"
	root.add_child(settings_manager)
	var settings_screen := SETTINGS_SCENE.instantiate() as Control
	root.add_child(settings_screen)
	for _frame: int in 6:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("当前渲染驱动没有提供设置页预览纹理。")
		quit(2)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("当前渲染驱动没有提供设置页预览图像。")
		quit(3)
		return
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("SETTINGS_UI_PREVIEW_%s path=%s" % ["PASS" if result == OK else "FAIL", OUTPUT_PATH])
	settings_screen.queue_free()
	settings_manager.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
