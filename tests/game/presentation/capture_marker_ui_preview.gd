extends SceneTree

const MATCH_SCREEN_SCENE: PackedScene = preload(
	"res://scenes/game/match/match_screen.tscn"
)
const FormalLocalSession = preload(
	"res://scripts/game/application/formal_local_session.gd"
)
const OUTPUT_PATH := "res://evidence/ui/marker-ui-board-border-v1-1280x720.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var match_screen: Control = MATCH_SCREEN_SCENE.instantiate() as Control
	root.add_child(match_screen)
	match_screen.apply_layout_for_size(Vector2(root.size))

	var session: RefCounted = FormalLocalSession.create(471001)
	var port: RefCounted = session.create_client_port("red")
	port.player_view_updated.connect(match_screen.render_player_view)
	port.publish_current()
	await process_frame
	await process_frame

	match_screen.apply_marker(Vector2i(3, 5), "circle")
	match_screen.apply_marker(Vector2i(5, 5), "cross")
	match_screen.apply_marker(Vector2i(7, 5), "square")
	match_screen.handle_cancel_or_marker(Vector2i(5, 5), Vector2(360.0, 316.0))
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	if image == null:
		push_error("marker UI preview image was unavailable")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://evidence/ui")
	)
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	if image.save_png(absolute_path) != OK:
		push_error("failed to save marker UI preview")
		quit(1)
		return
	print("MARKER_UI_PREVIEW_PASS path=%s" % OUTPUT_PATH)
	match_screen.queue_free()
	await process_frame
	quit(0)
