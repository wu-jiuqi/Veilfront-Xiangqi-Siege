extends SceneTree

const LAB_SCENE: PackedScene = preload(
	"res://scenes/dev/ui/match_hud_v2_interaction_lab.tscn"
)
const FORMAL_MATCH_STATE = preload("res://scripts/game/domain/match_state.gd")
const BOARD_WORLD_SIZE := Vector2(1152.0, 3072.0)
const EXPECTED_MAP_PATH := \
	"res://assets/art/boards/terracotta_warriors/terracotta_battlefield_board_bg_gridless_v7_low_noise.png"
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
	_expect(int(snapshot.get("piece_count", 0)) == 32, "lab did not render the formal 32-piece opening army")
	var rendered_paths: Array[String] = []
	for value: Variant in snapshot.get("piece_art_paths", []):
		rendered_paths.append(str(value))
	_expect(rendered_paths.size() == 32, "not every formal opening piece used an artwork texture")
	var unique_paths: Dictionary = {}
	for path: String in rendered_paths:
		unique_paths[path] = true
	_expect(unique_paths.size() == 14, "art showcase did not cover 14 unique piece textures")
	for path: String in EXPECTED_PIECE_PATHS:
		_expect(path in rendered_paths, "missing terracotta piece texture: %s" % path)
		_expect_texture_import(path, 0, true)
	_expect_texture_import(EXPECTED_MAP_PATH, 0, true)

	var formal_state: Dictionary = FORMAL_MATCH_STATE.create(471001)
	var player_view: Dictionary = match_screen.get_player_view_snapshot()
	var actual_by_id: Dictionary = {}
	for piece_value: Variant in player_view.get("pieces", []):
		var piece: Dictionary = piece_value
		actual_by_id[str(piece.get("id", ""))] = piece
	_expect(
		actual_by_id.size() == formal_state.get("pieces", {}).size(),
		"lab opening piece count drifted from the formal match state"
	)
	for expected_value: Variant in formal_state.get("pieces", {}).values():
		var expected_piece: Dictionary = expected_value
		var piece_id := str(expected_piece.get("id", ""))
		var actual_piece: Dictionary = actual_by_id.get(piece_id, {})
		_expect(not actual_piece.is_empty(), "lab omitted formal opening piece: %s" % piece_id)
		if actual_piece.is_empty():
			continue
		_expect(
			actual_piece.get("position", []) == expected_piece.get("position", []),
			"lab opening position drifted for piece: %s" % piece_id
		)
		_expect(
			str(actual_piece.get("piece_type", "")) == str(expected_piece.get("piece_type", ""))
			and str(actual_piece.get("side", "")) == str(expected_piece.get("side", "")),
			"lab opening identity drifted for piece: %s" % piece_id
		)

	var background: Sprite2D = lab.get_node(
		"MatchScreen/MatchHudV2/BoardFrame/BoardViewport/BoardSubViewport/BoardWorld/MapBackground"
	) as Sprite2D
	_expect(background.visible, "preset map background node remained hidden")
	_expect(is_equal_approx(background.scale.x, background.scale.y), "map background was stretched non-uniformly")
	_expect(
		background.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"map background did not use stable mipmapped linear sampling"
	)
	_expect(
		background.material == null,
		"map clarity still depended on the obsolete corrective sharpening shader"
	)

	var piece_layer: Node2D = lab.get_node(
		"MatchScreen/MatchHudV2/BoardFrame/BoardViewport/BoardSubViewport/BoardWorld/PieceLayer"
	) as Node2D
	var board_world: Node2D = piece_layer.get_parent() as Node2D
	var board_theme: BoardTheme = board_world.get("board_theme") as BoardTheme
	var grid_line_style: Dictionary = board_theme.grid_line_style
	_expect(
		float(grid_line_style.get("width", 0.0)) >= 5.0,
		"terracotta board grid lines were not strengthened"
	)
	_expect(
		(grid_line_style.get("color", Color.TRANSPARENT) as Color).a >= 0.9,
		"terracotta board grid line contrast was too weak"
	)
	var piece_sizing_checked := false
	for piece_view_value: Variant in piece_layer.get_children():
		var piece_view := piece_view_value as Node2D
		if piece_view == null:
			continue
		var artwork := piece_view.get_node_or_null("Artwork") as Sprite2D
		_expect(artwork != null and artwork.texture != null, "rendered piece artwork was missing")
		if artwork == null or artwork.texture == null:
			continue
		if not piece_sizing_checked:
			var scale_multipliers: Dictionary = piece_view.get("piece_scale_multipliers")
			for piece_type: String in ["horse", "rook", "cannon"]:
				_expect(
					float(scale_multipliers.get(piece_type, 1.0)) > 1.0,
					"%s did not receive an authored size increase" % piece_type
				)
			piece_sizing_checked = true
		_expect(
			artwork.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
			"piece artwork did not use stable mipmapped linear sampling"
		)
		var artwork_half_size := artwork.texture.get_size() * artwork.scale.abs() * 0.5
		var artwork_bounds := Rect2(
			piece_view.position + artwork.position - artwork_half_size,
			artwork_half_size * 2.0
		)
		_expect(
			artwork.position.is_zero_approx(),
			"board piece artwork was not centered on its board intersection"
		)
		_expect(
			artwork_bounds.position.x >= -0.1 and artwork_bounds.position.y >= -0.1 \
			and artwork_bounds.end.x <= BOARD_WORLD_SIZE.x + 0.1 \
			and artwork_bounds.end.y <= BOARD_WORLD_SIZE.y + 0.1,
			"board piece artwork exceeded the board world boundary: %s" % artwork_bounds
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
		print("MATCH_HUD_V2_TERRACOTTA_ART_PASS map=terracotta_battlefield_v3 pieces=32")
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


func _expect_texture_import(path: String, compress_mode: int, mipmaps: bool) -> void:
	var config := ConfigFile.new()
	var error := config.load(ProjectSettings.globalize_path(path + ".import"))
	_expect(error == OK, "texture import metadata was unavailable: %s" % path)
	if error != OK:
		return
	_expect(
		int(config.get_value("params", "compress/mode", -1)) == compress_mode,
		"texture was not imported losslessly: %s" % path
	)
	_expect(
		bool(config.get_value("params", "mipmaps/generate", false)) == mipmaps,
		"texture mipmap policy mismatch: %s" % path
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
