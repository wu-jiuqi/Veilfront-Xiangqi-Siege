extends SceneTree

const FLAG_SCENE: PackedScene = preload(
	"res://scenes/game/match/board/flag_view.tscn"
)
const BOARD_WORLD_SCENE: PackedScene = preload(
	"res://scenes/game/match/board/board_world.tscn"
)
const EXPECTED_PATHS: Dictionary = {
	"neutral": "res://assets/art/flags/terracotta_warriors/neutral_flag.png",
	"red": "res://assets/art/flags/terracotta_warriors/red_flag_captured.png",
	"black": "res://assets/art/flags/terracotta_warriors/black_flag_captured.png",
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for owner: String in ["", "red", "black"]:
		var texture_key := owner if owner != "" else "neutral"
		var view: Node2D = FLAG_SCENE.instantiate() as Node2D
		root.add_child(view)
		_expect(view.has_method("configure_flag"), "flag scene has no state configuration method")
		if view.has_method("configure_flag"):
			view.call("configure_flag", {"owner": owner}, Vector2(128.0, 128.0))
		var artwork: Sprite2D = view.get_node_or_null("Artwork") as Sprite2D
		_expect(artwork != null, "%s flag has no preset Artwork Sprite2D" % texture_key)
		if artwork != null:
			_expect(artwork.texture != null, "%s flag texture is missing" % texture_key)
			if artwork.texture != null:
				_expect(
					artwork.texture.resource_path == str(EXPECTED_PATHS[texture_key]),
					"%s flag mapped to the wrong artwork" % texture_key
				)
				var bottom_y := artwork.position.y \
					+ artwork.texture.get_height() * artwork.scale.y * 0.5
				_expect(absf(bottom_y) <= 0.01, "%s flag base is not anchored to its cell" % texture_key)
		_expect(bool(view.visible), "%s flag view is hidden after configuration" % texture_key)
		_expect(str(view.get_meta("flag_owner", "")) == texture_key, "%s flag state metadata mismatch" % texture_key)
		view.queue_free()
	var board_world: Node2D = BOARD_WORLD_SCENE.instantiate() as Node2D
	root.add_child(board_world)
	board_world.call("render_player_view", {
		"viewer_side": "red",
		"board": {"width": 9, "height": 24},
		"pieces": [],
		"flags": [
			_flag("neutral", "", Vector2i(3, 12)),
			_flag("red", "red", Vector2i(5, 12)),
			_flag("black", "black", Vector2i(7, 12)),
		],
	})
	var flag_renderer: Node = board_world.get_node("IntelLayer/FlagViews")
	_expect(
		flag_renderer.call("get_rendered_art_paths") == [
			EXPECTED_PATHS["neutral"],
			EXPECTED_PATHS["red"],
			EXPECTED_PATHS["black"],
		],
		"board renderer did not apply all three flag artwork states"
	)
	board_world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("FLAG_ART_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FLAG_ART_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _flag(flag_id: String, owner: String, position: Vector2i) -> Dictionary:
	return {
		"capture_progress": 0,
		"capturing_side": "",
		"contested": false,
		"discovered": true,
		"id": flag_id,
		"owner": owner,
		"position": [position.x, position.y],
	}
