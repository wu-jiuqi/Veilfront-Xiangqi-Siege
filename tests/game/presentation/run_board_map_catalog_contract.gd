extends SceneTree

const CATALOG_PATH := "res://resources/game/content/boards/board_map_catalog.tres"
const EXPECTED_MAPS := {
	&"terracotta_battlefield_v3": {
		"path": "res://assets/art/boards/terracotta_warriors/terracotta_battlefield_board_bg_gridless_v7_low_noise.png",
		"size": Vector2i(823, 1911),
	},
	&"terracotta_grassland_pond_stream_v5": {
		"path": "res://assets/art/boards/terracotta_warriors/terracotta_grassland_board_bg_gridless_v5_pond_stream.png",
		"size": Vector2i(820, 1918),
	},
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as Resource
	if catalog == null:
		_failures.append("board map catalog failed to load")
		_finish()
		return
	if not catalog.has_method("get_selectable_maps") or not catalog.has_method("find_map"):
		_failures.append("board map catalog API is incomplete")
		_finish()
		return

	var selectable_maps: Array = catalog.call("get_selectable_maps")
	_expect(selectable_maps.size() == EXPECTED_MAPS.size(), "expected exactly two selectable maps")
	var observed_ids: Dictionary = {}
	for option_variant: Variant in selectable_maps:
		var option := option_variant as Resource
		if option == null:
			_failures.append("catalog contains a null or invalid map option")
			continue
		var map_id := StringName(option.get("map_id"))
		observed_ids[map_id] = true
		_expect(bool(option.get("selectable")), "%s must be selectable" % map_id)
		_expect(not str(option.get("display_name")).is_empty(), "%s display name is empty" % map_id)
		_expect(option.call("is_valid_definition"), "%s definition is invalid" % map_id)
		var texture := option.get("background_texture") as Texture2D
		_expect(texture != null, "%s background texture is missing" % map_id)
		if texture == null:
			continue
		var expected: Dictionary = EXPECTED_MAPS.get(map_id, {})
		_expect(
			texture.resource_path == str(expected.get("path", "")),
			"%s points to an unexpected texture" % map_id
		)
		_expect(
			Vector2i(texture.get_width(), texture.get_height()) == expected.get(
				"size", Vector2i.ZERO
			),
			"%s texture size drifted from the approved asset" % map_id
		)

	for expected_id: StringName in EXPECTED_MAPS:
		_expect(observed_ids.has(expected_id), "missing selectable map: %s" % expected_id)
		_expect(catalog.call("find_map", expected_id) != null, "find_map failed: %s" % expected_id)
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("BOARD_MAP_CATALOG_PASS selectable=2 ids=%s" % [EXPECTED_MAPS.keys()])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("BOARD_MAP_CATALOG_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
