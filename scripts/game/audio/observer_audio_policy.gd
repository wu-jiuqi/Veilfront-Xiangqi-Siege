class_name ObserverAudioPolicy
extends RefCounted

const CUE_SCHEMA: String = "veilfront-audio-cue-v1"
const BATCH_SCHEMA: String = "veilfront-audio-cue-batch-v1"
const VALID_ERRORS: Array[String] = [
	"known_illegal", "intent_unresolved", "stale_intent", "invalid_request",
]


static func project_frame(
	previous_view: Dictionary,
	current_view: Dictionary,
	visible_events: Array,
	visible_error: Dictionary = {}
) -> Dictionary:
	if not _is_observer_view(current_view):
		return {}
	var action_index: int = int(current_view.get("action_index", -1))
	var cursor: int = int(current_view.get("visible_event_cursor", -1))
	if action_index < 0 or cursor < 0:
		return {}
	var session_public_id: String = str(current_view.get("match_id", ""))
	if session_public_id.is_empty():
		return {}
	var drafts: Array[Dictionary] = []
	if previous_view.is_empty():
		if bool(current_view.get("terminal", false)):
			drafts.append(_terminal_draft(current_view))
		return _finalize_batch(session_public_id, action_index, cursor, drafts)
	if not _is_coherent_transition(previous_view, current_view):
		return {}

	_append_visible_error(drafts, visible_error, action_index)
	_append_event_subjects(drafts, visible_events, previous_view, current_view)
	_append_piece_and_casualty_changes(drafts, previous_view, current_view)
	_append_public_state_changes(drafts, previous_view, current_view)
	_append_turn_and_terminal(drafts, previous_view, current_view)
	return _finalize_batch(session_public_id, action_index, cursor, drafts)


static func project_visible_error(current_view: Dictionary, visible_error: Dictionary) -> Dictionary:
	if not _is_observer_view(current_view) or visible_error.is_empty():
		return {}
	var drafts: Array[Dictionary] = []
	var action_index: int = int(current_view.get("action_index", -1))
	_append_visible_error(drafts, visible_error, action_index)
	return _finalize_batch(
		str(current_view.get("match_id", "")),
		action_index,
		int(current_view.get("visible_event_cursor", 0)),
		drafts
	)


static func local_cue(
	session_public_id: String,
	action_index: int,
	sequence: int,
	cue_key: String,
	position_public: Array = []
) -> Dictionary:
	var mode: String = "board_2d" if _is_public_position(position_public) else "global"
	var cue: Dictionary = _draft(
		cue_key,
		"local_interaction",
		maxi(-1, action_index),
		mode,
		position_public,
		_priority_for(cue_key),
		_group_for(cue_key),
		"drop_if_late"
	)
	cue["occurrence_index"] = 0
	cue["cue_id"] = "%s:local:%d:%s" % [session_public_id, sequence, cue_key]
	return cue


static func _append_visible_error(
	drafts: Array[Dictionary], visible_error: Dictionary, action_index: int
) -> void:
	if visible_error.is_empty():
		return
	if str(visible_error.get("public_code", "")) not in VALID_ERRORS:
		return
	if int(visible_error.get("action_index", -1)) != action_index:
		return
	var rejection: Dictionary = _draft(
		"sfx.ui.reject", "visible_error", action_index, "global", [],
		"normal", "ui_action", "drop_if_late"
	)
	# Rejections do not advance action_index, so the public intent id is required
	# to distinguish separate attempts without exposing their public_code.
	rejection["_identity_token"] = str(visible_error.get("intent_id", ""))
	drafts.append(rejection)


