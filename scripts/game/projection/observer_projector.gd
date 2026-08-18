extends RefCounted

const Canonical = preload("res://scripts/game/domain/canonical.gd")
const MatchState = preload("res://scripts/game/domain/match_state.gd")
const VisibilityPolicy = preload("res://scripts/game/domain/visibility_policy.gd")


static func project_player_view(
	state_snapshot: Dictionary,
	viewer_context: RefCounted
) -> Dictionary:
	assert(viewer_context != null and viewer_context.has_method("is_valid"))
	assert(bool(viewer_context.call("is_valid")))
	var side: String = str(viewer_context.call("side"))
	var visibility: Dictionary = VisibilityPolicy.context(state_snapshot, side)
	var visible_cell_set: Dictionary = visibility["visible_cell_set"]
	var pieces: Array = []
	for piece_value: Variant in state_snapshot["pieces"].values():
		var piece: Dictionary = piece_value
		if piece["side"] == side:
			pieces.append(_public_piece(piece, true))
			continue
		if not piece["alive"] or piece["in_reserve"]:
			continue
		var position: Vector2i = Canonical.coordinate(piece["position"])
		var normally_visible: bool = visible_cell_set.has(Canonical.cell_key(position))
		var elephant_revealed: bool = piece["hidden"] \
			and VisibilityPolicy.in_elephant_reveal_zone(state_snapshot, position, side)
		if (normally_visible and VisibilityPolicy.enemy_piece_revealed(
			state_snapshot, piece, side
		)) or elephant_revealed:
			pieces.append(_public_piece(piece, false))
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	return {
		"schema_version": "veilfront-player-view-v1",
		"match_id": str(state_snapshot["match_id"]),
		"rules_revision": str(state_snapshot["rules_revision"]),
		"viewer_side": side,
		"board": {
			"width": int(state_snapshot["board_width"]),
			"height": int(state_snapshot["board_height"]),
		},
		"active_side": str(state_snapshot["active_side"]),
		"action_index": int(state_snapshot["action_index"]),
		"full_round_index": maxi(1, int(state_snapshot["full_round_index"])),
		"round_limit_public": int(
			state_snapshot["configuration"]["full_round_limit_hypothesis"]
		),
		"terminal": bool(state_snapshot["terminal"]),
		"winner": str(state_snapshot["winner"]),
		"win_reason": str(state_snapshot["win_reason"]),
		"visible_cells": visibility["visible_cells"].duplicate(true),
		"hidden_detection_cells": VisibilityPolicy.hidden_detection_cells(
			state_snapshot, side
		),
		"pieces": pieces,
		"flags": _public_flags(state_snapshot, side),
		"walls": _public_walls(state_snapshot),
		"casualties": _public_casualties(state_snapshot),
		"capture_ghosts": _public_capture_ghosts(state_snapshot, side),
		"vision_overlays": _public_vision_overlays(state_snapshot, side),
		"contact_intel": _public_contact_intel(state_snapshot, side),
		"visible_event_cursor": state_snapshot["player_events"][side].size(),
	}


static func _public_piece(piece: Dictionary, owned: bool) -> Dictionary:
	var tags: Array = ["owned"] if owned else ["visible"]
	if owned and piece["hidden"]:
		tags.append("hidden")
	if piece["in_reserve"]:
		tags.append("reserve")
	var result: Dictionary = {
		"id": str(piece["id"]),
		"side": str(piece["side"]),
		"piece_type": str(piece["piece_type"]),
		"position": piece["position"].duplicate(),
		"alive": bool(piece["alive"]),
		"in_reserve": bool(piece["in_reserve"]),
		"status_tags": tags,
	}
	if owned:
		result["bombard_ammo"] = int(piece["bombard_ammo"])
	return result


static func _public_walls(state_snapshot: Dictionary) -> Array:
	var result: Array = []
	for side: String in [MatchState.RED, MatchState.BLACK]:
		result.append({
			"side": side,
			"status": str(state_snapshot["walls"][side]["status"]),
		})
	return result


