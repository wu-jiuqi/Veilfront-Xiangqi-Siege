extends SceneTree

const VFX_SCENE: PackedScene = preload("res://scenes/game/vfx/vfx_root.tscn")
const Policy = preload("res://scripts/game/vfx/observer_vfx_policy.gd")
const CueContract = preload("res://scripts/game/vfx/vfx_cue.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var director := VFX_SCENE.instantiate() as VfxDirector
	director.position = Vector2(40.0, 40.0)
	director.cell_size = Vector2(48.0, 24.0)
	viewport.add_child(director)
	await process_frame
	var standard: Dictionary = Policy.derive_local_selection_batch(
		"vfx-smoke", 3, 2, 1, [3, 7], "red", "standard"
	)
	_expect(director.play_batch(standard) == 1, "标准selection应播放一次", failures)
	_expect(director.play_batch(standard) == 0, "重复batch应被去重", failures)
	var standard_snapshot: Dictionary = director.get_pool_snapshot()
	_expect(standard_snapshot["world_slot_count"] == 9, "应有9个预置棋盘槽", failures)
	_expect(standard_snapshot["global_slot_count"] == 3, "应有3个预置global槽", failures)
	_expect(standard_snapshot["active_count"] == 1, "标准selection应占用一个槽", failures)
	_expect(standard_snapshot["overdraw_points"] <= 100, "标准过绘不得超预算", failures)
	var world_slot := director.get_node("WorldPool/World01") as VfxEffectSlot
	var expected_red := Vector2(120.0, 420.0)
	_expect(world_slot.position == expected_red, "红方公开位置应映射到正式棋盘坐标", failures)

	director.clear_all()
	director.set_display_side("black")
	var reduced: Dictionary = Policy.derive_local_selection_batch(
		"vfx-smoke", 3, 2, 2, [3, 7], "red", "reduced"
	)
	_expect(director.play_batch(reduced) == 1, "reduced selection应播放一次", failures)
	var reduced_snapshot: Dictionary = director.get_pool_snapshot()
	_expect(reduced_snapshot["overdraw_points"] <= 56, "减少动态过绘不得超预算", failures)
	_expect(not bool(reduced_snapshot["active"][0]["particles_emitting"]), "减少动态selection必须关闭粒子", failures)
	var expected_black := Vector2(312.0, 156.0)
	_expect(world_slot.position == expected_black, "黑方镜像只改变公开位置映射", failures)

	director.clear_all()
	var terminal_view := _terminal_view()
	var terminal_batch: Dictionary = Policy.derive_batch({}, terminal_view, [], "reduced")
	_expect(director.play_batch(terminal_batch) == 1, "首次终局基线允许一次global提示", failures)
	var terminal_snapshot: Dictionary = director.get_pool_snapshot()
	_expect(terminal_snapshot["active_count"] == 1, "终局应占用一个global槽", failures)
	_expect(terminal_snapshot["active"][0]["family"] == "terminal", "终局应匹配terminal定义", failures)
	_expect(terminal_snapshot["overdraw_points"] <= 56, "终局降级仍需满足预算", failures)

	director.clear_all()
	director.set_display_side("red")
	var peak_batch := _peak_batch("standard")
	_expect(director.play_batch(peak_batch) == 7, "标准七族峰值应由预置池承载", failures)
	var peak_snapshot: Dictionary = director.get_pool_snapshot()
	_expect(peak_snapshot["active_count"] == 7, "七族峰值应保持七个活动效果", failures)
	_expect(peak_snapshot["overdraw_points"] == 95, "标准七族峰值预算应为95 points", failures)

	director.clear_all()
	var reduced_peak := _peak_batch("reduced")
	_expect(director.play_batch(reduced_peak) == 7, "减少动态七族峰值应由预置池承载", failures)
	var reduced_peak_snapshot: Dictionary = director.get_pool_snapshot()
	_expect(reduced_peak_snapshot["overdraw_points"] == 34, "减少动态七族峰值应为34 points", failures)

	if failures.is_empty():
		print("VFX_SCENE_SMOKE_PASS pool=9+3 peak_standard=95 peak_reduced=34 dedup=true reduced_motion=true gl_compatibility=true")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _terminal_view() -> Dictionary:
	return {
		"schema_version": "veilfront-player-view-v1",
		"match_id": "vfx-smoke-terminal",
		"rules_revision": "owner-rule-revision-5",
		"viewer_side": "red",
		"board": {"width": 9, "height": 24},
		"active_side": "red",
		"action_index": 9,
		"full_round_index": 5,
		"round_limit_public": 50,
		"terminal": true,
		"winner": "red",
		"win_reason": "three_flags",
		"visible_cells": [],
		"hidden_detection_cells": [],
		"pieces": [],
		"flags": [],
		"walls": [],
		"casualties": [],
		"capture_ghosts": [],
		"vision_overlays": {"rook_paths": [], "elephant_reveal_zones": [], "elephant_block_fields": []},
		"contact_intel": [],
		"visible_event_cursor": 0,
	}


func _peak_batch(motion_profile: String) -> Dictionary:
	var specs: Array[Dictionary] = [
		{"key": "vfx.selection.focus", "position": [2, 5], "priority": "normal", "group": "selection", "late": "replace_group"},
		{"key": "vfx.move.step", "position": [7, 7], "priority": "normal", "group": "move", "late": "drop_if_late"},
		{"key": "vfx.capture.impact", "position": [3, 11], "priority": "high", "group": "capture", "late": "play_once"},
		{"key": "vfx.bombardment.resolve", "position": [7, 14], "priority": "high", "group": "bombardment", "late": "play_once"},
		{"key": "vfx.wall.breached", "position": [5, 21], "priority": "high", "group": "wall", "late": "replace_group"},
		{"key": "vfx.flag.captured", "position": [3, 18], "priority": "high", "group": "flag", "late": "replace_group"},
		{"key": "vfx.terminal.victory", "position": [], "priority": "critical", "group": "terminal", "late": "play_once"},
	]
	var cues: Array = []
	for index: int in specs.size():
		var spec: Dictionary = specs[index]
		cues.append(CueContract.build(
			"vfx-smoke-peak", 10, str(spec["key"]), "local_interaction" if index == 0 else "view_diff",
			10, 0, "global" if spec["position"].is_empty() else "board_2d",
			spec["position"], str(spec["priority"]), str(spec["group"]), str(spec["late"]),
			"red", motion_profile, "peak-%d" % index
		))
	return CueContract.build_batch("vfx-smoke-peak", 10, 10, motion_profile, cues)


func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
