extends SceneTree

const LAB_SCENE: PackedScene = preload(
	"res://scenes/dev/ui/match_hud_v2_interaction_lab.tscn"
)
const EXPECTED_MAP_PATH := \
	"res://assets/art/boards/terracotta_warriors/terracotta_battlefield_board_bg_gridless_v3_decorated.png"
const EXPECTED_PIECE_PATHS: Array[String] = [
	"res://assets/art/pieces/terracotta_warriors/red_chariot_idle.png",
	"res://assets/art/pieces/terracotta_warriors/red_cavalry_idle.png",
	"res://assets/art/pieces/terracotta_warriors/red_minister_idle.png",
	"res://assets/art/pieces/terracotta_warriors/red_guard_idle.png",
	"res://assets/art/pieces/terracotta_warriors/red_general_idle.png",
	"res://assets/art/pieces/terracotta_warriors/red_trebuchet_idle.png",
	"res://assets/art/pieces/terracotta_warriors/red_infantry_idle.png",
	"res://assets/art/pieces/terracotta_warriors/black_chariot_idle.png",
	"res://assets/art/pieces/terracotta_warriors/black_cavalry_idle.png",
	"res://assets/art/pieces/terracotta_warriors/black_minister_idle.png",
	"res://assets/art/pieces/terracotta_warriors/black_guard_idle.png",
	"res://assets/art/pieces/terracotta_warriors/black_general_idle.png",
	"res://assets/art/pieces/terracotta_warriors/black_trebuchet_idle.png",
	"res://assets/art/pieces/terracotta_warriors/black_infantry_idle.png",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lab: Control = LAB_SCENE.instantiate() as Control
	viewport.add_child(lab)
	await process_frame
	await process_frame
	await process_frame

	var match_screen: Control = lab.get_node("MatchScreen") as Control
	var snapshot: Dictionary = match_screen.get_board_render_snapshot()
	_expect(str(snapshot.get("map_id", "")) == "terracotta_battlefield_v3", "lab did not use the first selectable map")
	_expect(str(snapshot.get("map_background_path", "")) == EXPECTED_MAP_PATH, "lab map background path mismatch")
	_expect(int(snapshot.get("piece_count", 0)) == 14, "lab did not render all 14 art showcase pieces")
	var rendered_paths: Array[String] = []
	for value: Variant in snapshot.get("piece_art_paths", []):
		rendered_paths.append(str(value))
	_expect(rendered_paths.size() == 14, "not every rendered piece used an artwork texture")
	var unique_paths: Dictionary = {}
	for path: String in rendered_paths:
		unique_paths[path] = true
	_expect(unique_paths.size() == 14, "art showcase did not cover 14 unique piece textures")
	for path: String in EXPECTED_PIECE_PATHS:
		_expect(path in rendered_paths, "missing terracotta piece texture: %s" % path)

	var background: Sprite2D = lab.get_node(
		"MatchScreen/MatchHudV2/BoardFrame/BoardViewport/BoardSubViewport/BoardWorld/MapBackground"
	) as Sprite2D
	_expect(background.visible, "preset map background node remained hidden")
	_expect(is_equal_approx(background.scale.x, background.scale.y), "map background was stretched non-uniformly")
	_expect(
		background.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		"map background did not use stable linear sampling before sharpening"
	)
	var board_material := background.material as ShaderMaterial
	_expect(board_material != null, "map background sharpening material was missing")
	if board_material != null:
		_expect(
			board_material.shader != null
			and board_material.shader.resource_path == "res://shaders/game/board_background_sharpen.gdshader",
			"map background did not use the board sharpening shader"
		)

	var piece_layer: Node2D = lab.get_node(
		"MatchScreen/MatchHudV2/BoardFrame/BoardViewport/BoardSubViewport/BoardWorld/PieceLayer"
	) as Node2D
	for piece_view_value: Variant in piece_layer.get_children():
		var piece_view := piece_view_value as Node2D
		if piece_view == null:
			continue
		var artwork := piece_view.get_node_or_null("Artwork") as Sprite2D
		_expect(artwork != null and artwork.texture != null, "rendered piece artwork was missing")
		if artwork == null or artwork.texture == null:
			continue
		var artwork_bottom: float = artwork.position.y \
			+ artwork.texture.get_height() * artwork.scale.y * 0.5
		_expect(
			absf(artwork_bottom) <= 0.1,
			"piece artwork bottom was not anchored to its board intersection"
		)
		var authority_cell: Vector2i = piece_view.get_meta(
			"authority_cell", Vector2i.ZERO
		) as Vector2i
		var expected_position := BoardCoordinateMapper.authority_to_world(
			authority_cell, "red", Vector2(128.0, 128.0)
		)
		_expect(
			piece_view.position.is_equal_approx(expected_position),
			"piece root did not match its authority-cell board intersection"
		)
	if "--capture-screenshot" in OS.get_cmdline_user_args():
		_capture_screenshot(viewport)

	lab.queue_free()
	viewport.queue_free()
	await process_frame
	if _failures.is_empty():
		print("MATCH_HUD_V2_TERRACOTTA_ART_PASS map=terracotta_battlefield_v3 pieces=14")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("MATCH_HUD_V2_TERRACOTTA_ART_FAIL failures=%d" % _failures.size())
	quit(1)


func _capture_screenshot(viewport: SubViewport) -> void:
	var image := viewport.get_texture().get_image()
	if image == null:
		_failures.append("art integration screenshot was unavailable")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.codex-temp"))
	var output_path := ProjectSettings.globalize_path(
		"res://.codex-temp/match-hud-v2-terracotta-art-integration.png"
	)
	_expect(image.save_png(output_path) == OK, "failed to save art integration screenshot")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
