extends SceneTree

const REVIEW_SCENE: PackedScene = preload("res://scenes/game/vfx/vfx_review_lab.tscn")
const OUTPUT_PATH := "res://evidence/gate3/vfx/vfx-review-1280x720.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var review := REVIEW_SCENE.instantiate() as Node2D
	viewport.add_child(review)
	for _frame: int in 3:
		await process_frame
	var snapshot: Dictionary = review.call("get_review_snapshot")
	var families := PackedStringArray()
	for effect_value: Variant in snapshot.get("active", []):
		families.append(str(effect_value.get("family", "")))
	families.sort()
	var expected := PackedStringArray([
		"bombardment", "capture", "flag", "move", "selection", "terminal", "wall",
	])
	if int(snapshot.get("active_count", 0)) != 7 or families != expected:
		push_error("VFX review hold missing families: active=%s families=%s" % [snapshot.get("active_count", 0), families])
		quit(4)
		return
	RenderingServer.force_draw()
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("VFX review capture unavailable")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/gate3/vfx"))
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("VFX_REVIEW_CAPTURE_%s path=%s active=7 families=%s review_hold=true" % ["PASS" if result == OK else "FAIL", OUTPUT_PATH, families])
	review.queue_free()
	viewport.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
