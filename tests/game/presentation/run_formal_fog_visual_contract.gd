extends SceneTree

const FOG_SCENE: PackedScene = preload("res://scenes/game/match/board/fog_overlay.tscn")
const BOARD_WORLD_SCENE: PackedScene = preload("res://scenes/game/match/board/board_world.tscn")
const EXPECTED_SHADER_PATH := "res://shaders/game/fog_of_war.gdshader"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fog := FOG_SCENE.instantiate() as TextureRect
	root.add_child(fog)
	fog.render(
		[[1, 1], [2, 1], [5, 12]],
		[[8, 20]],
		"red",
		Vector2(128.0, 128.0)
	)
	var snapshot: Dictionary = fog.get_visual_snapshot()
	_expect(int(snapshot.get("board_cell_count", 0)) == 216, "formal fog mask must cover 9x24 cells")
	_expect(int(snapshot.get("visible_cell_count", 0)) == 3, "formal fog must consume visible PlayerView cells")
	_expect(int(snapshot.get("detection_cell_count", 0)) == 1, "formal fog must consume observer-safe detection cells")
	_expect(bool(snapshot.get("uses_generated_mask", false)), "formal fog must generate a mask texture")
	_expect(bool(snapshot.get("uses_player_view_only", false)), "formal fog must declare the PlayerView-only boundary")
	_expect(str(snapshot.get("boundary_style", "")) == "shader_warped_irregular", "formal fog must use irregular shader boundaries")
	_expect(snapshot.get("mask_size") == Vector2i(144, 384), "formal fog mask resolution changed")
	_expect(not fog.is_cell_fogged(Vector2i(1, 1)), "visible cell remained fogged")
	_expect(fog.is_cell_fogged(Vector2i(9, 24)), "hidden cell lost fog")
	var material := fog.material as ShaderMaterial
	_expect(material != null and material.shader != null, "formal fog material or shader missing")
	if material != null and material.shader != null:
		_expect(material.shader.resource_path == EXPECTED_SHADER_PATH, "formal fog did not use the production shader")
		_expect(float(material.get_shader_parameter("boundary_warp")) >= 0.75, "formal fog boundary warp is too weak")

	fog.render([[9, 24]], [], "black", Vector2(128.0, 128.0))
	_expect(str(fog.get_visual_snapshot().get("display_side", "")) == "black", "black observer orientation was not applied")
	fog.queue_free()

	var board_world := BOARD_WORLD_SCENE.instantiate() as Node2D
	root.add_child(board_world)
	await process_frame
	var piece_layer := board_world.get_node("PieceLayer")
	var fog_layer := board_world.get_node("FogOverlay")
	var structure_layer := board_world.get_node("StructureLayer")
	var intel_layer := board_world.get_node("IntelLayer")
	_expect(
		fog_layer.get_index() < piece_layer.get_index(),
		"authorized PlayerView pieces must remain readable above fog"
	)
	_expect(piece_layer.get_index() < structure_layer.get_index(), "public structures must render above pieces")
	_expect(fog_layer.get_index() < intel_layer.get_index(), "authorized intel must render above fog")
	board_world.queue_free()
	await process_frame

	if _failures.is_empty():
		print("FORMAL_FOG_VISUAL_CONTRACT_PASS mask=144x384 cells=216")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FORMAL_FOG_VISUAL_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
