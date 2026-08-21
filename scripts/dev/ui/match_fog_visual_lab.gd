extends Control

const FOG_VISUAL_OVERLAY_SCENE: PackedScene = preload(
	"res://scenes/dev/ui/fog_visual_overlay_lab.tscn"
)

@export var board_theme: BoardTheme
@export var map_option: BoardMapOption

@onready var _match_screen: Control = $MatchScreen
@onready var _fog_toggle: CheckButton = $LabToolbar/Margin/VBox/Controls/FogToggle
@onready var _focus_button: Button = $LabToolbar/Margin/VBox/Controls/FocusButton
@onready var _status_label: Label = $LabToolbar/Margin/VBox/StatusLabel

var _fog_visual: TextureRect
var _player_view: Dictionary = {}


func _ready() -> void:
	_match_screen.set_board_presentation_assets(board_theme, map_option)
	_match_screen.action_previews_requested.connect(_on_action_previews_requested)
	_fog_toggle.toggled.connect(set_fog_enabled)
	_focus_button.pressed.connect(_focus_warzone)
	var mirror_button := _match_screen.get_node(
		"MatchHudV2/FactionRight/MirrorButton"
	) as Button
	mirror_button.pressed.connect(func() -> void: call_deferred("_refresh_fog_orientation"))
	call_deferred("_seed_preview")


func set_fog_enabled(enabled: bool) -> void:
	if _fog_toggle.button_pressed != enabled:
		_fog_toggle.set_pressed_no_signal(enabled)
	if is_instance_valid(_fog_visual):
		_fog_visual.visible = enabled
	_fog_toggle.text = "雾效：开启" if enabled else "雾效：关闭"
	_update_status()


func get_lab_snapshot() -> Dictionary:
	var fog_snapshot: Dictionary = _fog_visual.get_visual_snapshot() \
		if is_instance_valid(_fog_visual) else {}
	return {
		"fog_enabled": is_instance_valid(_fog_visual) and _fog_visual.visible,
		"fog_parent": _fog_visual.get_parent().name if is_instance_valid(_fog_visual) else "",
		"fog_index": _fog_visual.get_index() if is_instance_valid(_fog_visual) else -1,
		"piece_index": _piece_layer().get_index(),
		"structure_index": _board_world().get_node("StructureLayer").get_index(),
		"production_fog_hidden": not _production_fog().visible,
		"visual": fog_snapshot,
	}


func _seed_preview() -> void:
	_player_view = _build_player_view()
	_match_screen.render_player_view(_player_view)
	_install_visual_fog()
	_focus_warzone()
	_update_status()


func _install_visual_fog() -> void:
	var board_world: Node2D = _board_world()
	var production_fog: Control = _production_fog()
	var piece_layer: Node2D = _piece_layer()
	production_fog.visible = false
	board_world.move_child(piece_layer, production_fog.get_index())
	_fog_visual = FOG_VISUAL_OVERLAY_SCENE.instantiate() as TextureRect
	board_world.add_child(_fog_visual)
	board_world.move_child(_fog_visual, piece_layer.get_index() + 1)
	_refresh_fog_orientation()


func _refresh_fog_orientation() -> void:
	if not is_instance_valid(_fog_visual):
		return
	var board_viewport: Control = _board_viewport()
	_fog_visual.call(
		"render",
		_player_view.get("visible_cells", []),
		str(board_viewport.call("get_presentation_side")),
		board_theme.cell_size
	)


func _focus_warzone() -> void:
	_board_viewport().call("focus_authority_cell", Vector2i(5, 13))


func _on_action_previews_requested(piece_id: String, action_type: String) -> void:
	if piece_id != "fog-lab-red-rook":
		_match_screen.render_action_previews_from_port([])
		return
	var target_cell: Array = [5, 14] if action_type == "move" else [6, 14]
	_match_screen.render_action_previews_from_port([{
		"preview_id": "fog-lab-%s" % action_type,
		"piece_id": piece_id,
		"action_type": action_type,
		"target_cell": target_cell,
		"classification": "TENTATIVE",
		"message_key": "雾中行动测试",
	}])


func _update_status() -> void:
	if not is_instance_valid(_fog_visual):
		_status_label.text = "正在生成观察者雾层……"
		return
	var snapshot: Dictionary = _fog_visual.get_visual_snapshot()
	_status_label.text = "当前可见 %d 格 · 入雾 %d 格 · 旗帜记忆保留在雾层上方" % [
		int(snapshot.get("visible_cell_count", 0)),
		int(snapshot.get("fogged_cell_count", 0)),
	]


