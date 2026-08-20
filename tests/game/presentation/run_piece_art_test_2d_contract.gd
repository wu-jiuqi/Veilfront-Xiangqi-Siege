extends SceneTree

const TEST_SCENE := preload("res://scenes/dev/art/piece_art_test_2d.tscn")
const EXPECTED_BACKGROUND_PATH := \
	"res://assets/art/boards/terracotta_warriors/terracotta_battlefield_board_bg_gridless_v3_decorated.png"
const EXPECTED_THEME_PATH := \
	"res://resources/dev/art/terracotta_battlefield_board_test_theme.tres"
const BOARD_PIXEL_SIZE := Vector2(1152.0, 3072.0)
const EXPECTED_BY_CAMP := {"red": 16, "black": 16}
const EXPECTED_BY_TYPE := {
	"infantry": 10,
	"trebuchet": 4,
	"chariot": 4,
	"cavalry": 4,
	"minister": 4,
	"guard": 4,
	"general": 2,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := TEST_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	var pieces := get_nodes_in_group("piece_art_test_2d")
	var by_camp: Dictionary = {}
	var by_type: Dictionary = {}
	var textures: Dictionary = {}
	var failures: Array[String] = []
	var background := scene.get_node_or_null("BattlefieldBackground") as Sprite2D
	if background == null or background.texture == null:
		failures.append("missing BattlefieldBackground texture")
	else:
		if background.texture.resource_path != EXPECTED_BACKGROUND_PATH:
			failures.append("unexpected battlefield background: %s" % background.texture.resource_path)
		var covered_size := Vector2(
			background.texture.get_width(),
			background.texture.get_height()
		) * background.scale.abs()
		if covered_size.x < BOARD_PIXEL_SIZE.x or covered_size.y < BOARD_PIXEL_SIZE.y:
			failures.append("battlefield background does not cover board: %s" % covered_size)
		if background.z_index >= 0:
			failures.append("battlefield background must render below board layers")
	var board_world := scene.get_node_or_null("BoardWorld")
	if board_world == null:
		failures.append("missing BoardWorld")
	else:
		var board_theme: Resource = board_world.get("board_theme") as Resource
		if board_theme == null or board_theme.resource_path != EXPECTED_THEME_PATH:
			failures.append("BoardWorld missing battlefield test theme")
		var fog_overlay := board_world.get_node_or_null("FogOverlay") as Control
		if fog_overlay == null or fog_overlay.visible:
			failures.append("art test must disable gameplay fog overlay")
	for piece: Node in pieces:
		var camp := str(piece.get_meta("camp", ""))
		var piece_type := str(piece.get_meta("piece_type", ""))
		by_camp[camp] = int(by_camp.get(camp, 0)) + 1
		by_type[piece_type] = int(by_type.get(piece_type, 0)) + 1
		var artwork := piece.get_node_or_null("Artwork") as Sprite2D
		if artwork == null or artwork.texture == null:
			failures.append("%s missing Artwork texture" % piece.name)
			continue
		textures[artwork.texture.resource_path] = true
	if pieces.size() != 32:
		failures.append("expected 32 preset instances, got %d" % pieces.size())
	if by_camp != EXPECTED_BY_CAMP:
		failures.append("camp counts mismatch: %s" % by_camp)
	if by_type != EXPECTED_BY_TYPE:
		failures.append("piece type counts mismatch: %s" % by_type)
	if textures.size() != 14:
		failures.append("expected 14 distinct textures, got %d" % textures.size())
	if failures.is_empty():
		print("PIECE_ART_TEST_2D_PASS pieces=32 textures=14 background=v3_decorated camps=%s types=%s" % [
			by_camp, by_type
		])
		scene.queue_free()
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("PIECE_ART_TEST_2D_FAIL failures=%d" % failures.size())
	scene.queue_free()
	quit(1)
