extends SceneTree

const LAB_SCENE: PackedScene = preload("res://scenes/dev/ui/match_hud_v2_interaction_lab.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/game/ui/match_hud_v2.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var authored_hud := HUD_SCENE.instantiate() as MatchHudLayout
	var authored_layouts := {
		"FactionLeft": _control_layout(authored_hud.get_node("FactionLeft") as Control),
		"FactionRight": _control_layout(authored_hud.get_node("FactionRight") as Control),
		"UnitInfo": _control_layout(authored_hud.get_node("UnitInfo") as Control),
		"PieceInfoDrawer": _control_layout(authored_hud.get_node("PieceInfoDrawer") as Control),
		"FactionLeft/Portrait": _control_layout(authored_hud.get_node("FactionLeft/Portrait") as Control),
		"FactionRight/Portrait": _control_layout(authored_hud.get_node("FactionRight/Portrait") as Control),
		"UnitInfo/UnitName": _control_layout(authored_hud.get_node("UnitInfo/UnitName") as Control),
		"UnitInfo/UnitPortrait": _control_layout(authored_hud.get_node("UnitInfo/UnitPortrait") as Control),
	}
	authored_hud.free()

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lab := LAB_SCENE.instantiate() as Control
	viewport.add_child(lab)
	await process_frame
	await process_frame

	var hud := lab.get_node("MatchScreen/MatchHudV2") as MatchHudLayout
	var snapshot := hud.get_layout_snapshot()
	_expect(str(snapshot.get("active_profile", "")) == "scene-authored", "交互实验仍在使用 JSON 布局档案")
	for node_path_value: Variant in authored_layouts.keys():
		var node_path := str(node_path_value)
		_expect_layout(
			hud.get_node(node_path) as Control,
			authored_layouts.get(node_path, {}) as Dictionary,
			node_path
		)

	lab.queue_free()
	viewport.queue_free()
	await process_frame
	_finish()


func _control_layout(control: Control) -> Dictionary:
	return {
		"anchors": Vector4(control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom),
		"offsets": Vector4(control.offset_left, control.offset_top, control.offset_right, control.offset_bottom),
	}


func _expect_layout(control: Control, expected: Dictionary, label: String) -> void:
	_expect(control != null, "%s节点不存在" % label)
	if control == null:
		return
	var actual := _control_layout(control)
	var actual_anchors: Vector4 = actual.get("anchors", Vector4.ZERO)
	var expected_anchors: Vector4 = expected.get("anchors", Vector4.ZERO)
	var actual_offsets: Vector4 = actual.get("offsets", Vector4.ZERO)
	var expected_offsets: Vector4 = expected.get("offsets", Vector4.ZERO)
	_expect(
		actual_anchors.is_equal_approx(expected_anchors),
		"%s锚点没有保留 match_hud_v2.tscn 的值：%s" % [label, actual.get("anchors")]
	)
	_expect(
		actual_offsets.is_equal_approx(expected_offsets),
		"%s偏移没有保留 match_hud_v2.tscn 的值：%s" % [label, actual.get("offsets")]
	)


func _finish() -> void:
	if _failures.is_empty():
		print("MATCH_HUD_V2_LAB_SCENE_LAYOUT_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("MATCH_HUD_V2_LAB_SCENE_LAYOUT_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
