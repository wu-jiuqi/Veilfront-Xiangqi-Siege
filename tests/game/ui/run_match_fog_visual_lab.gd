extends SceneTree

const LAB_SCENE: PackedScene = preload("res://scenes/dev/ui/match_fog_visual_lab.tscn")
const OUTPUT_PATH := "res://.codex-temp/match-fog-visual-lab-1280x720.png"
const EXPECTED_SHADER_PATH := "res://shaders/dev/fog_of_war_lab.gdshader"

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
	await process_frame

	var snapshot: Dictionary = lab.call("get_lab_snapshot")
	var visual: Dictionary = snapshot.get("visual", {})
	_expect(bool(snapshot.get("fog_enabled", false)), "visual fog was not enabled")
	_expect(bool(snapshot.get("production_fog_hidden", false)), "production fog remained visible")
	_expect(str(snapshot.get("fog_parent", "")) == "BoardWorld", "visual fog was outside BoardWorld")
	_expect(
		int(snapshot.get("piece_index", -1)) < int(snapshot.get("fog_index", -1)),
		"visual fog did not render after pieces"
	)
	_expect(
		int(snapshot.get("fog_index", -1)) < int(snapshot.get("structure_index", -1)),
		"visual fog did not render before public structures"
	)
	_expect(int(visual.get("board_cell_count", 0)) == 216, "fog mask did not cover 9x24 board")
	_expect(int(visual.get("visible_cell_count", 0)) > 0, "fog mask had no visible cells")
	_expect(int(visual.get("fogged_cell_count", 0)) > 0, "fog mask had no fogged cells")
	_expect(bool(visual.get("uses_generated_mask", false)), "generated mask texture was missing")
	_expect(bool(visual.get("uses_player_view_only", false)), "visual fog contract was not observer-safe")
	_expect(
		str(visual.get("boundary_style", "")) == "shader_warped_irregular",
		"fog boundary fell back to rectangular rendering"
	)
	_expect(
		str(visual.get("mask_encoding", "")) == "visible_distance_field",
		"fog mask fell back to square-cell encoding"
	)
	_expect(visual.get("mask_size") == Vector2i(144, 384), "fog mask resolution changed")

	var fog_visual := lab.get_node(
		"MatchScreen/MatchHudV2/BoardFrame/BoardViewport/BoardSubViewport/BoardWorld/FogVisualOverlayLab"
	) as TextureRect
	var material := fog_visual.material as ShaderMaterial
	_expect(material != null and material.shader != null, "fog shader material was missing")
	if material != null and material.shader != null:
		_expect(material.shader.resource_path == EXPECTED_SHADER_PATH, "fog shader path mismatch")
		_expect(
			float(material.get_shader_parameter("boundary_warp")) >= 0.75,
			"fog boundary warp was too weak to break the cell silhouette"
		)
		_expect(
			float(material.get_shader_parameter("edge_breakup")) >= 0.3,
			"fog edge erosion was disabled"
		)

	lab.call("set_fog_enabled", false)
	_expect(not fog_visual.visible, "fog toggle did not hide visual fog")
	lab.call("set_fog_enabled", true)
	_expect(fog_visual.visible, "fog toggle did not restore visual fog")

	if "--capture-screenshot" in OS.get_cmdline_user_args():
		_capture_screenshot(viewport)

	lab.queue_free()
	viewport.queue_free()
	await process_frame
	if _failures.is_empty():
		print("MATCH_FOG_VISUAL_LAB_PASS visible=%d fogged=%d" % [
			int(visual.get("visible_cell_count", 0)),
			int(visual.get("fogged_cell_count", 0)),
		])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("MATCH_FOG_VISUAL_LAB_FAIL failures=%d" % _failures.size())
	quit(1)


func _capture_screenshot(viewport: SubViewport) -> void:
	var image := viewport.get_texture().get_image()
	if image == null:
		_failures.append("fog lab screenshot was unavailable")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.codex-temp"))
	var output_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	_expect(image.save_png(output_path) == OK, "failed to save fog lab screenshot")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
