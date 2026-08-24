extends Node2D

const CueContract = preload("res://scripts/game/vfx/vfx_cue.gd")

@onready var _vfx: VfxDirector = $BoardPreview/BoardViewport/VfxRoot


func _ready() -> void:
	queue_redraw()
	call_deferred("_play_review_set")


func get_review_snapshot() -> Dictionary:
	return _vfx.get_pool_snapshot()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("111820"))
	draw_rect(Rect2(Vector2(44.0, 72.0), Vector2(452.0, 592.0)), Color("1b2529"), true)
	draw_rect(Rect2(Vector2(44.0, 72.0), Vector2(452.0, 592.0)), Color("b99456"), false, 2.0)
	for x: int in 10:
		var px := 68.0 + float(x) * 48.0
		draw_line(Vector2(px, 84.0), Vector2(px, 660.0), Color(0.55, 0.48, 0.34, 0.28), 1.0)
	for y: int in 25:
		var py := 84.0 + float(y) * 24.0
		draw_line(Vector2(68.0, py), Vector2(500.0, py), Color(0.55, 0.48, 0.34, 0.28), 1.0)
	draw_rect(Rect2(Vector2(528.0, 72.0), Vector2(708.0, 592.0)), Color("171e26"), true)
	draw_rect(Rect2(Vector2(528.0, 72.0), Vector2(708.0, 592.0)), Color("536f69"), false, 2.0)


func _play_review_set() -> void:
	var specs: Array[Dictionary] = [
		{"key": "vfx.selection.focus", "position": [2, 5], "priority": "normal", "group": "selection", "late": "replace_group", "side": "red"},
		{"key": "vfx.move.step", "position": [7, 7], "priority": "normal", "group": "move", "late": "drop_if_late", "side": "black"},
		{"key": "vfx.capture.impact", "position": [3, 11], "priority": "high", "group": "capture", "late": "play_once", "side": "red"},
		{"key": "vfx.bombardment.resolve", "position": [7, 14], "priority": "high", "group": "bombardment", "late": "play_once", "side": "black"},
		{"key": "vfx.wall.breached", "position": [5, 21], "priority": "high", "group": "wall", "late": "replace_group", "side": "black"},
		{"key": "vfx.flag.captured", "position": [3, 18], "priority": "high", "group": "flag", "late": "replace_group", "side": "red"},
		{"key": "vfx.terminal.victory", "position": [], "priority": "critical", "group": "terminal", "late": "play_once", "side": "red"},
	]
	var cues: Array = []
	for index: int in specs.size():
		var spec: Dictionary = specs[index]
		cues.append(CueContract.build(
			"vfx-review", 7, str(spec["key"]),
			"local_interaction" if index == 0 else "view_diff",
			7, 0,
			"global" if spec["position"].is_empty() else "board_2d",
			spec["position"], str(spec["priority"]), str(spec["group"]),
			str(spec["late"]), str(spec["side"]), "standard", "review-%d" % index
		))
	var batch := CueContract.build_batch("vfx-review", 7, 7, "standard", cues)
	_vfx.play_batch(batch)