static func _append_event_subjects(
	drafts: Array[Dictionary],
	visible_events: Array,
	previous_view: Dictionary,
	current_view: Dictionary
) -> void:
	var previous_cursor: int = int(previous_view.get("visible_event_cursor", 0))
	var current_cursor: int = int(current_view.get("visible_event_cursor", 0))
	var accepted_events: Array[Dictionary] = []
	for event_value: Variant in visible_events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var sequence: int = int(event.get("visible_sequence", -1))
		if sequence <= previous_cursor or sequence > current_cursor:
			continue
		accepted_events.append(event)
	accepted_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("visible_sequence", 0)) < int(b.get("visible_sequence", 0))
	)
	for event: Dictionary in accepted_events:
		var event_type: String = str(event.get("event_type", ""))
		var event_action: int = int(event.get("action_index", current_view.get("action_index", 0)))
		match event_type:
			"pass", "skip":
				drafts.append(_draft(
					"sfx.action.pass", "visible_event", event_action, "global", [],
					"normal", "board_move", "drop_if_late"
				))
			"timeout":
				drafts.append(_draft(
					"sfx.turn.timeout", "visible_event", event_action, "global", [],
					"high", "turn", "play_once"
				))
			"bombardment_resolved":
				# The layer count is intentionally fixed. Hidden impact and casualty truth
				# never changes this two-cue public skeleton.
				drafts.append(_draft(
					"sfx.bombard.launch", "visible_event", event_action, "global", [],
					"high", "bombard", "play_once"
				))
				drafts.append(_draft(
					"sfx.bombard.impact_bed", "visible_event", event_action, "global", [],
					"high", "bombard", "play_once"
				))
			"advisor_resurrection_resolved":
				drafts.append(_draft(
					"sfx.advisor.sacrifice", "visible_event", event_action, "global", [],
					"high", "advisor", "play_once"
				))
				drafts.append(_draft(
					"sfx.advisor.resurrect", "visible_event", event_action, "global", [],
					"high", "advisor", "play_once"
				))


static func _append_piece_and_casualty_changes(
	drafts: Array[Dictionary], previous_view: Dictionary, current_view: Dictionary
) -> void:
	var action_index: int = int(current_view.get("action_index", 0))
	var previous_pieces: Dictionary = _records_by_id(previous_view.get("pieces", []), "id")
	var current_pieces: Dictionary = _records_by_id(current_view.get("pieces", []), "id")
	var viewer_side: String = str(current_view.get("viewer_side", ""))
	var piece_ids: Array = current_pieces.keys()
	piece_ids.sort()
	for piece_id_value: Variant in piece_ids:
		var piece_id: String = str(piece_id_value)
		var current_piece: Dictionary = current_pieces[piece_id]
		if not previous_pieces.has(piece_id):
			if str(current_piece.get("side", "")) != viewer_side \
			and bool(current_piece.get("alive", false)) \
			and _is_public_position(current_piece.get("position", [])):
				drafts.append(_draft(
					"sfx.reveal.piece", "view_diff", action_index, "board_2d",
					current_piece.get("position", []).duplicate(), "normal", "reveal", "drop_if_late"
				))
			continue
		var previous_piece: Dictionary = previous_pieces[piece_id]
		if not bool(current_piece.get("alive", false)) \
		or bool(current_piece.get("in_reserve", false)):
			continue
		var current_position: Array = current_piece.get("position", [])
		if current_position == previous_piece.get("position", []) \
		or not _is_public_position(current_position):
			continue
		var cue_key: String = _move_key(str(current_piece.get("piece_type", "")))
		drafts.append(_draft(
			cue_key, "view_diff", action_index, "board_2d", current_position.duplicate(),
			"normal", "board_move", "drop_if_late"
		))

	var previous_casualties: Dictionary = _records_by_id(
		previous_view.get("casualties", []), "piece_id"
	)
	var current_casualties: Dictionary = _records_by_id(
		current_view.get("casualties", []), "piece_id"
	)
	var ghosts: Dictionary = _records_by_id(current_view.get("capture_ghosts", []), "piece_id")
	var casualty_ids: Array = current_casualties.keys()
	casualty_ids.sort()
	for casualty_id_value: Variant in casualty_ids:
		var casualty_id: String = str(casualty_id_value)
		if previous_casualties.has(casualty_id):
			continue
		var casualty: Dictionary = current_casualties[casualty_id]
		var position: Array = []
		if ghosts.has(casualty_id):
			position = ghosts[casualty_id].get("position", []).duplicate()
		if _is_public_position(position):
			drafts.append(_draft(
				"sfx.capture.impact", "view_diff", action_index, "board_2d", position,
				"high", "impact", "play_once"
			))
		else:
			drafts.append(_draft(
				"sfx.casualty.public", "view_diff", action_index, "global", [],
				"normal", "impact", "play_once"
			))
		if str(casualty.get("piece_type", "")) in ["general", "king"]:
			drafts.append(_draft(
				"sfx.general.destroyed", "view_diff", action_index, "global", [],
				"critical", "general", "play_once"
			))


