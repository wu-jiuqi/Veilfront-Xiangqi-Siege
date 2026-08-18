extends RefCounted

const ProtoCanonical = preload("res://scripts/prototype/core/canonical.gd")
const ProtoMatchState = preload("res://scripts/prototype/core/match_state.gd")
const ProtoProjector = preload("res://scripts/prototype/view/player_view_projector.gd")


static func full_state(state: Dictionary, seed_value: int) -> Dictionary:
	var mapped: Dictionary = state.duplicate(true)
	mapped["schema_version"] = "veilfront-full-state-v1"
	mapped["match_id"] = "match-%d" % seed_value
	mapped["implementation_revision"] = "formal-core-revision-1"
	for event: Dictionary in mapped.get("events", []):
		event["schema_version"] = "veilfront-domain-event-v1"
	return mapped


static func player_view(state: Dictionary, side: String, seed_value: int) -> Dictionary:
	var source: Dictionary = ProtoProjector.project(state, side)
	var contact: Array = []
	for intel_value: Variant in source.get("contact_intel", []):
		var intel: Dictionary = intel_value
		if intel.get("cell", []).size() == 2:
			contact.append(intel.duplicate(true))
	var flags: Array = source["flags"].duplicate(true)
	for flag: Dictionary in flags:
		if str(flag.get("owner", "")) == ProtoMatchState.NEUTRAL:
			flag["owner"] = ""
	return {
		"schema_version": "veilfront-player-view-v1",
		"match_id": "match-%d" % seed_value,
		"rules_revision": str(source["rules_revision"]),
		"viewer_side": side,
		"board": {"width": int(source["board_width"]), "height": int(source["board_height"])},
		"active_side": str(source["active_side"]),
		"action_index": int(source["action_index"]),
		"full_round_index": maxi(1, int(source["full_round_index"])),
		"round_limit_public": int(source["full_round_limit_hypothesis"]),
		"terminal": bool(source["terminal"]),
		"winner": str(source["winner"]),
		"win_reason": str(source["win_reason"]),
		"visible_cells": source["visible_cells"].duplicate(true),
		"hidden_detection_cells": source["hidden_detection_cells"].duplicate(true),
		"pieces": source["pieces"].duplicate(true),
		"flags": flags,
		"walls": source["walls"].duplicate(true),
		"casualties": source["casualties"].duplicate(true),
		"capture_ghosts": source["capture_ghosts"].duplicate(true),
		"vision_overlays": source["vision_overlays"].duplicate(true),
		"contact_intel": contact,
		"visible_event_cursor": source.get("player_events", []).size(),
	}


static func visible_events(state: Dictionary, side: String) -> Array:
	var result: Array = []
	var source_events: Array = state.get("player_events", {}).get(side, [])
	for index: int in source_events.size():
		var source: Dictionary = source_events[index]
		var event_type: String = str(source.get("event_type", "event.public"))
		var position: Array = source.get("position", []).duplicate()
		if position.size() != 2:
			position = []
		var payload: Dictionary = {}
		if event_type == "flag.capture_progress":
			payload = {
				"capturing_side": str(source.get("capturing_side", source.get("actor_side", ""))),
				"progress": int(source.get("progress", 1)),
			}
		result.append({
			"schema_version": "veilfront-visible-event-v1",
			"visible_sequence": index + 1,
			"action_index": _event_action_index(source, index),
			"event_type": event_type,
			"actor_side_public": str(source.get("actor_side", "")),
			"position_public": position,
			"piece_public": {},
			"message_key": "event.%s" % event_type,
			"public_payload": payload,
			"timing_bucket": "standard",
		})
	return result


static func action_preview(player_view: Dictionary, intent: Dictionary) -> Dictionary:
	var source: Dictionary = ProtoProjector.preview_intent(player_view, intent)
	var public_code: String = str(source.get("error", {}).get("code", ""))
	var action_type: String = str(source.get("action_type", ""))
	return {
		"schema_version": "veilfront-action-preview-v1",
		"preview_id": str(source.get("id", "")),
		"piece_id": str(source.get("piece_id", "")),
		"action_type": action_type,
		"target_cell": source.get("target_cell", []).duplicate(),
		"skill_type": str(source.get("skill_type", "")),
		"classification": str(source.get("classification", "KNOWN_ILLEGAL")),
		"confirmation_required": action_type in ["move", "bombard", "resurrect"],
		"public_cost": {},
		"message_key": "action.%s" % (public_code if not public_code.is_empty() else action_type),
	}


static func replay_checkpoint(
	intents: Array,
	state_digest: String,
	event_digest: String
) -> Dictionary:
	return {
		"intent_prefix_digest": ProtoCanonical.digest(intents),
		"state_digest": state_digest,
		"event_digest": event_digest,
	}


static func _event_action_index(source: Dictionary, fallback: int) -> int:
	var parts: PackedStringArray = str(source.get("id", "")).split("-")
	if parts.size() >= 3 and parts[2].is_valid_int():
		return int(parts[2])
	return fallback
