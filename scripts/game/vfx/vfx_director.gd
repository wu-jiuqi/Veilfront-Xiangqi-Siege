class_name VfxDirector
extends Node2D

const CueContract = preload("res://scripts/game/vfx/vfx_cue.gd")
const PositionMapper = preload("res://scripts/game/vfx/vfx_public_position_mapper.gd")

@export var catalog: VfxCatalog
@export var display_side: String = "red"
@export var cell_size: Vector2 = Vector2(128.0, 128.0)
@export_range(1, 160, 1) var max_overdraw_points_standard: int = 100
@export_range(1, 100, 1) var max_overdraw_points_reduced: int = 56
@export_range(16, 1024, 1) var dedup_capacity: int = 256
@export var review_hold: bool = false

@onready var _world_pool: Node2D = $WorldPool
@onready var _global_pool: Node2D = $GlobalCanvas/GlobalAnchor/GlobalPool

var _played_ids: Dictionary = {}
var _played_order: Array[String] = []
var _dropped_count: int = 0


func _ready() -> void:
	for slot: VfxEffectSlot in _all_slots():
		slot.set_review_hold(review_hold)


func play_batch(batch: Dictionary) -> int:
	if not CueContract.is_valid_batch(batch) or catalog == null \
	or not catalog.validation_errors().is_empty():
		return 0
	var played: int = 0
	for cue_value: Variant in batch.get("cues", []):
		if cue_value is Dictionary and play_cue(cue_value):
			played += 1
	return played


func play_cue(cue: Dictionary) -> bool:
	if not CueContract.is_valid(cue) or catalog == null:
		return false
	var cue_id: String = str(cue["cue_id"])
	if _played_ids.has(cue_id):
		return false
	var definition: VfxCueDefinition = catalog.definition_for(str(cue["cue_key"]))
	if definition == null:
		return false
	var pool: Node2D = _global_pool if str(cue["spatial_mode"]) == "global" else _world_pool
	var cost: int = definition.overdraw_points_reduced \
		if str(cue["motion_profile"]) == "reduced" \
		else definition.overdraw_points_standard
	var budget: int = max_overdraw_points_reduced \
		if str(cue["motion_profile"]) == "reduced" \
		else max_overdraw_points_standard
	var slot := _select_slot(pool, cue, definition, cost, budget)
	if slot == null:
		_dropped_count += 1
		return false
	if str(cue["spatial_mode"]) == "board_2d":
		var mapped := PositionMapper.to_local(cue["position_public"], display_side, cell_size)
		if not is_finite(mapped.x) or not is_finite(mapped.y):
			return false
		slot.position = mapped
	else:
		slot.position = get_viewport_rect().size * 0.5
	slot.trigger(cue, definition)
	_remember(cue_id)
	return true


func clear_all() -> void:
	for slot: VfxEffectSlot in _all_slots():
		slot.stop_immediately()
	_played_ids.clear()
	_played_order.clear()
	_dropped_count = 0


func set_display_side(side: String) -> void:
	if side in ["red", "black"]:
		display_side = side


func get_pool_snapshot() -> Dictionary:
	var active: Array = []
	var overdraw_points: int = 0
	for slot: VfxEffectSlot in _all_slots():
		var snapshot := slot.effect_snapshot()
		if bool(snapshot["active"]):
			active.append(snapshot)
			overdraw_points += int(snapshot["overdraw_points"])
	return {
		"world_slot_count": _world_pool.get_child_count(),
		"global_slot_count": _global_pool.get_child_count(),
		"active_count": active.size(),
		"active": active,
		"overdraw_points": overdraw_points,
		"dedup_count": _played_ids.size(),
		"dropped_count": _dropped_count,
		"display_side": display_side,
		"cell_size": cell_size,
	}


func _select_slot(
	pool: Node2D,
	cue: Dictionary,
	definition: VfxCueDefinition,
	cost: int,
	budget: int
) -> VfxEffectSlot:
	var group: String = str(cue["concurrency_group"])
	var group_count: int = 0
	var free_slot: VfxEffectSlot
	var replacement: VfxEffectSlot
	for slot_value: Node in pool.get_children():
		var slot := slot_value as VfxEffectSlot
		if slot == null:
			continue
		if not slot.is_active_effect() and free_slot == null:
			free_slot = slot
		if slot.is_active_effect():
			if slot.concurrency_group() == group:
				group_count += 1
				if replacement == null or slot.priority_rank() < replacement.priority_rank():
					replacement = slot
	var incoming_rank: int = ["low", "normal", "high", "critical"].find(str(cue["priority"]))
	var selected_slot: VfxEffectSlot
	if group_count >= definition.max_instances:
		if str(cue["late_policy"]) == "replace_group" and replacement != null:
			selected_slot = replacement
	else:
		selected_slot = free_slot
		if selected_slot == null and incoming_rank >= 2:
			for slot_value: Node in pool.get_children():
				var slot := slot_value as VfxEffectSlot
				if slot == null or not slot.is_active_effect() \
				or slot.priority_rank() >= incoming_rank:
					continue
				if selected_slot == null \
				or slot.priority_rank() < selected_slot.priority_rank():
					selected_slot = slot
	if selected_slot == null:
		return null
	var projected_cost: int = _current_overdraw_points() \
		- selected_slot.overdraw_points() + cost
	var evictions: Array[VfxEffectSlot] = []
	if projected_cost > budget:
		if incoming_rank < 2:
			return null
		var evictable: Array[VfxEffectSlot] = []
		for slot: VfxEffectSlot in _all_slots():
			if slot != selected_slot and slot.is_active_effect() \
			and slot.priority_rank() < incoming_rank:
				evictable.append(slot)
		evictable.sort_custom(func(a: VfxEffectSlot, b: VfxEffectSlot) -> bool:
			return a.priority_rank() < b.priority_rank()
		)
		for slot: VfxEffectSlot in evictable:
			evictions.append(slot)
			projected_cost -= slot.overdraw_points()
			if projected_cost <= budget:
				break
	if projected_cost > budget:
		return null
	for slot: VfxEffectSlot in evictions:
		slot.stop_immediately()
	if selected_slot.is_active_effect():
		selected_slot.stop_immediately()
	return selected_slot


func _current_overdraw_points() -> int:
	var total: int = 0
	for slot: VfxEffectSlot in _all_slots():
		total += slot.overdraw_points()
	return total


func _all_slots() -> Array[VfxEffectSlot]:
	var slots: Array[VfxEffectSlot] = []
	for parent: Node in [_world_pool, _global_pool]:
		for child: Node in parent.get_children():
			var slot := child as VfxEffectSlot
			if slot != null:
				slots.append(slot)
	return slots


func _remember(cue_id: String) -> void:
	_played_ids[cue_id] = true
	_played_order.append(cue_id)
	while _played_order.size() > dedup_capacity:
		var expired: String = _played_order.pop_front()
		_played_ids.erase(expired)
