class_name ObserverVfxPolicy
extends RefCounted

const VfxCueContract = preload("res://scripts/game/vfx/vfx_cue.gd")
const PositionMapper = preload("res://scripts/game/vfx/vfx_public_position_mapper.gd")
const PlayerViewCodec = preload("res://scripts/game/contracts/player_view_codec.gd")
const VisibleEventCodec = preload("res://scripts/game/contracts/visible_event_codec.gd")

const PHASE_SETTLEMENT: int = 10
const PHASE_CASUALTY: int = 20
const PHASE_STATE: int = 30
const PHASE_TERMINAL: int = 50


static func derive_batch(
	previous_view: Dictionary,
	current_view: Dictionary,
	visible_events: Array,
	motion_profile: String = "standard"
) -> Dictionary:
	if motion_profile not in VfxCueContract.MOTION_PROFILES \
	or not _valid_player_view(current_view) \
	or (not previous_view.is_empty() and not _valid_player_view(previous_view)) \
	or not _same_observer(previous_view, current_view) \
	or not _valid_visible_events(visible_events):
		return {"ok": false, "error": "invalid_observer_frame"}
	var session_public_id: String = str(current_view["match_id"])
	var action_index: int = int(current_view["action_index"])
	var visible_event_cursor: int = int(current_view["visible_event_cursor"])
	var candidates: Array[Dictionary] = []
	if previous_view.is_empty():
		_append_terminal_candidate(candidates, {}, current_view)
	else:
		_append_settlement_candidates(candidates, previous_view, current_view, visible_events)
		_append_capture_candidates(candidates, previous_view, current_view)
		_append_wall_candidates(candidates, previous_view, current_view)
		_append_flag_candidates(candidates, previous_view, current_view)
		_append_terminal_candidate(candidates, previous_view, current_view)
	candidates.sort_custom(_candidate_less)
	var cues: Array = []
	var occurrence_counts: Dictionary = {}
	for index: int in candidates.size():
		var candidate: Dictionary = candidates[index]
		var cue_key: String = str(candidate["cue_key"])
		var occurrence_index: int = int(occurrence_counts.get(cue_key, 0))
		occurrence_counts[cue_key] = occurrence_index + 1
		cues.append(VfxCueContract.build(
			session_public_id,
			visible_event_cursor,
			cue_key,
			str(candidate["source_kind"]),
			action_index,
			occurrence_index,
			str(candidate["spatial_mode"]),
			candidate["position_public"],
			str(candidate["priority"]),
			str(candidate["concurrency_group"]),
			str(candidate["late_policy"]),
			str(candidate["actor_side_public"]),
			motion_profile,
			str(candidate["source_token"])
		))
	return VfxCueContract.build_batch(
		session_public_id,
		action_index,
		visible_event_cursor,
		motion_profile,
		cues
	)


static func derive_local_selection_batch(
	session_public_id: String,
	action_index: int,
	visible_event_cursor: int,
	local_sequence: int,
	position_public: Array,
	actor_side_public: String,
	motion_profile: String = "standard"
) -> Dictionary:
	if session_public_id.is_empty() \
	or action_index < 0 or visible_event_cursor < 0 or local_sequence < 0 \
	or not PositionMapper.is_public_cell(position_public) \
	or actor_side_public not in ["red", "black"] \
	or motion_profile not in VfxCueContract.MOTION_PROFILES:
		return {"ok": false, "error": "invalid_local_interaction"}
	var cue := VfxCueContract.build(
		session_public_id,
		visible_event_cursor,
		"vfx.selection.focus",
		"local_interaction",
		action_index,
		0,
		"board_2d",
		position_public,
		"normal",
		"selection",
		"replace_group",
		actor_side_public,
		motion_profile,
		"local-%d" % local_sequence
	)
	return VfxCueContract.build_batch(
		session_public_id,
		action_index,
		visible_event_cursor,
		motion_profile,
		[cue]
	)