static func _append_public_state_changes(
	drafts: Array[Dictionary], previous_view: Dictionary, current_view: Dictionary
) -> void:
	var action_index: int = int(current_view.get("action_index", 0))
	var previous_visible: Dictionary = _coordinate_set(previous_view.get("visible_cells", []))
	var added_visible: bool = false
	for cell_value: Variant in current_view.get("visible_cells", []):
		if _is_public_position(cell_value) and not previous_visible.has(_coordinate_key(cell_value)):
			added_visible = true
			break
	if added_visible:
		drafts.append(_draft(
			"sfx.fog.reveal", "view_diff", action_index, "global", [],
			"low", "reveal", "drop_if_late"
		))

	var previous_contacts: Dictionary = _contact_set(previous_view.get("contact_intel", []))
	for contact_value: Variant in current_view.get("contact_intel", []):
		if not contact_value is Dictionary:
			continue
		var contact: Dictionary = contact_value
		if previous_contacts.has(_contact_key(contact)):
			continue
		# Unknown contacts are deliberately non-positional even though the safe DTO
		# may contain a cell. This prevents sound from becoming an extra locator.
		drafts.append(_draft(
			"sfx.contact.unknown", "view_diff", action_index, "global", [],
			"normal", "contact", "play_once"
		))

	var previous_overlays: Dictionary = previous_view.get("vision_overlays", {})
	var current_overlays: Dictionary = current_view.get("vision_overlays", {})
	if previous_overlays.get("elephant_reveal_zones", []) \
	!= current_overlays.get("elephant_reveal_zones", []) \
	or previous_overlays.get("elephant_block_fields", []) \
	!= current_overlays.get("elephant_block_fields", []):
		drafts.append(_draft(
			"sfx.special.elephant_field", "view_diff", action_index, "global", [],
			"normal", "reveal", "drop_if_late"
		))

	_append_wall_changes(drafts, previous_view, current_view)
	_append_flag_changes(drafts, previous_view, current_view)


static func _append_wall_changes(
	drafts: Array[Dictionary], previous_view: Dictionary, current_view: Dictionary
) -> void:
	var action_index: int = int(current_view.get("action_index", 0))
	var previous_walls: Dictionary = _records_by_id(previous_view.get("walls", []), "side")
	var current_walls: Dictionary = _records_by_id(current_view.get("walls", []), "side")
	var sides: Array = current_walls.keys()
	sides.sort()
	for side_value: Variant in sides:
		var side: String = str(side_value)
		if not previous_walls.has(side):
			continue
		var before: String = str(previous_walls[side].get("status", ""))
		var after: String = str(current_walls[side].get("status", ""))
		var key: String = ""
		if before == "INTACT" and after == "BREACHED":
			key = "sfx.wall.breached"
		elif before == "BREACHED" and after == "REPAIRING":
			key = "sfx.wall.repairing"
		elif before == "REPAIRING" and after == "INTACT":
			key = "sfx.wall.repaired"
		if not key.is_empty():
			drafts.append(_draft(
				key, "view_diff", action_index, "global", [],
				"high", "wall_flag", "play_once"
			))