func _build_player_view() -> Dictionary:
	var visible_set: Dictionary = {}
	_add_center_vision(visible_set, Vector2i(3, 11))
	_add_center_vision(visible_set, Vector2i(5, 13))
	_add_center_vision(visible_set, Vector2i(7, 14))
	for authority_y: int in range(9, 16):
		visible_set[Vector2i(5, authority_y)] = true
	var visible_cells: Array = []
	for cell_value: Variant in visible_set.keys():
		var cell: Vector2i = cell_value
		visible_cells.append([cell.x, cell.y])
	visible_cells.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[1]) < int(b[1]) or (int(a[1]) == int(b[1]) and int(a[0]) < int(b[0]))
	)
	return {
		"match_id": "match-fog-visual-lab",
		"action_index": 18,
		"viewer_side": "red",
		"active_side": "red",
		"full_round_index": 9,
		"round_limit_public": 50,
		"terminal": false,
		"winner": "",
		"win_reason": "",
		"board": {"width": 9, "height": 24},
		"visible_cells": visible_cells,
		"hidden_detection_cells": _field_cells(Vector2i(5, 13)),
		"pieces": [
			_piece("fog-lab-red-rook", "red", "rook", Vector2i(5, 13), ["路径视野"]),
			_piece("fog-lab-red-elephant", "red", "elephant", Vector2i(3, 11), ["反隐侦察"]),
			_piece("fog-lab-red-horse", "red", "horse", Vector2i(7, 14), []),
			_piece("fog-lab-black-pawn", "black", "pawn", Vector2i(5, 10), ["已发现"]),
			_piece("fog-lab-black-cannon", "black", "cannon", Vector2i(4, 13), ["已发现"]),
			_piece("fog-lab-black-horse", "black", "horse", Vector2i(6, 14), ["已显形"]),
		],
		"flags": [{
			"capture_progress": 0,
			"capturing_side": "",
			"contested": false,
			"discovered": true,
			"id": "fog-lab-flag-memory",
			"owner": "",
			"position": [8, 16],
		}],
		"walls": [
			{"side": "red", "status": "INTACT"},
			{"side": "black", "status": "BREACHED"},
		],
		"casualties": [
			{"piece_id": "fog-lab-casualty", "side": "black", "piece_type": "pawn"},
		],
		"capture_ghosts": [{
			"piece_id": "fog-lab-ghost",
			"piece_type": "horse",
			"position": [2, 14],
			"side": "red",
		}],
		"vision_overlays": {
			"rook_paths": [{
				"piece_id": "fog-lab-red-rook",
				"cells": [[5, 9], [5, 10], [5, 11], [5, 12], [5, 13], [5, 14], [5, 15]],
			}],
			"elephant_reveal_zones": [{
				"piece_id": "fog-lab-red-elephant",
				"cells": _field_cells(Vector2i(5, 13)),
			}],
			"elephant_block_fields": [{
				"piece_id": "fog-lab-red-elephant",
				"cells": _field_cells(Vector2i(5, 13)),
			}],
		},
		"contact_intel": [],
	}


func _piece(
	piece_id: String,
	side: String,
	piece_type: String,
	cell: Vector2i,
	status_tags: Array[String]
) -> Dictionary:
	return {
		"alive": true,
		"id": piece_id,
		"in_reserve": false,
		"piece_type": piece_type,
		"position": [cell.x, cell.y],
		"side": side,
		"status_tags": status_tags,
	}


func _add_center_vision(result: Dictionary, center: Vector2i) -> void:
	for authority_y: int in range(center.y - 1, center.y + 2):
		for authority_x: int in range(center.x - 1, center.x + 2):
			var cell := Vector2i(authority_x, authority_y)
			if BoardCoordinateMapper.is_authority_cell_valid(cell):
				result[cell] = true


func _field_cells(center: Vector2i) -> Array:
	var cells: Array = []
	for authority_y: int in range(center.y - 1, center.y + 2):
		for authority_x: int in range(center.x - 1, center.x + 2):
			var cell := Vector2i(authority_x, authority_y)
			if BoardCoordinateMapper.is_authority_cell_valid(cell):
				cells.append([cell.x, cell.y])
	return cells


func _board_viewport() -> Control:
	return _match_screen.get_node("MatchHudV2/BoardFrame/BoardViewport") as Control


func _board_world() -> Node2D:
	return _match_screen.get_node(
		"MatchHudV2/BoardFrame/BoardViewport/BoardSubViewport/BoardWorld"
	) as Node2D


func _production_fog() -> Control:
	return _board_world().get_node("FogOverlay") as Control


func _piece_layer() -> Node2D:
	return _board_world().get_node("PieceLayer") as Node2D
