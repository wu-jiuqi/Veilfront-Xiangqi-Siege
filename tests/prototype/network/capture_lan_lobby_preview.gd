extends SceneTree

const LOBBY_SCENE: PackedScene = preload("res://scenes/prototype/network/lan_lobby.tscn")
const OUTPUT_PATH: String = "res://evidence/ui/lan-lobby-board-metal-v1-1280x720.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var lobby: Control = LOBBY_SCENE.instantiate() as Control
	root.add_child(lobby)
	for _frame: int in 6:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("当前渲染驱动没有提供联机房间预览纹理。")
		quit(2)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("当前渲染驱动没有提供联机房间预览图像。")
		quit(3)
		return
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("LAN_LOBBY_PREVIEW_%s path=%s" % ["PASS" if result == OK else "FAIL", OUTPUT_PATH])
	lobby.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
