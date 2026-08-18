extends RefCounted

const Canonical = preload("res://scripts/game/domain/canonical.gd")
const PlayerViewCodec = preload("res://scripts/game/contracts/player_view_codec.gd")
const VisibleEventCodec = preload("res://scripts/game/contracts/visible_event_codec.gd")
const VisibleErrorCodec = preload("res://scripts/game/contracts/visible_error_codec.gd")
const ActionPreviewCodec = preload("res://scripts/game/contracts/action_preview_codec.gd")

const ROOT_FIELDS: Array[String] = [
	"schema_version", "match_id", "rules_revision", "viewer_side", "initial_player_view",
	"frames", "final_player_view_digest", "codec_versions", "audit_digest",
]
const FRAME_FIELDS: Array[String] = [
	"frame_sequence", "action_index", "player_view_or_digest", "visible_events", "visible_error",
	"action_previews",
]
const CODEC_VERSIONS: Dictionary = {
	"observer_replay": "veilfront-observer-replay-v2",
	"player_view": "veilfront-player-view-v1",
	"visible_event": "veilfront-visible-event-v1",
	"visible_error": "veilfront-visible-error-v1",
	"action_preview": "veilfront-action-preview-v1",
}


static func validate(record: Dictionary, bound_side: String) -> Dictionary:
	if not _has_exact_fields(record, ROOT_FIELDS) \
	or str(record.get("schema_version", "")) != "veilfront-observer-replay-v2" \
	or str(record.get("viewer_side", "")) != bound_side \
	or record.get("codec_versions") != CODEC_VERSIONS:
		return _failure()
	var audit_surface: Dictionary = record.duplicate(true)
	var expected_audit: String = str(audit_surface.get("audit_digest", ""))
	audit_surface["audit_digest"] = ""
	if expected_audit.is_empty() or Canonical.digest(audit_surface) != expected_audit:
		return _failure()
	var initial_view: Variant = record.get("initial_player_view")
	if not initial_view is Dictionary or not _valid_player_view(
		initial_view, record, bound_side
	):
		return _failure()
	var frames: Variant = record.get("frames")
	if not frames is Array:
		return _failure()
	var final_view: Dictionary = initial_view
	var previous_action_index: int = int(initial_view.get("action_index", 0))
	var previous_cursor: int = int(initial_view.get("visible_event_cursor", 0))
	var previous_events: Array = []
	for frame_index: int in frames.size():
		var frame_value: Variant = frames[frame_index]
		if not frame_value is Dictionary:
			return _failure()
		var frame: Dictionary = frame_value
		if not _has_exact_fields(frame, FRAME_FIELDS) \
		or typeof(frame.get("frame_sequence")) != TYPE_INT \
		or int(frame.get("frame_sequence", 0)) != frame_index + 1 \
		or typeof(frame.get("action_index")) != TYPE_INT \
		or int(frame.get("action_index", -1)) < previous_action_index:
			return _failure()
		var player_view: Variant = frame.get("player_view_or_digest")
		if not player_view is Dictionary or not _valid_player_view(
			player_view, record, bound_side
		) or int(frame["action_index"]) != int(player_view["action_index"]):
			return _failure()
		if not _valid_visible_events(frame.get("visible_events")) \
		or not _valid_visible_error(frame.get("visible_error")) \
		or not _valid_action_previews(frame.get("action_previews")):
			return _failure()
		var visible_events: Array = frame["visible_events"]
		var visible_cursor: int = int(player_view.get("visible_event_cursor", -1))
		if visible_cursor != visible_events.size() or visible_cursor < previous_cursor \
		or visible_events.slice(0, previous_events.size()) != previous_events:
			return _failure()
		previous_action_index = int(frame["action_index"])
		previous_cursor = visible_cursor
		previous_events = visible_events.duplicate(true)
		final_view = player_view
	if str(record.get("final_player_view_digest", "")) != Canonical.digest(final_view):
		return _failure()
	return {"ok": true, "value": record.duplicate(true), "error_code": ""}


static func _valid_player_view(
	view: Dictionary,
	record: Dictionary,
	bound_side: String
) -> bool:
	return bool(PlayerViewCodec.encode(view).get("ok", false)) \
		and str(view.get("match_id", "")) == str(record.get("match_id", "")) \
		and str(view.get("rules_revision", "")) == str(record.get("rules_revision", "")) \
		and str(view.get("viewer_side", "")) == bound_side


static func _valid_visible_events(value: Variant) -> bool:
	if not value is Array:
		return false
	var expected_sequence: int = 1
	for event_value: Variant in value:
		if not event_value is Dictionary \
		or not bool(VisibleEventCodec.encode(event_value).get("ok", false)) \
		or int(event_value.get("visible_sequence", 0)) != expected_sequence:
			return false
		expected_sequence += 1
	return true


static func _valid_visible_error(value: Variant) -> bool:
	return value is Dictionary and (
		value.is_empty() or bool(VisibleErrorCodec.encode(value).get("ok", false))
	)


static func _valid_action_previews(value: Variant) -> bool:
	if not value is Array:
		return false
	var previous_id: String = ""
	for preview_value: Variant in value:
		if not preview_value is Dictionary \
		or not bool(ActionPreviewCodec.encode(preview_value).get("ok", false)):
			return false
		var preview_id: String = str(preview_value.get("preview_id", ""))
		if not previous_id.is_empty() and preview_id <= previous_id:
			return false
		previous_id = preview_id
	return true


static func _has_exact_fields(value: Dictionary, fields: Array[String]) -> bool:
	if value.size() != fields.size():
		return false
	for field_name: String in fields:
		if not value.has(field_name):
			return false
	return true


static func _failure() -> Dictionary:
	return {"ok": false, "value": {}, "error_code": "invalid_or_tampered_observer_replay"}
