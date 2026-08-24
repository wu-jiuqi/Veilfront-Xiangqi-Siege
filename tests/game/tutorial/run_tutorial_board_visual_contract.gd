extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")
const TutorialChapterCatalog = preload("res://scripts/game/tutorial/tutorial_chapter_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for level_id: String in TutorialChapterCatalog.TUTORIAL_IDS:
		root.set_meta("veilfront_selected_level_id", level_id)
		var level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
		root.add_child(level)
		await process_frame
		await process_frame
		await process_frame
		var screen: Control = level.get_node("MatchScreen") as Control
		await _wait_for_camera_idle(screen, level_id)
		var snapshot: Dictionary = screen.get_board_render_snapshot()
		_expect(int(snapshot.get("piece_count", 0)) > 0, "%s renders no pieces" % level_id)
		var glyphs: Array = snapshot.get("piece_glyphs", [])
		_expect(not glyphs.has("棋") and not glyphs.has("?"), "%s has placeholder glyphs: %s" % [level_id, glyphs])
		var layer_order: Dictionary = snapshot.get("layer_order", {})
		_expect(
			int(layer_order.get("piece", -1)) > int(layer_order.get("fog", -1)),
			"%s pieces are not drawn above fog: %s" % [level_id, layer_order]
		)
		_expect(bool(snapshot.get("focused_cell_visible", false)), "%s focused step is outside viewport" % level_id)
		level.queue_free()
		await process_frame

	var piece_scene: PackedScene = load(
		"res://scenes/game/match/board/terracotta_piece_view.tscn"
	) as PackedScene
	var piece_view: Node2D = piece_scene.instantiate() as Node2D
	var shadow: Polygon2D = piece_view.get_node("Shadow") as Polygon2D
	_expect(shadow.polygon.size() >= 16, "formal piece has no authored contact shadow")
	_expect(piece_view.get_node_or_null("Artwork") is Sprite2D, "formal piece has no artwork node")
	_expect(
		(piece_view.get("piece_textures") as Dictionary).size() == 14,
		"formal piece scene does not bind all 14 faction/type textures"
	)
	piece_view.free()

	if _failures.is_empty():
		print("TUTORIAL_BOARD_VISUAL_CONTRACT_PASS chapters=11")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_BOARD_VISUAL_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _wait_for_camera_idle(screen: Control, level_id: String) -> void:
	for _frame: int in range(120):
		var snapshot: Dictionary = screen.get_board_render_snapshot()
		if not bool(snapshot.get("camera_motion_active", true)):
			return
		await process_frame
	_failures.append("%s camera focus did not settle within 120 frames" % level_id)
