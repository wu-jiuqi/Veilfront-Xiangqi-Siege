extends SceneTree

const MATCH_SCENE: PackedScene = preload("res://scenes/game/match/match_screen.tscn")
const CueContract = preload("res://scripts/game/vfx/vfx_cue.gd")
const OUTPUT_DIR: String = "res://evidence/gate3/vfx"


func _init() -> void:
	call_deferred("_capture_all")


func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var failed := false
	for kind: String in ["capture", "general"]:
		if not await _capture_kind(kind):
			failed = true
	quit(1 if failed else 0)


func _capture_kind(kind: String) -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var screen := MATCH_SCENE.instantiate() as Control
	viewport.add_child(screen)
	for _frame: int in 4:
		await process_frame
	var overlay := screen.get_node("ScreenCalloutOverlay") as ScreenCalloutOverlay
	overlay.set_review_hold(true)
	overlay.trigger(_cue(kind))
	for _frame: int in 3:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image := viewport.get_texture().get_image()
	var path := "%s/screen-callout-%s-1280x720.png" % [OUTPUT_DIR, kind]
	var result := ERR_CANT_CREATE if image == null or image.is_empty() \
		else image.save_png(ProjectSettings.globalize_path(path))
	print(
		"SCREEN_CALLOUT_CAPTURE_%s kind=%s path=%s center=true review_hold=true" % [
			"PASS" if result == OK else "FAIL", kind, path
		]
	)
	screen.queue_free()
	viewport.queue_free()
	await process_frame
	return result == OK


func _cue(kind: String) -> Dictionary:
	return CueContract.build(
		"screen-callout-review",
		1,
		"vfx.callout.%s" % kind,
		"view_diff",
		1,
		0,
		"global",
		[],
		"critical" if kind == "general" else "high",
		"callout",
		"replace_group",
		"red",
		"standard",
		"review-%s" % kind
	)
