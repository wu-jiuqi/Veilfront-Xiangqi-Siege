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
var _catalog_visuals_initialized: bool = false
var _text_layer_visibility: Dictionary = {}
var _catalog_text_values: Dictionary = {}
var _scene_authored_layout_enabled: bool = false


func _ready() -> void:
	_load_layout_definition()


func apply_layout_for_size(requested_size: Vector2, reserved_right: float = 0.0) -> void:
	if _layout_definition.is_empty():
		_load_layout_definition()
	if _layout_definition.is_empty():
		return

	_applied_screen_size = Vector2(maxf(1.0, requested_size.x), maxf(1.0, requested_size.y))
	_reserved_right = clampf(reserved_right, 0.0, maxf(0.0, _applied_screen_size.x - 320.0))
	if _scene_authored_layout_enabled:
		_active_profile_name = "scene-authored"
		_apply_catalog_visuals()
		_apply_catalog_text_layout(false)
		_incense_turn_clock.refresh_layout()
		return
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
	var configured_slots: Dictionary = {}
	for entry_value: Variant in profile.get("ui_layout", []):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var slot_id := str(entry.get("id", ""))
		var slot: Control = slots.get(slot_id) as Control
		if slot == null:
			continue
		configured_slots[slot_id] = true
		_apply_rect(slot, _scaled_rect(entry.get("pixel_rect", {}), scale_factor))
		var slot_visible := bool(entry.get("visible", true))
		if slot == _piece_info_drawer:
			_piece_info_drawer.set_layout_enabled(slot_visible)
		else:
			slot.visible = slot_visible
		slot.z_index = int(entry.get("z_index", 0))
	for ui_id_value: Variant in slots.keys():
		var ui_id := str(ui_id_value)
		if configured_slots.has(ui_id):
			continue
		var disabled_slot: Control = slots.get(ui_id) as Control
		if disabled_slot == null:
			continue
		if disabled_slot == _piece_info_drawer:
			_piece_info_drawer.set_layout_enabled(false)
		else:
			disabled_slot.visible = false

	_apply_catalog_visuals()
	_apply_catalog_text_layout()
	_incense_turn_clock.refresh_layout()


func set_scene_authored_layout_enabled(enabled: bool) -> void:
	_scene_authored_layout_enabled = enabled
	if is_node_ready() and enabled:
		apply_layout_for_size(size, 0.0)


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
		"text_layer_visibility": _text_layer_visibility.duplicate(true),
	}


func is_text_layer_enabled(panel_id: String, layer_id: String) -> bool:
	return bool(_text_layer_visibility.get("%s/%s" % [panel_id, layer_id], false))


func get_catalog_text(panel_id: String, layer_id: String, fallback: String = "") -> String:
	return str(_catalog_text_values.get("%s/%s" % [panel_id, layer_id], fallback))


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
		return
	_index_catalog_text()


func _index_catalog_text() -> void:
	_catalog_text_values.clear()
	for catalog_value: Variant in _layout_definition.get("ui_catalog", []):
		if not catalog_value is Dictionary:
			continue
		var catalog: Dictionary = catalog_value
		var panel_id := str(catalog.get("id", ""))
		for layer_value: Variant in catalog.get("text_layers", []):
			if not layer_value is Dictionary:
				continue
			var layer: Dictionary = layer_value
			_catalog_text_values["%s/%s" % [panel_id, str(layer.get("id", ""))]] = str(
				layer.get("text", "")
			)


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


