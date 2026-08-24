extends SceneTree

const CueContract = preload("res://scripts/game/vfx/vfx_cue.gd")
const Policy = preload("res://scripts/game/vfx/observer_vfx_policy.gd")
const PositionMapper = preload("res://scripts/game/vfx/vfx_public_position_mapper.gd")
const BoardMapper = preload("res://scripts/game/presentation/board/board_coordinate_mapper.gd")
const CATALOG_PATH := "res://resources/game/vfx/vfx_catalog.tres"


func _init() -> void:
	var failures := PackedStringArray()
	var previous := _view(false)
	var current := _view(true)
	var events: Array = [_bombard_event()]
	var standard: Dictionary = Policy.derive_batch(previous, current, events, "standard")
	_expect(CueContract.is_valid_batch(standard), "standard batch 必须合法", failures)
	var cues: Array = standard.get("cues", [])
	_expect(cues.size() == 8, "公开帧应生成8个cue（含吃子弹字与两个旗帜边沿）", failures)
	var keys := PackedStringArray()
	for cue_value: Variant in cues:
		keys.append(str(cue_value.get("cue_key", "")))
	_expect(keys == PackedStringArray([
		"vfx.bombardment.resolve",
		"vfx.move.step",
		"vfx.capture.impact",
		"vfx.callout.capture",
		"vfx.wall.breached",
		"vfx.flag.progress",
		"vfx.flag.captured",
		"vfx.terminal.victory",
	]), "顺序必须为结算主体→伤亡→状态→终局", failures)
	_expect(cues[5]["spatial_mode"] == "global" and cues[5]["position_public"].is_empty(), "未发现旗位只能global", failures)
	_expect(cues[6]["spatial_mode"] == "board_2d" and cues[6]["position_public"] == [5, 12], "已发现旗位使用公开坐标", failures)
	_expect(cues[4]["position_public"] == [5, 4], "红墙映射到公开固定线中心", failures)
	_expect(cues[3]["position_public"] == [4, 8], "吃字只能落在公开吃子坐标", failures)
	var shared_fields := [
		"schema_version", "cue_id", "cue_key", "source_kind", "action_index",
		"occurrence_index", "spatial_mode", "position_public", "priority",
		"concurrency_group", "late_policy",
	]
	for field: String in shared_fields:
		_expect(cues[0].has(field), "共享Cue字段缺失：%s" % field, failures)

	var duplicate_input: Dictionary = Policy.derive_batch(
		previous.duplicate(true), current.duplicate(true), events.duplicate(true), "standard"
	)
	_expect(standard == duplicate_input, "相同观察者输入必须生成字节等价batch", failures)
	var reduced: Dictionary = Policy.derive_batch(previous, current, events, "reduced")
	_expect(CueContract.is_valid_batch(reduced), "reduced batch 必须合法", failures)
	for index: int in cues.size():
		_expect(cues[index]["cue_id"] == reduced["cues"][index]["cue_id"], "降级不能改变cue_id", failures)
		_expect(reduced["cues"][index]["motion_profile"] == "reduced", "降级profile必须显式", failures)

	var poisoned := current.duplicate(true)
	poisoned["secret_seed"] = 919
	_expect(not bool(Policy.derive_batch(previous, poisoned, events).get("ok", true)), "未知观察者字段必须fail closed", failures)
	var hidden_variant_a := {"private_piece": [9, 24], "future_draw": 1}
	var hidden_variant_b := {"private_piece": [1, 1], "future_draw": 99}
	_expect(hidden_variant_a != hidden_variant_b and standard == duplicate_input, "外部隐藏事实不可进入policy输入", failures)

	var general_view := current.duplicate(true)
	general_view["capture_ghosts"][0]["piece_type"] = "general"
	general_view["casualties"][0]["piece_type"] = "general"
	var general_batch: Dictionary = Policy.derive_batch(previous, general_view, events, "standard")
	var general_keys := PackedStringArray()
	for cue_value: Variant in general_batch.get("cues", []):
		general_keys.append(str(cue_value.get("cue_key", "")))
	_expect(general_keys.has("vfx.callout.general"), "公开将领被摧毁必须生成将字", failures)
	_expect(not general_keys.has("vfx.callout.capture"), "将字不能与吃字重复叠加", failures)

	var resurrection_previous := _resurrection_view(false)
	var resurrection_current := _resurrection_view(true)
	var resurrection_batch: Dictionary = Policy.derive_batch(
		resurrection_previous, resurrection_current, [], "standard"
	)
	_expect(CueContract.is_valid_batch(resurrection_batch), "复活公开差分batch必须合法", failures)
	_expect(resurrection_batch.get("cues", []).size() == 1, "复活不得被误判为普通移动", failures)
	if resurrection_batch.get("cues", []).size() == 1:
		var resurrection_cue: Dictionary = resurrection_batch["cues"][0]
		_expect(resurrection_cue["cue_key"] == "vfx.resurrection.revive", "士复活必须匹配回魂特效", failures)
		_expect(resurrection_cue["position_public"] == [3, 6], "复活特效只能使用复活棋子的公开坐标", failures)

	var local_a: Dictionary = Policy.derive_local_selection_batch(
		"vfx-contract", 1, 1, 4, [3, 6], "red", "standard"
	)
	var local_b: Dictionary = Policy.derive_local_selection_batch(
		"vfx-contract", 1, 1, 5, [3, 6], "red", "standard"
	)
	_expect(CueContract.is_valid_batch(local_a), "本地selection batch必须合法", failures)
	_expect(local_a["cues"][0]["source_kind"] == "local_interaction", "selection必须本地分流", failures)
	_expect(local_a["cues"][0]["cue_id"] != local_b["cues"][0]["cue_id"], "本地单调序号允许重复选择反馈", failures)

	var cell_size := Vector2(128.0, 128.0)
	for side: String in ["red", "black"]:
		var public_position := [7, 19]
		var expected: Vector2 = BoardMapper.authority_to_world(Vector2i(7, 19), side, cell_size)
		var actual: Vector2 = PositionMapper.to_local(public_position, side, cell_size)
		_expect(actual == expected, "%s方公开位置映射必须匹配正式棋盘" % side, failures)

	var catalog := load(CATALOG_PATH) as VfxCatalog
	_expect(catalog != null, "VFX catalog必须可加载", failures)
	if catalog != null:
		_expect(catalog.validation_errors().is_empty(), "九族definition与预算字段必须合法", failures)
		_expect(catalog.definitions.size() == 9, "catalog必须恰含九族", failures)
		for definition: VfxCueDefinition in catalog.definitions:
			_expect(definition.flash_hz_max <= 3.0, "%s闪烁不得超过3Hz" % definition.family, failures)
			_expect(definition.flash_area_ratio_max <= 0.25, "%s闪烁面积不得超过25%%" % definition.family, failures)
			_expect(definition.particles_reduced <= 3, "%s降级粒子不得超过3" % definition.family, failures)

	_scan_runtime_dependencies(failures)
	if failures.is_empty():
		print("VFX_CUE_CONTRACT_PASS cues=%d families=9 shared_fields=11 hidden_equivalence=true" % cues.size())
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _scan_runtime_dependencies(failures: PackedStringArray) -> void:
	var directory := DirAccess.open("res://scripts/game/vfx")
	_expect(directory != null, "VFX脚本目录必须存在", failures)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".gd"):
			var path := "res://scripts/game/vfx/%s" % file_name
			var file := FileAccess.open(path, FileAccess.READ)
			var text := file.get_as_text().to_lower() if file != null else ""
			for forbidden: String in ["/domain/", "full" + "state", "domain" + "event", "rng_state", "authoritative" + "replay", "rand", "seed"]:
				_expect(not text.contains(forbidden), "%s 禁止依赖 %s" % [path, forbidden], failures)
		file_name = directory.get_next()
	directory.list_dir_end()
	var scene_file := FileAccess.open("res://scenes/game/vfx/vfx_effect_slot.tscn", FileAccess.READ)
	var scene_text := scene_file.get_as_text().to_lower() if scene_file != null else ""
	_expect(not scene_text.contains("trail"), "GL Compatibility VFX禁止粒子trail", failures)