static func _append_flag_changes(
	drafts: Array[Dictionary], previous_view: Dictionary, current_view: Dictionary
) -> void:
	var action_index: int = int(current_view.get("action_index", 0))
	var previous_flags: Dictionary = _records_by_id(previous_view.get("flags", []), "id")
	var current_flags: Dictionary = _records_by_id(current_view.get("flags", []), "id")
	var flag_ids: Array = current_flags.keys()
	flag_ids.sort()
	for flag_id_value: Variant in flag_ids:
		var flag_id: String = str(flag_id_value)
		if not previous_flags.has(flag_id):
			continue
		var before: Dictionary = previous_flags[flag_id]
		var after: Dictionary = current_flags[flag_id]
		var position: Array = after.get("position", []).duplicate()
		var mode: String = "board_2d" if bool(after.get("discovered", false)) \
		and _is_public_position(position) else "global"
		if mode == "global":
			position = []
		if not bool(before.get("discovered", false)) and bool(after.get("discovered", false)):
			drafts.append(_draft(
				"sfx.flag.discovered", "view_diff", action_index, mode, position,
				"high", "wall_flag", "play_once"
			))
		var old_progress: int = int(before.get("capture_progress", 0))
		var new_progress: int = int(after.get("capture_progress", 0))
		var owner_changed: bool = str(before.get("owner", "")) \
			!= str(after.get("owner", "")) and not str(after.get("owner", "")).is_empty()
		# Completion supersedes the lower-value progress tick so the two-slot
		# wall/flag concurrency group remains readable.
		if owner_changed:
			drafts.append(_draft(
				"sfx.flag.captured", "view_diff", action_index, mode, position,
				"high", "wall_flag", "play_once"
			))
		elif new_progress > old_progress:
			drafts.append(_draft(
				"sfx.flag.capture_progress", "view_diff", action_index, mode, position,
				"normal", "wall_flag", "play_once"
			))
		elif old_progress > 0 and new_progress == 0:
			drafts.append(_draft(
				"sfx.flag.capture_cancelled", "view_diff", action_index, mode, position,
				"normal", "wall_flag", "play_once"
			))


static func _append_turn_and_terminal(
	drafts: Array[Dictionary], previous_view: Dictionary, current_view: Dictionary
) -> void:
	var action_index: int = int(current_view.get("action_index", 0))
	if str(previous_view.get("active_side", "")) != str(current_view.get("active_side", "")) \
	and str(current_view.get("active_side", "")) == str(current_view.get("viewer_side", "")) \
	and not bool(current_view.get("terminal", false)):
		drafts.append(_draft(
			"sfx.turn.local_start", "view_diff", action_index, "global", [],
			"high", "turn", "play_once"
		))
	if not bool(previous_view.get("terminal", false)) and bool(current_view.get("terminal", false)):
		drafts.append(_terminal_draft(current_view))


static func _terminal_draft(view: Dictionary) -> Dictionary:
	var winner: String = str(view.get("winner", ""))
	var viewer: String = str(view.get("viewer_side", ""))
	var cue_key: String = "sfx.match.draw"
	if winner in ["red", "black"]:
		cue_key = "sfx.match.victory" if winner == viewer else "sfx.match.defeat"
	return _draft(
		cue_key, "view_diff", int(view.get("action_index", 0)), "global", [],
		"critical", "terminal", "play_once"
	)


static func _finalize_batch(
	session_public_id: String,
	action_index: int,
	cursor: int,
	drafts: Array[Dictionary]
) -> Dictionary:
	var counts: Dictionary = {}
	var cues: Array[Dictionary] = []
	for draft: Dictionary in drafts:
		var key: String = str(draft.get("cue_key", ""))
		var occurrence: int = int(counts.get(key, 0))
		counts[key] = occurrence + 1
		var cue: Dictionary = draft.duplicate(true)
		var identity_token: String = str(cue.get("_identity_token", ""))
		cue.erase("_identity_token")
		cue["occurrence_index"] = occurrence
		cue["cue_id"] = "%s:%d:%s:%d%s" % [
			session_public_id,
			action_index,
			key,
			occurrence,
			(":" + identity_token.sha256_text().substr(0, 12)) if not identity_token.is_empty() else "",
		]
		cues.append(cue)
	var batch: Dictionary = {
		"schema_version": BATCH_SCHEMA,
		"session_public_id": session_public_id,
		"frame_action_index": action_index,
		"visible_event_cursor": cursor,
		"cues": cues,
	}
	batch["batch_digest"] = JSON.stringify(batch, "", true, true).sha256_text()
	return batch


