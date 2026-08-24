extends SceneTree

const OUTPUT_PATH := "res://evidence/gate2/v3-candidate-05ada98/asset-memory-estimate.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var png_paths: Array[String] = []
	_collect_png("res://assets", png_paths)
	var categories := {}
	var importable_bytes := 0
	var importable_count := 0
	var ignored_count := 0
	var top: Array[Dictionary] = []
	for path: String in png_paths:
		var ignored := "/source_chroma/" in path
		var category := "ignored_source_chroma" if ignored else _category(path)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			push_error("ASSET_MEMORY_ESTIMATE_FAIL unreadable=%s" % path)
			quit(1)
			return
		var bytes := image.get_width() * image.get_height() * 4
		var current: Dictionary = categories.get(category, {"count": 0, "rgba_bytes": 0})
		current["count"] = int(current.get("count", 0)) + 1
		current["rgba_bytes"] = int(current.get("rgba_bytes", 0)) + bytes
		categories[category] = current
		if ignored:
			ignored_count += 1
		else:
			importable_count += 1
			importable_bytes += bytes
			top.append({"path": path, "width": image.get_width(), "height": image.get_height(), "rgba_bytes": bytes})
	top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.rgba_bytes) > int(b.rgba_bytes))
	if top.size() > 25:
		top.resize(25)
	var font_paths: Array[String] = []
	_collect_extension("res://assets/fonts", "ttf", font_paths)
	var fonts: Array[Dictionary] = []
	var font_bytes := 0
	for path: String in font_paths:
		var bytes := FileAccess.get_file_as_bytes(path).size()
		font_bytes += bytes
		fonts.append({"path": path, "file_bytes": bytes})
	var result := {
		"schema_version": "veilfront-gate2-rc5-asset-memory-estimate-v1",
		"candidate": "05ada9848c20c41b6d6cc92ce552df643c31438c",
		"method": "source PNG dimensions x RGBA8; full mip-chain conservative multiplier 4/3; source_chroma excluded by .gdignore; all other assets/* remain export candidates under all_resources",
		"png_source_total": png_paths.size(),
		"png_source_chroma_ignored": ignored_count,
		"png_importable_candidate_count": importable_count,
		"png_importable_rgba_bytes": importable_bytes,
		"png_importable_rgba_mips_bytes": int(ceil(importable_bytes * 4.0 / 3.0)),
		"categories": categories,
		"font_file_count": fonts.size(),
		"font_file_bytes": font_bytes,
		"fonts": fonts,
		"top_importable_textures": top,
		"limitations": [
			"worst-case export-candidate estimate is not simultaneous resident VRAM",
			"font atlas GPU allocation is dynamic and not represented by raw TTF bytes",
			"driver compression and texture import format are not modeled",
		],
	}
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ASSET_MEMORY_ESTIMATE_FAIL cannot_open_output")
		quit(2)
		return
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("GATE2_RC5_ASSET_MEMORY_ESTIMATE_PASS png=%d importable=%d rgba_bytes=%d mip_bytes=%d fonts=%d font_bytes=%d path=%s" % [png_paths.size(), importable_count, importable_bytes, int(ceil(importable_bytes * 4.0 / 3.0)), fonts.size(), font_bytes, OUTPUT_PATH])
	quit(0)


func _category(path: String) -> String:
	if "/concepts/" in path:
		return "concepts_export_candidate"
	if "/tutorial/comic_v1/" in path:
		return "tutorial_comic_runtime"
	if "/ui/match_hud_v3/" in path or "/ui/level_guide_panel/" in path \
		or "/ui/system_dialog/" in path or path.ends_with("/level_select_empty_background_v3.png"):
		return "rc5_integrated_ui_runtime"
	if "/ui/" in path:
		return "ui_runtime_or_reference"
	return "game_art_runtime_or_reference"


func _collect_png(directory: String, output: Array[String]) -> void:
	_collect_extension(directory, "png", output)


func _collect_extension(directory: String, extension: String, output: Array[String]) -> void:
	var access := DirAccess.open(directory)
	if access == null:
		return
	access.list_dir_begin()
	while true:
		var name := access.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		var path := directory.path_join(name)
		if access.current_is_dir():
			_collect_extension(path, extension, output)
		elif name.get_extension().to_lower() == extension:
			output.append(path)
	access.list_dir_end()
