class_name VfxCue
extends RefCounted

const SCHEMA_VERSION: String = "veilfront-vfx-cue-v1"
const BATCH_SCHEMA_VERSION: String = "veilfront-vfx-cue-batch-v1"

const CUE_FIELDS: Array[String] = [
	"schema_version", "cue_id", "cue_key", "source_kind", "action_index",
	"occurrence_index", "spatial_mode", "position_public", "priority",
	"concurrency_group", "late_policy", "actor_side_public", "motion_profile",
]
const BATCH_FIELDS: Array[String] = [
	"schema_version", "session_public_id", "frame_action_index",
	"visible_event_cursor", "motion_profile", "cues", "batch_digest",
]
const SOURCE_KINDS: Array[String] = [
	"local_interaction", "visible_event", "visible_error", "view_diff",
]
const SPATIAL_MODES: Array[String] = ["global", "board_2d"]
const PRIORITIES: Array[String] = ["low", "normal", "high", "critical"]
const LATE_POLICIES: Array[String] = ["drop_if_late", "replace_group", "play_once"]
const MOTION_PROFILES: Array[String] = ["standard", "reduced"]


static func build(
	session_public_id: String,
	visible_event_cursor: int,
	cue_key: String,
	source_kind: String,
	action_index: int,
	occurrence_index: int,
	spatial_mode: String,
	position_public: Array,
	priority: String,
	concurrency_group: String,
	late_policy: String,
	actor_side_public: String,
	motion_profile: String,
	source_token: String = ""
) -> Dictionary:
	var normalized_position: Array = _normalized_position(position_public)
	var identity_text := "|".join(PackedStringArray([
		session_public_id,
		str(visible_event_cursor),
		cue_key,
		source_kind,
		str(action_index),
		str(occurrence_index),
		spatial_mode,
		_position_key(normalized_position),
		source_token,
	]))
	return {
		"schema_version": SCHEMA_VERSION,
		"cue_id": "vfx-%s" % identity_text.sha256_text().substr(0, 24),
		"cue_key": cue_key,
		"source_kind": source_kind,
		"action_index": action_index,
		"occurrence_index": occurrence_index,
		"spatial_mode": spatial_mode,
		"position_public": normalized_position,
		"priority": priority,
		"concurrency_group": concurrency_group,
		"late_policy": late_policy,
		"actor_side_public": actor_side_public,
		"motion_profile": motion_profile,
	}


static func build_batch(
	session_public_id: String,
	frame_action_index: int,
	visible_event_cursor: int,
	motion_profile: String,
	cues: Array
) -> Dictionary:
	var payload := {
		"schema_version": BATCH_SCHEMA_VERSION,
		"session_public_id": session_public_id,
		"frame_action_index": frame_action_index,
		"visible_event_cursor": visible_event_cursor,
		"motion_profile": motion_profile,
		"cues": cues.duplicate(true),
	}
	var digest_input := JSON.stringify(payload, "", true, true)
	payload["batch_digest"] = digest_input.sha256_text()
	return payload


static func is_valid(cue: Dictionary) -> bool:
	if not _has_exact_fields(cue, CUE_FIELDS):
		return false
	var position: Variant = cue.get("position_public")
	var spatial_mode: String = str(cue.get("spatial_mode", ""))
	return cue.get("schema_version") == SCHEMA_VERSION \
		and _non_empty_string(cue.get("cue_id")) \
		and str(cue.get("cue_id", "")).begins_with("vfx-") \
		and _non_empty_string(cue.get("cue_key")) \
		and str(cue.get("cue_key", "")).begins_with("vfx.") \
		and str(cue.get("source_kind", "")) in SOURCE_KINDS \
		and cue.get("action_index") is int and int(cue.get("action_index")) >= 0 \
		and cue.get("occurrence_index") is int \
		and int(cue.get("occurrence_index")) >= 0 \
		and spatial_mode in SPATIAL_MODES \
		and _valid_position_for_mode(position, spatial_mode) \
		and str(cue.get("priority", "")) in PRIORITIES \
		and _non_empty_string(cue.get("concurrency_group")) \
		and str(cue.get("late_policy", "")) in LATE_POLICIES \
		and str(cue.get("actor_side_public", "")) in ["", "red", "black"] \
		and str(cue.get("motion_profile", "")) in MOTION_PROFILES


static func is_valid_batch(batch: Dictionary) -> bool:
	if not _has_exact_fields(batch, BATCH_FIELDS):
		return false
	if batch.get("schema_version") != BATCH_SCHEMA_VERSION \
	or not _non_empty_string(batch.get("session_public_id")) \
	or not batch.get("frame_action_index") is int \
	or int(batch.get("frame_action_index")) < 0 \
	or not batch.get("visible_event_cursor") is int \
	or int(batch.get("visible_event_cursor")) < 0 \
	or str(batch.get("motion_profile", "")) not in MOTION_PROFILES \
	or not batch.get("cues") is Array \
	or not _non_empty_string(batch.get("batch_digest")):
		return false
	var cues: Array = batch["cues"]
	var occurrence_counts: Dictionary = {}
	for index: int in cues.size():
		if not cues[index] is Dictionary or not is_valid(cues[index]):
			return false
		var cue_key: String = str(cues[index].get("cue_key", ""))
		var expected_occurrence: int = int(occurrence_counts.get(cue_key, 0))
		if int(cues[index].get("occurrence_index", -1)) != expected_occurrence:
			return false
		occurrence_counts[cue_key] = expected_occurrence + 1
		if str(cues[index].get("motion_profile", "")) != str(batch["motion_profile"]):
			return false
	var unsigned := batch.duplicate(true)
	unsigned.erase("batch_digest")
	var expected := JSON.stringify(unsigned, "", true, true).sha256_text()
	return expected == str(batch.get("batch_digest", ""))


static func _has_exact_fields(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for field: String in expected:
		if not value.has(field):
			return false
	return true


static func _valid_position_for_mode(value: Variant, spatial_mode: String) -> bool:
	if not value is Array:
		return false
	var position: Array = value
	if spatial_mode == "global":
		return position.is_empty()
	return position.size() == 2 \
		and position[0] is int and position[1] is int \
		and int(position[0]) >= 1 and int(position[0]) <= 9 \
		and int(position[1]) >= 1 and int(position[1]) <= 24


static func _normalized_position(value: Array) -> Array:
	if value.size() != 2:
		return []
	return [int(value[0]), int(value[1])]


static func _position_key(value: Array) -> String:
	return "global" if value.is_empty() else "%d,%d" % [int(value[0]), int(value[1])]


static func _non_empty_string(value: Variant) -> bool:
	return value is String and not str(value).is_empty()