static func _draft(
	cue_key: String,
	source_kind: String,
	action_index: int,
	spatial_mode: String,
	position_public: Array,
	priority: String,
	concurrency_group: String,
	late_policy: String
) -> Dictionary:
	return {
		"schema_version": CUE_SCHEMA,
		"cue_id": "",
		"cue_key": cue_key,
		"source_kind": source_kind,
		"action_index": action_index,
		"occurrence_index": 0,
		"spatial_mode": spatial_mode,
		"position_public": position_public.duplicate(),
		"priority": priority,
		"concurrency_group": concurrency_group,
		"late_policy": late_policy,
	}


static func _move_key(piece_type: String) -> String:
	if piece_type in ["cavalry", "horse"]:
		return "sfx.move.cavalry"
	if piece_type in ["chariot", "rook"]:
		return "sfx.move.chariot"
	if piece_type in ["trebuchet", "cannon"]:
		return "sfx.move.cannon"
	return "sfx.move.foot"


static func _priority_for(cue_key: String) -> String:
	if cue_key in ["sfx.match.victory", "sfx.match.defeat", "sfx.match.draw"]:
		return "critical"
	if cue_key in ["sfx.ui.confirm", "sfx.bombard.launch", "sfx.wall.breached"]:
		return "high"
	return "normal"


static func _group_for(cue_key: String) -> String:
	if cue_key.begins_with("sfx.ui."):
		return "ui_action"
	if cue_key.begins_with("sfx.board.") or cue_key.begins_with("sfx.move."):
		return "board_move"
	if cue_key.begins_with("sfx.marker."):
		return "marker"
	return "system"


static func _is_observer_view(view: Dictionary) -> bool:
	return str(view.get("schema_version", "")) == "veilfront-player-view-v1" \
		and str(view.get("viewer_side", "")) in ["red", "black"] \
		and not str(view.get("match_id", "")).is_empty()


static func _is_coherent_transition(previous_view: Dictionary, current_view: Dictionary) -> bool:
	return _is_observer_view(previous_view) \
		and str(previous_view.get("match_id", "")) == str(current_view.get("match_id", "")) \
		and str(previous_view.get("viewer_side", "")) == str(current_view.get("viewer_side", "")) \
		and int(current_view.get("action_index", -1)) >= int(previous_view.get("action_index", -1)) \
		and int(current_view.get("visible_event_cursor", -1)) \
		>= int(previous_view.get("visible_event_cursor", -1))


static func _records_by_id(records_value: Variant, id_field: String) -> Dictionary:
	var result: Dictionary = {}
	if not records_value is Array:
		return result
	for record_value: Variant in records_value:
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		var identifier: String = str(record.get(id_field, ""))
		if not identifier.is_empty():
			result[identifier] = record
	return result


static func _coordinate_set(coordinates_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not coordinates_value is Array:
		return result
	for coordinate_value: Variant in coordinates_value:
		if _is_public_position(coordinate_value):
			result[_coordinate_key(coordinate_value)] = true
	return result


static func _coordinate_key(position: Variant) -> String:
	if not position is Array or position.size() != 2:
		return ""
	return "%d,%d" % [int(position[0]), int(position[1])]


static func _contact_set(contacts_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not contacts_value is Array:
		return result
	for contact_value: Variant in contacts_value:
		if contact_value is Dictionary:
			result[_contact_key(contact_value)] = true
	return result


static func _contact_key(contact: Dictionary) -> String:
	return "%s:%s:%d" % [
		str(contact.get("kind", "")),
		_coordinate_key(contact.get("cell", [])),
		int(contact.get("created_at_action_index", -1)),
	]


static func _is_public_position(position: Variant) -> bool:
	if not position is Array or position.size() != 2:
		return false
	return typeof(position[0]) == TYPE_INT and typeof(position[1]) == TYPE_INT \
		and int(position[0]) >= 1 and int(position[0]) <= 9 \
		and int(position[1]) >= 1 and int(position[1]) <= 24