func _apply_catalog_text_layout(apply_geometry: bool = true) -> void:
	var bindings := {
		"faction-left": {
			"portrait": $FactionLeft/Portrait,
			"name": $FactionLeft/FactionLeftName,
			"turn": $FactionLeft/FactionLeftTurn,
			"stats": $FactionLeft/FactionLeftStats,
			"return": $FactionLeft/ReturnButton,
		},
		"faction-right": {
			"portrait": $FactionRight/Portrait,
			"name": $FactionRight/FactionRightName,
			"turn": $FactionRight/FactionRightTurn,
			"stats": $FactionRight/FactionRightStats,
			"mirror": $FactionRight/MirrorButton,
		},
		"unit-info": {
			"name": $UnitInfo/UnitName,
			"portrait": $UnitInfo/UnitPortrait,
		},
		"objective-events": {
			"heading": $ObjectiveEvents/Heading,
			"selection": $ObjectiveEvents/SelectionStatus,
			"move": $ObjectiveEvents/OwnFlags,
			"bombard": $ObjectiveEvents/OwnCasualties,
			"pass": $ObjectiveEvents/EnemyCasualties,
			"text-1787297730520-1": $ObjectiveEvents/BoardPosition,
			"message": $ObjectiveEvents/MessageValue,
		},
		"minimap": {"title": $Minimap/Title},
		"custom-ui-1787292062912-1": {
			"movement-caption": $PieceInfoDrawer/ContentMargin/ContentRow/TextArea/MovementCaption,
			"movement-summary": $PieceInfoDrawer/ContentMargin/ContentRow/TextArea/MovementSummary,
			"move-button": $PieceInfoDrawer/ContentMargin/ContentRow/SkillButtons/MoveButton,
			"bombard-button": $PieceInfoDrawer/ContentMargin/ContentRow/SkillButtons/BombardButton,
			"resurrect-button": $PieceInfoDrawer/ContentMargin/ContentRow/SkillButtons/ResurrectButton,
			"no-skill-button": $PieceInfoDrawer/ContentMargin/ContentRow/SkillButtons/NoSkillButton,
		},
		"custom-ui-1787293016650-4": {
			"round-number": $IncenseTurnClock/RoundDisplaySlot/NumberFloat/SmokeNumber,
			"round-caption": $IncenseTurnClock/RoundDisplaySlot/NumberFloat/RoundCaption,
		},
	}
	_text_layer_visibility.clear()
	for panel_binding_value: Variant in bindings.values():
		if not panel_binding_value is Dictionary:
			continue
		var panel_binding: Dictionary = panel_binding_value
		for control_value: Variant in panel_binding.values():
			var bound_control := control_value as Control
			if bound_control != null:
				bound_control.visible = false
	# “跳过”已不属于当前 JSON 的目标信息层；保留预置节点和信号，仅按目录决定是否显示。
	$ObjectiveEvents/PassButton.visible = false
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
			var layer_id := str(layer.get("id", ""))
			var control: Control = panel_bindings.get(layer_id) as Control
			if control == null:
				continue
			if apply_geometry and not bool(layer.get("layout_managed_by_container", false)):
				var rect: Dictionary = layer.get("normalized_rect", {})
				control.anchor_left = float(rect.get("x", control.anchor_left))
				control.anchor_top = float(rect.get("y", control.anchor_top))
				control.anchor_right = control.anchor_left + float(rect.get("width", control.anchor_right - control.anchor_left))
				control.anchor_bottom = control.anchor_top + float(rect.get("height", control.anchor_bottom - control.anchor_top))
				control.offset_left = 0.0
				control.offset_top = 0.0
				control.offset_right = 0.0
				control.offset_bottom = 0.0
			control.visible = bool(layer.get("visible", true))
			_text_layer_visibility["%s/%s" % [str(catalog.get("id", "")), layer_id]] = control.visible
			control.add_theme_font_size_override("font_size", int(layer.get("font_size", 12)))
			if control is Label:
				var label := control as Label
				label.horizontal_alignment = _horizontal_alignment(str(layer.get("horizontal_alignment", "left")))
				label.vertical_alignment = _vertical_alignment(str(layer.get("vertical_alignment", "center")))
			elif control is Button:
				(control as Button).alignment = _horizontal_alignment(str(layer.get("horizontal_alignment", "center")))
			if not _catalog_text_initialized:
				if control is Label:
					(control as Label).text = str(layer.get("text", (control as Label).text))
				elif control is Button:
					(control as Button).text = str(layer.get("text", (control as Button).text))
	_catalog_text_initialized = true


func _apply_catalog_visuals() -> void:
	if _catalog_visuals_initialized:
		return
	var backgrounds := {
		"faction-left": $FactionLeft/Background,
		"faction-right": $FactionRight/Background,
		"unit-info": $UnitInfo/Background,
		"objective-events": $ObjectiveEvents/Background,
		"minimap": $Minimap/Frame,
	}
	for catalog_value: Variant in _layout_definition.get("ui_catalog", []):
		if not catalog_value is Dictionary:
			continue
		var catalog: Dictionary = catalog_value
		var background: TextureRect = backgrounds.get(str(catalog.get("id", ""))) as TextureRect
		if background == null:
			continue
		var asset_path := str(catalog.get("asset", ""))
		if not asset_path.is_empty() and ResourceLoader.exists(asset_path):
			var texture := load(asset_path) as Texture2D
			if texture != null:
				background.texture = texture
		background.flip_h = bool(catalog.get("mirror_x", false))
	_catalog_visuals_initialized = true


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