static func _append_settlement_candidates(
	candidates: Array[Dictionary],
	previous_view: Dictionary,
	current_view: Dictionary,
	visible_events: Array
) -> void:
	var previous_cursor: int = int(previous_view["visible_event_cursor"])
	var current_cursor: int = int(current_view["visible_event_cursor"])
	for event_value: Variant in visible_events:
		var event: Dictionary = event_value
		var sequence: int = int(event["visible_sequence"])
		if sequence <= previous_cursor or sequence > current_cursor:
			continue
		if str(event["event_type"]) != "bombardment_resolved":
			continue
		var position: Array = _public_position(event.get("position_public", []))
		candidates.append(_candidate(
			PHASE_SETTLEMENT,
			"010-event-%08d" % sequence,
			"vfx.bombardment.resolve",
			"visible_event",
			"board_2d" if not position.is_empty() else "global",
			position,
			"high",
			"bombardment",
			"play_once",
			str(event.get("actor_side_public", "")),
			"event-%d" % sequence
		))
	if int(current_view["action_index"]) != int(previous_view["action_index"]) + 1:
		return
	var previous_pieces: Dictionary = _records_by_id(previous_view.get("pieces", []), "id")
	var current_pieces: Dictionary = _records_by_id(current_view.get("pieces", []), "id")
	var piece_ids: Array = current_pieces.keys()
	piece_ids.sort()
	for piece_id_value: Variant in piece_ids:
		var piece_id: String = str(piece_id_value)
		if not previous_pieces.has(piece_id):
			continue
		var previous_piece: Dictionary = previous_pieces[piece_id]
		var current_piece: Dictionary = current_pieces[piece_id]
		var previous_position: Array = _public_position(previous_piece.get("position", []))
		var current_position: Array = _public_position(current_piece.get("position", []))
		if previous_position.is_empty() or current_position.is_empty() \
		or previous_position == current_position \
		or not bool(current_piece.get("alive", true)) \
		or bool(current_piece.get("in_reserve", false)):
			continue
		candidates.append(_candidate(
			PHASE_SETTLEMENT,
			"020-piece-%s" % piece_id,
			"vfx.move.step",
			"view_diff",
			"board_2d",
			current_position,
			"normal",
			"move",
			"drop_if_late",
			str(current_piece.get("side", "")),
			"piece-%s" % piece_id
		))


static func _append_capture_candidates(
	candidates: Array[Dictionary],
	previous_view: Dictionary,
	current_view: Dictionary
) -> void:
	var previous_ghosts: Dictionary = _records_by_id(
		previous_view.get("capture_ghosts", []), "piece_id"
	)
	var current_ghosts: Dictionary = _records_by_id(
		current_view.get("capture_ghosts", []), "piece_id"
	)
	var piece_ids: Array = current_ghosts.keys()
	piece_ids.sort()
	for piece_id_value: Variant in piece_ids:
		var piece_id: String = str(piece_id_value)
		if previous_ghosts.has(piece_id):
			continue
		var ghost: Dictionary = current_ghosts[piece_id]
		var position: Array = _public_position(ghost.get("position", []))
		if position.is_empty():
			continue
		candidates.append(_candidate(
			PHASE_CASUALTY,
			"capture-%s" % piece_id,
			"vfx.capture.impact",
			"view_diff",
			"board_2d",
			position,
			"high",
			"capture",
			"play_once",
			str(ghost.get("side", "")),
			"ghost-%s" % piece_id
		))


static func _append_wall_candidates(
	candidates: Array[Dictionary],
	previous_view: Dictionary,
	current_view: Dictionary
) -> void:
	var previous_walls: Dictionary = _records_by_id(previous_view.get("walls", []), "side")
	var current_walls: Dictionary = _records_by_id(current_view.get("walls", []), "side")
	for side: String in ["red", "black"]:
		if not previous_walls.has(side) or not current_walls.has(side):
			continue
		var old_status: String = str(previous_walls[side].get("status", ""))
		var new_status: String = str(current_walls[side].get("status", ""))
		if old_status == new_status:
			continue
		var suffix: String = {
			"BREACHED": "breached",
			"REPAIRING": "repairing",
			"INTACT": "repaired",
		}.get(new_status, "changed")
		candidates.append(_candidate(
			PHASE_STATE,
			"010-wall-%s" % side,
			"vfx.wall.%s" % suffix,
			"view_diff",
			"board_2d",
			PositionMapper.wall_anchor(side),
			"high",
			"wall",
			"replace_group",
			side,
			"wall-%s-%s" % [side, new_status]
		))


static func _append_flag_candidates(
	candidates: Array[Dictionary],
	previous_view: Dictionary,
	current_view: Dictionary
) -> void:
	var previous_flags: Dictionary = _records_by_id(previous_view.get("flags", []), "id")
	var current_flags: Dictionary = _records_by_id(current_view.get("flags", []), "id")
	var flag_ids: Array = current_flags.keys()
	flag_ids.sort()
	for flag_id_value: Variant in flag_ids:
		var flag_id: String = str(flag_id_value)
		if not previous_flags.has(flag_id):
			continue
		var old_flag: Dictionary = previous_flags[flag_id]
		var new_flag: Dictionary = current_flags[flag_id]
		var position: Array = _public_position(new_flag.get("position", []))
		var spatial_mode := "board_2d" if not position.is_empty() else "global"
		var old_discovered: bool = bool(old_flag.get("discovered", false))
		var new_discovered: bool = bool(new_flag.get("discovered", false))
		if not old_discovered and new_discovered:
			_append_flag_candidate(
				candidates, flag_id, "discovered", "high", position, spatial_mode,
				str(new_flag.get("owner", "")), "010"
			)
		var old_owner: String = str(old_flag.get("owner", ""))
		var new_owner: String = str(new_flag.get("owner", ""))
		var old_progress: int = int(old_flag.get("capture_progress", 0))
		var new_progress: int = int(new_flag.get("capture_progress", 0))
		if old_owner != new_owner:
			_append_flag_candidate(
				candidates, flag_id, "captured", "high", position, spatial_mode,
				new_owner, "030"
			)
		elif new_progress > old_progress:
			_append_flag_candidate(
				candidates, flag_id, "progress", "normal", position, spatial_mode,
				str(new_flag.get("capturing_side", "")), "020"
			)
		elif old_progress > 0 and new_progress == 0:
			_append_flag_candidate(
				candidates, flag_id, "cancelled", "normal", position, spatial_mode,
				str(old_flag.get("capturing_side", "")), "040"
			)


