class_name PieceInfoDrawer
extends Control

const OPEN_SECONDS: float = 0.24
const CLOSE_SECONDS: float = 0.16

const MOVE_DESCRIPTIONS := {
	"general": "将帅：仅在九宫内横直移动一格。",
	"advisor": "士：仅在九宫内斜行一格；满足条件时可献祭复活阵亡棋子。",
	"elephant": "象：沿对角移动两格；象眼受阻时不可通过，并展开侦察区域。",
	"horse": "马：按日字移动；未触发特殊规则时会受蹩马腿阻挡。",
	"rook": "车：沿横线或纵线直行；路径通常不可穿越棋子。",
	"cannon": "炮：沿横线或纵线移动；隔一枚棋子可吃子，并可选择区域轰炸。",
	"pawn": "兵：通常向前一格或横移一格；特殊区域内可直线突进。",
}

@onready var movement_summary: Label = %MovementSummary
@onready var move_button: Button = %MoveButton
@onready var bombard_button: Button = %BombardButton
@onready var resurrect_button: Button = %ResurrectButton

var reduced_motion: bool = false
var _visibility_tween: Tween
var _piece_id: String = ""
var _layout_enabled: bool = true


func _ready() -> void:
	visible = false
	scale = Vector2(0.02, 1.0)
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_update_pivot)
	_update_pivot()


func show_piece(piece: Dictionary, can_submit: bool, animate: bool = true) -> void:
	if not _layout_enabled:
		return
	var piece_type := str(piece.get("piece_type", ""))
	var next_piece_id := str(piece.get("id", ""))
	movement_summary.text = str(MOVE_DESCRIPTIONS.get(piece_type, "该棋子的移动逻辑尚未登记。"))
	move_button.disabled = not can_submit
	bombard_button.visible = piece_type == "cannon"
	bombard_button.disabled = not can_submit
	resurrect_button.visible = piece_type == "advisor"
	resurrect_button.disabled = not can_submit
	if visible and next_piece_id == _piece_id:
		return
	_piece_id = next_piece_id
	_kill_visibility_tween()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if reduced_motion or not animate:
		scale = Vector2.ONE
		modulate.a = 1.0
		return
	scale = Vector2(0.02, 1.0)
	modulate.a = 0.0
	_visibility_tween = create_tween().set_parallel(true)
	_visibility_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_visibility_tween.tween_property(self, "scale:x", 1.0, OPEN_SECONDS)
	_visibility_tween.tween_property(self, "modulate:a", 1.0, OPEN_SECONDS * 0.72)


func hide_drawer(animate: bool = true) -> void:
	if not visible:
		return
	_kill_visibility_tween()
	_piece_id = ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if reduced_motion or not animate:
		visible = false
		scale = Vector2(0.02, 1.0)
		modulate.a = 0.0
		return
	_visibility_tween = create_tween().set_parallel(true)
	_visibility_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_visibility_tween.tween_property(self, "scale:x", 0.02, CLOSE_SECONDS)
	_visibility_tween.tween_property(self, "modulate:a", 0.0, CLOSE_SECONDS)
	_visibility_tween.chain().tween_callback(func() -> void: visible = false)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled


func set_layout_enabled(enabled: bool) -> void:
	_layout_enabled = enabled
	if not _layout_enabled:
		hide_drawer(false)


func get_state_snapshot() -> Dictionary:
	return {
		"layout_enabled": _layout_enabled,
		"visible": visible,
		"movement_summary": movement_summary.text,
		"move_visible": move_button.visible,
		"bombard_visible": bombard_button.visible,
		"resurrect_visible": resurrect_button.visible,
	}


func _update_pivot() -> void:
	pivot_offset = Vector2(0.0, size.y * 0.5)


func _kill_visibility_tween() -> void:
	if _visibility_tween != null and _visibility_tween.is_valid():
		_visibility_tween.kill()
	_visibility_tween = null
