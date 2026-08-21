class_name MatchHudLayout
extends Control

const DEFAULT_LAYOUT_PATH := "res://resources/game/ui/layouts/veilfront_board_ui_layout_v2.json"

@export_file("*.json") var layout_path: String = DEFAULT_LAYOUT_PATH

@onready var _board_frame: Control = $BoardFrame
@onready var _piece_info_drawer: PieceInfoDrawer = $PieceInfoDrawer
@onready var _incense_turn_clock: IncenseTurnClock = $IncenseTurnClock

var _layout_definition: Dictionary = {}
var _active_profile_name: String = ""
var _applied_screen_size := Vector2.ZERO
var _reserved_right: float = 0.0
var _catalog_text_initialized: bool = false


func _ready() -> void:
	_load_layout_definition()


func apply_layout_for_size(requested_size: Vector2, reserved_right: float = 0.0) -> void:
	if _layout_definition.is_empty():
		_load_layout_definition()
	if _layout_definition.is_empty():
		return

	_applied_screen_size = Vector2(maxf(1.0, requested_size.x), maxf(1.0, requested_size.y))
	_reserved_right = clampf(reserved_right, 0.0, maxf(0.0, _applied_screen_size.x - 320.0))
	var available_size := Vector2(_applied_screen_size.x - _reserved_right, _applied_screen_size.y)
	_active_profile_name = _select_profile_name(available_size)
	var profiles: Dictionary = _layout_definition.get("profiles", {})
	var profile: Dictionary = profiles.get(_active_profile_name, {})
	if profile.is_empty():
		return

	var canvas: Dictionary = profile.get("canvas", {})
	var canvas_size := Vector2(
		maxf(1.0, float(canvas.get("width", 1280.0))),
		maxf(1.0, float(canvas.get("height", 720.0)))
	)
	var scale_factor := Vector2(available_size.x / canvas_size.x, available_size.y / canvas_size.y)
	var board_definition: Dictionary = profile.get("default_visible_board_screen_rect", {})
	_apply_rect(_board_frame, _scaled_rect(board_definition.get("pixel_rect", {}), scale_factor))

	var slots := {
		"faction-left": $FactionLeft,
		"faction-right": $FactionRight,
		"unit-info": $UnitInfo,
		"objective-events": $ObjectiveEvents,
		"minimap": $Minimap,
		"custom-ui-1787265872199-1": $IncenseTurnClock/RoundIncenseSlot,
		"custom-ui-1787292062912-1": $PieceInfoDrawer,
		"custom-ui-1787292347530-2": $IncenseTurnClock/IncenseStandSlot,
		"custom-ui-1787292377548-3": $IncenseTurnClock/TimerIncenseSlot,
		"custom-ui-1787293016650-4": $IncenseTurnClock/RoundDisplaySlot,
	}
	for entry_value: Variant in profile.get("ui_layout", []):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var slot: Control = slots.get(str(entry.get("id", ""))) as Control
		if slot == null:
			continue
		_apply_rect(slot, _scaled_rect(entry.get("pixel_rect", {}), scale_factor))
		if slot != _piece_info_drawer:
			slot.visible = bool(entry.get("visible", true))
		slot.z_index = int(entry.get("z_index", 0))

	_apply_catalog_text_layout()
	_incense_turn_clock.refresh_layout()


func get_layout_snapshot() -> Dictionary:
	return {
		"schema_version": str(_layout_definition.get("schema_version", "")),
		"board_rect_meaning": str(_layout_definition.get("board_rect_meaning", "")),
		"active_profile": _active_profile_name,
		"screen_size": _applied_screen_size,
		"reserved_right": _reserved_right,
		"board_rect": Rect2(_board_frame.position, _board_frame.size),
		"ui_rects": {
			"faction-left": Rect2($FactionLeft.position, $FactionLeft.size),
			"faction-right": Rect2($FactionRight.position, $FactionRight.size),
			"unit-info": Rect2($UnitInfo.position, $UnitInfo.size),
			"objective-events": Rect2($ObjectiveEvents.position, $ObjectiveEvents.size),
			"minimap": Rect2($Minimap.position, $Minimap.size),
			"custom-ui-1787265872199-1": Rect2(
				$IncenseTurnClock/RoundIncenseSlot.position,
				$IncenseTurnClock/RoundIncenseSlot.size
			),
			"custom-ui-1787292062912-1": Rect2($PieceInfoDrawer.position, $PieceInfoDrawer.size),
			"custom-ui-1787292347530-2": Rect2(
				$IncenseTurnClock/IncenseStandSlot.position,
				$IncenseTurnClock/IncenseStandSlot.size
			),
			"custom-ui-1787292377548-3": Rect2(
				$IncenseTurnClock/TimerIncenseSlot.position,
				$IncenseTurnClock/TimerIncenseSlot.size
			),
			"custom-ui-1787293016650-4": Rect2(
				$IncenseTurnClock/RoundDisplaySlot.position,
				$IncenseTurnClock/RoundDisplaySlot.size
			),
		},
	}


