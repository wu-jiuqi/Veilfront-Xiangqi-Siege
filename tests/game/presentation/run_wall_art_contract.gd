extends SceneTree

const WALL_SCENE: PackedScene = preload(
	"res://scenes/game/match/board/wall_view.tscn"
)
const BOARD_WORLD_SCENE: PackedScene = preload(
	"res://scenes/game/match/board/board_world.tscn"
)
const EXPECTED_WALL_PATH: String = \
	"res://assets/art/structures/terracotta_warriors/walls/generated_v1/city_wall_v1.png"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_wall_scene()
	_check_board_integration()
	await process_frame
	if _failures.is_empty():
		print("WALL_ART_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("WALL_ART_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_wall_scene() -> void:
	var near_wall: Node2D = WALL_SCENE.instantiate() as Node2D
	root.add_child(near_wall)
	_expect(near_wall.has_method("configure_wall"), "wall scene has no configuration method")
	near_wall.call("configure_wall", {"side": "red", "status": "INTACT"}, Vector2(128, 128), true)
	var artwork: Sprite2D = near_wall.get_node_or_null("Artwork") as Sprite2D
	_expect(artwork != null, "wall scene has no preset Artwork Sprite2D")
	if artwork != null and artwork.texture != null:
		_expect(artwork.texture.resource_path == EXPECTED_WALL_PATH, "wall mapped to the wrong artwork")
		var image := artwork.texture.get_image()
		_expect(image != null and image.get_pixel(0, 0).a <= 0.01, "wall image corner is not transparent")
		var rendered_width := artwork.texture.get_width() * artwork.scale.x
		_expect(rendered_width >= 128.0 * 8.5, "wall does not span the nine-file board line")
		var bottom_y := artwork.position.y + artwork.texture.get_height() * artwork.scale.y * 0.5
		_expect(absf(bottom_y) <= 0.01, "near-side wall base is not anchored to the wall line")
	near_wall.queue_free()


func _check_board_integration() -> void:
	var board_world: Node2D = BOARD_WORLD_SCENE.instantiate() as Node2D
	root.add_child(board_world)
	board_world.call("render_player_view", {
		"viewer_side": "red",
		"board": {"width": 9, "height": 24},
		"pieces": [],
		"flags": [],
		"walls": [
			{"side": "red", "status": "INTACT"},
			{"side": "black", "status": "BREACHED"},
		],
	})
	var snapshot: Dictionary = board_world.call("get_render_snapshot")
	_expect(int(snapshot.get("wall_segment_count", -1)) == 18, "wall segment compatibility metric changed")
	var wall_views := board_world.get_node("StructureLayer/WallViews")
	_expect(
		int(wall_views.call("get_rendered_wall_count")) == 2,
		"board did not render one whole wall per side"
	)
	_expect(
		wall_views.call("get_rendered_art_paths") == [EXPECTED_WALL_PATH, EXPECTED_WALL_PATH],
		"board did not bind the city wall artwork"
	)
	_expect(wall_views.get_child_count() == 2, "wall renderer still creates nine nodes per wall")
	var far_wall := wall_views.get_child(1) as Node2D
	var far_artwork := far_wall.get_node("Artwork") as Sprite2D
	var top_y := far_artwork.position.y - far_artwork.texture.get_height() * far_artwork.scale.y * 0.5
	_expect(absf(top_y) <= 0.01, "far-side wall top is not anchored to the wall line")
	board_world.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
