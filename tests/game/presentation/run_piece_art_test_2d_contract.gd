extends SceneTree

const TEST_SCENE := preload("res://scenes/dev/art/piece_art_test_2d.tscn")
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
		print("PIECE_ART_TEST_2D_PASS pieces=32 textures=14 camps=%s types=%s" % [
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