static func _public_flags(state_snapshot: Dictionary, side: String) -> Array:
	var result: Array = []
	var discoveries: Array = state_snapshot.get("flag_discoveries", {}).get(side, [])
	for flag: Dictionary in state_snapshot["flags"]:
		var discovered: bool = discoveries.has(str(flag["id"]))
		result.append({
			"id": str(flag["id"]),
			"owner": "" if str(flag["owner"]) == MatchState.NEUTRAL else str(flag["owner"]),
			"capturing_side": str(flag["capturing_side"]),
			"capture_progress": int(flag["capture_progress"]),
			"contested": bool(flag["contested"]),
			"discovered": discovered,
			"position": flag["position"].duplicate() if discovered else [],
		})
	return result


static func _public_casualties(state_snapshot: Dictionary) -> Array:
	var result: Array = []
	for side: String in [MatchState.RED, MatchState.BLACK]:
		for piece_id_value: Variant in state_snapshot.get("casualty_pools", {}).get(side, []):
			var piece_id: String = str(piece_id_value)
			if not state_snapshot["pieces"].has(piece_id):
				continue
			var piece: Dictionary = state_snapshot["pieces"][piece_id]
			result.append({
				"piece_id": piece_id,
				"piece_type": str(piece["piece_type"]),
				"side": side,
			})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["piece_id"] < b["piece_id"]
	)
	return result


static func _public_capture_ghosts(state_snapshot: Dictionary, side: String) -> Array:
	var result: Array = []
	for ghost_value: Variant in state_snapshot.get("capture_ghosts", {}).get(side, []):
		var ghost: Dictionary = ghost_value
		if int(ghost.get("expires_at_action_index", -1)) <= int(state_snapshot["action_index"]):
			continue
		result.append({
			"piece_id": str(ghost["piece_id"]),
			"piece_type": str(ghost["piece_type"]),
			"side": str(ghost["side"]),
			"position": ghost["position"].duplicate(),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["piece_id"] < b["piece_id"]
	)
	return result


static func _public_vision_overlays(state_snapshot: Dictionary, side: String) -> Dictionary:
	var sources: Dictionary = state_snapshot.get("vision_sources", {}).get(side, {})
	return {
		"rook_paths": _public_source_records(sources.get("rook_paths", {})),
		"elephant_reveal_zones": _public_source_records(
			sources.get("elephant_reveal_zones", {})
		),
		"elephant_block_fields": _public_source_records(
			sources.get("elephant_block_fields", {})
		),
	}


static func _public_source_records(source_map: Dictionary) -> Array:
	var result: Array = []
	var piece_ids: Array = source_map.keys()
	piece_ids.sort()
	for piece_id_value: Variant in piece_ids:
		var cells: Array = []
		for cell_value: Variant in source_map[piece_id_value]:
			var cell: Vector2i = Canonical.coordinate(cell_value)
			if MatchState.is_inside_board(cell):
				cells.append([cell.x, cell.y])
		cells.sort_custom(_coordinate_less)
		result.append({"piece_id": str(piece_id_value), "cells": cells})
	return result


static func _public_contact_intel(state_snapshot: Dictionary, side: String) -> Array:
	var result: Array = []
	for intel_value: Variant in state_snapshot.get("contact_intel", {}).get(side, []):
		var intel: Dictionary = intel_value
		var cell: Array = intel.get("cell", [])
		if cell.size() != 2:
			continue
		result.append({
			"schema_version": "contact-intel-v1",
			"kind": str(intel.get("kind", "contact")),
			"cell": cell.duplicate(),
			"revealed_identity": str(intel.get("revealed_identity", "")),
			"created_at_action_index": int(intel.get("created_at_action_index", 0)),
			"persistent_tracking": bool(intel.get("persistent_tracking", false)),
		})
	return result


static func _coordinate_less(a: Array, b: Array) -> bool:
	return int(a[1]) < int(b[1]) or (int(a[1]) == int(b[1]) and int(a[0]) < int(b[0]))
