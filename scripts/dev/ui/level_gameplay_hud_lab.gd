extends Control

const FORMAL_MATCH_STATE = preload("res://scripts/game/domain/match_state.gd")
const SAMPLE_CELL := Vector2i(2, 3)
const GUIDE_PREVIEW_VIEW := {
	"title": "关卡指引",
	"objective": "田字封路：控制中央区域并完成协同行动。",
	"steps": [
		{"text": "移动兵至指定交点", "status": "complete"},
		{"text": "形成田字封路", "status": "active"},
		{"text": "确认行动完成关卡", "status": "pending"},
	],
	"current_operation": "选择兵并移动至高亮交点",
	"hint": "先占据田字右下角，再用相封锁斜线。",
	"hint_revealed": false,
}

@onready var _online_match_screen: Control = %OnlineMatchScreen
@onready var _level_guide_panel: Control = %LevelGuidePanel

var _initialized := false
var _last_guide_event := ""


func _ready() -> void:
	_level_guide_panel.hint_requested.connect(_on_hint_requested)
	_level_guide_panel.reset_requested.connect(_on_reset_requested)
	_level_guide_panel.collapsed_changed.connect(_on_collapsed_changed)
	call_deferred("_initialize_preview")


func get_lab_snapshot() -> Dictionary:
	var hud := _online_match_screen.get_node("MatchHudV3") as Control
	var original_right := hud.get_node("SafeMargin/MainRows/BodyBand/RightRail") as Control
	var objective_events := original_right.get_node("ObjectiveEvents") as Control
	var confirmation := original_right.get_node("Confirmation") as Control
	var board_viewport := hud.get_node(
		"SafeMargin/MainRows/BodyBand/CenterColumn/BoardFrame/BoardViewport"
	) as Control
	return {
		"initialized": _initialized,
		"uses_online_match_screen_scene": _online_match_screen.scene_file_path \
			== "res://scenes/game/match/online_match_screen.tscn",
		"uses_match_hud_v3": hud.scene_file_path == "res://scenes/game/ui/match_hud_v3.tscn",
		"original_right_rail_visible": original_right.visible,
		"original_right_content_hidden": not objective_events.visible \
			and not confirmation.visible,
		"original_right_rect": original_right.get_global_rect(),
		"guide_rect": _level_guide_panel.get_global_rect(),
		"guide": _level_guide_panel.get_state_snapshot(),
		"board": board_viewport.call("get_render_snapshot") as Dictionary,
		"last_guide_event": _last_guide_event,
	}


func reveal_hint_for_test() -> void:
	_level_guide_panel.reveal_hint()


func reset_guide_for_test() -> void:
	_level_guide_panel.reset_progress()


func collapse_guide_for_test(collapsed: bool) -> void:
	_level_guide_panel.set_collapsed(collapsed)


func _initialize_preview() -> void:
	_online_match_screen.call("set_session_navigation_enabled", false)
	_online_match_screen.call("set_level_guide_layout_enabled", true)
	_online_match_screen.call("render_player_view", _build_player_view())
	_online_match_screen.call("handle_board_point", SAMPLE_CELL)
	var hud := _online_match_screen.get_node("MatchHudV3") as Control
	var original_right := hud.get_node("SafeMargin/MainRows/BodyBand/RightRail") as Control
	original_right.visible = true
	original_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(original_right.get_node("ObjectiveEvents") as Control).visible = false
	(original_right.get_node("Confirmation") as Control).visible = false
	var board_sub_viewport := hud.get_node(
		"SafeMargin/MainRows/BodyBand/CenterColumn/BoardFrame/BoardViewport/BoardSubViewport"
	) as SubViewport
	board_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_level_guide_panel.call("configure", GUIDE_PREVIEW_VIEW)
	_initialized = true


func _build_player_view() -> Dictionary:
	var formal_state: Dictionary = FORMAL_MATCH_STATE.create(471001)
	var pieces: Array = []
	for piece_value: Variant in formal_state.get("pieces", {}).values():
		if piece_value is Dictionary:
			pieces.append((piece_value as Dictionary).duplicate(true))
	return {
		"match_id": "level-gameplay-hud-layout-lab",
		"action_index": 1,
		"viewer_side": "red",
		"active_side": "red",
		"full_round_index": 6,
		"round_limit_public": 20,
		"terminal": false,
		"board": {"width": 9, "height": 24},
		"visible_cells": _all_visible_cells(),
		"hidden_detection_cells": [],
		"pieces": pieces,
		"flags": [
			{
				"capture_progress": 3,
				"capturing_side": "",
				"contested": false,
				"discovered": true,
				"id": "level-lab-owned",
				"owner": "red",
				"position": [5, 7],
			},
			{
				"capture_progress": 1,
				"capturing_side": "red",
				"contested": false,
				"discovered": true,
				"id": "level-lab-target",
				"owner": "",
				"position": [5, 12],
			},
		],
		"walls": [
			{"side": "red", "status": "INTACT"},
			{"side": "black", "status": "INTACT"},
		],
		"casualties": [],
		"capture_ghosts": [],
		"vision_overlays": {
			"rook_paths": [],
			"elephant_reveal_zones": [],
			"elephant_block_fields": [],
		},
	}


func _all_visible_cells() -> Array:
	var cells: Array = []
	for y: int in range(1, 25):
		for x: int in range(1, 10):
			cells.append([x, y])
	return cells


func _on_hint_requested() -> void:
	_last_guide_event = "hint_requested"


func _on_reset_requested() -> void:
	_last_guide_event = "reset_requested"


func _on_collapsed_changed(collapsed: bool) -> void:
	_last_guide_event = "collapsed" if collapsed else "expanded"