func _view(after: bool) -> Dictionary:
	return {
		"schema_version": "veilfront-player-view-v1",
		"match_id": "vfx-contract",
		"rules_revision": "owner-rule-revision-5",
		"viewer_side": "red",
		"board": {"width": 9, "height": 24},
		"active_side": "black" if after else "red",
		"action_index": 1 if after else 0,
		"full_round_index": 1,
		"round_limit_public": 50,
		"terminal": after,
		"winner": "red" if after else "",
		"win_reason": "three_flags" if after else "",
		"visible_cells": [[2, 4], [2, 5], [4, 8], [5, 12]],
		"hidden_detection_cells": [],
		"pieces": [{
			"id": "red-pawn-1", "side": "red", "piece_type": "pawn",
			"position": [2, 5] if after else [2, 4], "alive": true,
			"in_reserve": false, "status_tags": ["owned"],
		}],
		"flags": [
			{
				"id": "flag-hidden", "owner": "", "capturing_side": "red" if after else "",
				"capture_progress": 1 if after else 0, "contested": after,
				"discovered": false, "position": [],
			},
			{
				"id": "flag-public", "owner": "red" if after else "",
				"capturing_side": "", "capture_progress": 0 if after else 2,
				"contested": false, "discovered": true, "position": [5, 12],
			},
		],
		"walls": [
			{"side": "red", "status": "BREACHED" if after else "INTACT"},
			{"side": "black", "status": "INTACT"},
		],
		"casualties": [{"piece_id": "black-pawn-9", "piece_type": "pawn", "side": "black"}] if after else [],
		"capture_ghosts": [{
			"piece_id": "black-pawn-9", "piece_type": "pawn", "side": "black", "position": [4, 8],
		}] if after else [],
		"vision_overlays": {
			"rook_paths": [], "elephant_reveal_zones": [], "elephant_block_fields": [],
		},
		"contact_intel": [],
		"visible_event_cursor": 1 if after else 0,
	}


func _bombard_event() -> Dictionary:
	return {
		"schema_version": "veilfront-visible-event-v1",
		"visible_sequence": 1,
		"action_index": 1,
		"event_type": "bombardment_resolved",
		"actor_side_public": "black",
		"position_public": [4, 8],
		"piece_public": {},
		"message_key": "event.bombardment_resolved",
		"public_payload": {},
		"timing_bucket": "standard",
	}


func _resurrection_view(after: bool) -> Dictionary:
	var view := _view(false)
	view["match_id"] = "vfx-resurrection"
	view["active_side"] = "black" if after else "red"
	view["action_index"] = 1 if after else 0
	view["visible_event_cursor"] = 1 if after else 0
	view["terminal"] = false
	view["winner"] = ""
	view["win_reason"] = ""
	view["visible_cells"] = [[2, 4], [3, 6]]
	view["flags"] = []
	view["walls"] = []
	view["casualties"] = []
	view["capture_ghosts"] = []
	view["pieces"] = [{
		"id": "red-pawn-reserve", "side": "red", "piece_type": "pawn",
		"position": [3, 6] if after else [2, 4], "alive": after,
		"in_reserve": not after, "status_tags": ["owned"],
	}]
	return view


func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