func _load_layout_definition() -> void:
	var file := FileAccess.open(layout_path, FileAccess.READ)
	if file == null:
		push_error("MatchHudLayout 无法读取布局 JSON：%s" % layout_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("MatchHudLayout 布局 JSON 格式无效：%s" % layout_path)
		return
	_layout_definition = parsed
	if str(_layout_definition.get("board_rect_meaning", "")) != "default_visible_board_screen_rect":
		push_error("MatchHudLayout 拒绝把非屏幕可视矩形当作棋盘布局。")
		_layout_definition.clear()


func _select_profile_name(available_size: Vector2) -> String:
	var profiles: Dictionary = _layout_definition.get("profiles", {})
	var requested_aspect := available_size.x / maxf(available_size.y, 1.0)
	var best_name := str(_layout_definition.get("active_profile", "1280x720"))
	var best_score := INF
	for profile_name_value: Variant in profiles.keys():
		var profile_name := str(profile_name_value)
		var profile: Dictionary = profiles.get(profile_name, {})
		var canvas: Dictionary = profile.get("canvas", {})
		var canvas_width := maxf(1.0, float(canvas.get("width", 1280.0)))
		var canvas_height := maxf(1.0, float(canvas.get("height", 720.0)))
		var aspect_delta := absf(requested_aspect - canvas_width / canvas_height)
		var height_delta := absf(available_size.y - canvas_height) / canvas_height
		var score := aspect_delta * 100.0 + height_delta * 0.01
		if score < best_score:
			best_score = score
			best_name = profile_name
	return best_name


func _scaled_rect(rect_definition: Dictionary, scale_factor: Vector2) -> Rect2:
	return Rect2(
		float(rect_definition.get("x", 0.0)) * scale_factor.x,
		float(rect_definition.get("y", 0.0)) * scale_factor.y,
		float(rect_definition.get("width", 0.0)) * scale_factor.x,
		float(rect_definition.get("height", 0.0)) * scale_factor.y
	)


func _apply_rect(control: Control, target_rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = target_rect.position
	control.size = target_rect.size


func _apply_catalog_text_layout() -> void:
	var bindings := {
		"faction-left": {
			"portrait": $FactionLeft/Portrait,
			"name": $FactionLeft/FactionLeftName,
			"stats": $FactionLeft/FactionLeftStats,
		},
		"faction-right": {
			"portrait": $FactionRight/Portrait,
			"name": $FactionRight/FactionRightName,
			"stats": $FactionRight/FactionRightStats,
		},
		"unit-info": {
			"name": $UnitInfo/UnitName,
			"glyph": $UnitInfo/UnitPortraitGlyph,
			"side": $UnitInfo/UnitSideStatus,
			"position": $UnitInfo/UnitPosition,
			"state": $UnitInfo/UnitState,
		},
		"objective-events": {
			"heading": $ObjectiveEvents/Heading,
			"selection": $ObjectiveEvents/SelectionStatus,
			"move": $ObjectiveEvents/OwnFlags,
			"bombard": $ObjectiveEvents/OwnCasualties,
			"pass": $ObjectiveEvents/EnemyCasualties,
		},
		"minimap": {"title": $Minimap/Title},
	}
	for catalog_value: Variant in _layout_definition.get("ui_catalog", []):
		if not catalog_value is Dictionary:
			continue
		var catalog: Dictionary = catalog_value
		var panel_bindings: Dictionary = bindings.get(str(catalog.get("id", "")), {})
		var text_layers: Variant = catalog.get("text_layers", [])
		if not text_layers is Array:
			continue
		for layer_value: Variant in text_layers:
			if not layer_value is Dictionary:
				continue
			var layer: Dictionary = layer_value
			var label: Label = panel_bindings.get(str(layer.get("id", ""))) as Label
			if label == null:
				continue
			var rect: Dictionary = layer.get("normalized_rect", {})
			label.anchor_left = float(rect.get("x", label.anchor_left))
			label.anchor_top = float(rect.get("y", label.anchor_top))
			label.anchor_right = label.anchor_left + float(rect.get("width", label.anchor_right - label.anchor_left))
			label.anchor_bottom = label.anchor_top + float(rect.get("height", label.anchor_bottom - label.anchor_top))
			label.offset_left = 0.0
			label.offset_top = 0.0
			label.offset_right = 0.0
			label.offset_bottom = 0.0
			label.visible = bool(layer.get("visible", true))
			label.add_theme_font_size_override("font_size", int(layer.get("font_size", 12)))
			label.horizontal_alignment = _horizontal_alignment(str(layer.get("horizontal_alignment", "left")))
			label.vertical_alignment = _vertical_alignment(str(layer.get("vertical_alignment", "center")))
			if not _catalog_text_initialized:
				label.text = str(layer.get("text", label.text))
	_catalog_text_initialized = true


func _horizontal_alignment(value: String) -> HorizontalAlignment:
	match value:
		"center":
			return HORIZONTAL_ALIGNMENT_CENTER
		"right":
			return HORIZONTAL_ALIGNMENT_RIGHT
		_:
			return HORIZONTAL_ALIGNMENT_LEFT


func _vertical_alignment(value: String) -> VerticalAlignment:
	match value:
		"top":
			return VERTICAL_ALIGNMENT_TOP
		"bottom":
			return VERTICAL_ALIGNMENT_BOTTOM
		_:
			return VERTICAL_ALIGNMENT_CENTER
