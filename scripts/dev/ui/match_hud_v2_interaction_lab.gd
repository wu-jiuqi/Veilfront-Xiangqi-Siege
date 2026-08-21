extends Control

@onready var _match_screen: Control = $MatchScreen


func _ready() -> void:
	_match_screen.action_previews_requested.connect(_on_action_previews_requested)
	call_deferred("_seed_preview")


func _seed_preview() -> void:
	_match_screen.render_player_view(_build_player_view())


func _on_action_previews_requested(piece_id: String, action_type: String) -> void:
	if piece_id != "ui-test-cannon":
		_match_screen.render_action_previews_from_port([])
		return
	var target_cell: Array = [5, 6] if action_type == "move" else [6, 6]
	_match_screen.render_action_previews_from_port([{
		"preview_id": "ui-test-%s" % action_type,
		"piece_id": piece_id,
		"action_type": action_type,
		"target_cell": target_cell,
		"classification": "KNOWN_LEGAL",
		"message_key": "UI 测试预览",
	}])


func _build_player_view() -> Dictionary:
	var visible_cells: Array = []
	for authority_y: int in range(1, 10):
		for authority_x: int in range(1, 10):
			visible_cells.append([authority_x, authority_y])
	return {
		"match_id": "match-hud-v2-interaction-lab",
		"action_index": 1,
		"viewer_side": "red",
		"active_side": "red",
		"full_round_index": 18,
		"round_limit_public": 50,
		"terminal": false,
		"board": {"width": 9, "height": 24},
		"visible_cells": visible_cells,
		"hidden_detection_cells": [],
		"pieces": [{
			"alive": true,
			"id": "ui-test-cannon",
			"in_reserve": false,
			"piece_type": "cannon",
			"position": [5, 5],
			"side": "red",
			"status_tags": ["READY", "测试棋子"],
		}],
		"flags": [{
			"capture_progress": 0,
			"capturing_side": "",
			"contested": false,
			"discovered": true,
			"id": "ui-test-flag",
			"owner": "red",
			"position": [7, 7],
		}],
		"walls": [
			{"side": "red", "status": "INTACT"},
			{"side": "black", "status": "BREACHED"},
		],
		"casualties": [{"side": "black", "piece_type": "soldier"}],
		"capture_ghosts": [{
			"piece_id": "ui-test-ghost",
			"piece_type": "horse",
			"position": [3, 6],
			"side": "red",
		}],
		"vision_overlays": {
			"rook_paths": [],
			"elephant_reveal_zones": [],
			"elephant_block_fields": [],
		},
	}