static func _append_flag_candidate(
	candidates: Array[Dictionary],
	flag_id: String,
	suffix: String,
	priority: String,
	position: Array,
	spatial_mode: String,
	actor_side: String,
	sort_prefix: String
) -> void:
	candidates.append(_candidate(
		PHASE_STATE,
		"020-flag-%s-%s-%s" % [flag_id, sort_prefix, suffix],
		"vfx.flag.%s" % suffix,
		"view_diff",
		spatial_mode,
		position,
		priority,
		"flag",
		"replace_group",
		actor_side,
		"flag-%s-%s" % [flag_id, suffix]
	))


static func _append_terminal_candidate(
	candidates: Array[Dictionary],
	previous_view: Dictionary,
	current_view: Dictionary
) -> void:
	if not bool(current_view.get("terminal", false)) \
	or (not previous_view.is_empty() and bool(previous_view.get("terminal", false))):
		return
	var viewer_side: String = str(current_view.get("viewer_side", ""))
	var winner: String = str(current_view.get("winner", ""))
	var suffix := "draw"
	if winner in ["red", "black"]:
		suffix = "victory" if winner == viewer_side else "defeat"
	candidates.append(_candidate(
		PHASE_TERMINAL,
		"terminal-%s" % suffix,
		"vfx.terminal.%s" % suffix,
		"view_diff",
		"global",
		[],
		"critical",
		"terminal",
		"play_once",
		winner if winner in ["red", "black"] else "",
		"terminal-%s" % suffix
	))


static func _candidate(
	phase: int,
	sort_key: String,
	cue_key: String,
	source_kind: String,
	spatial_mode: String,
	position_public: Array,
	priority: String,
	concurrency_group: String,
	late_policy: String,
	actor_side_public: String,
	source_token: String
) -> Dictionary:
	return {
		"phase": phase,
		"sort_key": sort_key,
		"cue_key": cue_key,
		"source_kind": source_kind,
		"spatial_mode": spatial_mode,
		"position_public": position_public.duplicate(),
		"priority": priority,
		"concurrency_group": concurrency_group,
		"late_policy": late_policy,
		"actor_side_public": actor_side_public \
			if actor_side_public in ["red", "black"] else "",
		"source_token": source_token,
	}


static func _candidate_less(a: Dictionary, b: Dictionary) -> bool:
	var phase_a: int = int(a["phase"])
	var phase_b: int = int(b["phase"])
	return phase_a < phase_b or (phase_a == phase_b and str(a["sort_key"]) < str(b["sort_key"]))


static func _records_by_id(records: Array, id_field: String) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in records:
		if not value is Dictionary:
			continue
		var identifier: String = str(value.get(id_field, ""))
		if not identifier.is_empty():
			result[identifier] = value
	return result


static func _public_position(value: Variant) -> Array:
	if not PositionMapper.is_public_cell(value):
		return []
	return [int(value[0]), int(value[1])]


static func _valid_player_view(view: Dictionary) -> bool:
	return bool(PlayerViewCodec.encode(view).get("ok", false))


static func _valid_visible_events(events: Array) -> bool:
	for value: Variant in events:
		if not value is Dictionary \
		or not bool(VisibleEventCodec.encode(value).get("ok", false)):
			return false
	return true


static func _same_observer(previous_view: Dictionary, current_view: Dictionary) -> bool:
	if previous_view.is_empty():
		return true
	return previous_view.get("match_id") == current_view.get("match_id") \
		and previous_view.get("viewer_side") == current_view.get("viewer_side") \
		and int(current_view.get("action_index", -1)) >= int(previous_view.get("action_index", -1)) \
		and int(current_view.get("visible_event_cursor", -1)) \
			>= int(previous_view.get("visible_event_cursor", -1))
