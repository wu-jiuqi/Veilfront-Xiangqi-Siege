extends SceneTree

const LOBBY_SCENE: PackedScene = preload("res://scenes/game/frontend/formal_lan_lobby.tscn")
const OUTPUT_PATH := "res://evidence/ui/formal-lan-lobby-ui-workflow-v1-1280x720.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var lobby := LOBBY_SCENE.instantiate() as Control
	root.add_child(lobby)
	await process_frame
	lobby.render_connection_snapshot({
		"state": "lobby",
		"role": "host",
		"local_seat": "red",
		"peer_connected": true,
		"red_ready": false,
		"black_ready": true,
		"can_start": false,
		"turn_timeout_seconds": 45,
	})
	for _frame: int in 6:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("当前渲染驱动没有提供正式 LAN 大厅预览纹理。")
		quit(2)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("当前渲染驱动没有提供正式 LAN 大厅预览图像。")
		quit(3)
		return
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("FORMAL_LAN_LOBBY_REFACTOR_PREVIEW_%s path=%s" % ["PASS" if result == OK else "FAIL", OUTPUT_PATH])
	lobby.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
