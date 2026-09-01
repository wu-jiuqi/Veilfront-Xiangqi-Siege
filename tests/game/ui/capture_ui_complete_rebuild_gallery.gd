extends SceneTree

const GALLERY := preload("res://scenes/dev/ui/ui_complete_rebuild_gallery.tscn")
const OUTPUT := "res://evidence/ui/ui-complete-rebuild-gallery-1280x720.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var gallery := GALLERY.instantiate() as Control
	root.add_child(gallery)
	for _frame: int in 6:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var image := root.get_texture().get_image()
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT)) if image != null else ERR_CANT_CREATE
	print("UI_COMPLETE_REBUILD_GALLERY_%s path=%s" % ["PASS" if result == OK else "FAIL", OUTPUT])
	quit(0 if result == OK else 1)
