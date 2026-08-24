class_name MatchFeedbackCoordinator
extends Node

const ObserverVfxPolicy = preload("res://scripts/game/vfx/observer_vfx_policy.gd")
const ObserverAudioPolicy = preload("res://scripts/game/audio/observer_audio_policy.gd")
const VfxCueContract = preload("res://scripts/game/vfx/vfx_cue.gd")

@onready var _audio_root: VeilfrontAudioRoot = $AudioRoot

var _vfx_director: VfxDirector
var _previous_view: Dictionary = {}
var _pending_view: Dictionary = {}
var _local_sequence: int = 0
var _board_emitter: BoardAudioEmitterPool


func bind_board_feedback(
	board_emitter: BoardAudioEmitterPool,
	vfx_director: VfxDirector
) -> void:
	if is_instance_valid(_board_emitter) and _board_emitter != board_emitter:
		_audio_root.unregister_board_emitter(_board_emitter)
	_board_emitter = board_emitter
	_audio_root.register_board_emitter(board_emitter)
	_vfx_director = vfx_director


func consume_player_view(view: Dictionary) -> void:
	if _starts_new_public_timeline(view):
		reset_session()
	_pending_view = view.duplicate(true)
	_audio_root.consume_player_view(view)


func consume_visible_events(events: Array) -> Dictionary:
	if _pending_view.is_empty():
		return {}
	var current_view := _pending_view.duplicate(true)
	var audio_candidate: Dictionary = ObserverAudioPolicy.project_frame(
		_previous_view,
		current_view,
		events
	)
	var vfx_batch: Dictionary = ObserverVfxPolicy.derive_batch(
		_previous_view,
		current_view,
		events,
		_motion_profile()
	)
	var audio_batch_valid: bool = not audio_candidate.is_empty()
	var vfx_batch_valid: bool = VfxCueContract.is_valid_batch(vfx_batch)
	if not audio_batch_valid or not vfx_batch_valid:
		reset_session()
		return {
			"audio_batch": {},
			"vfx_batch": vfx_batch,
			"audio_batch_valid": audio_batch_valid,
			"vfx_batch_valid": vfx_batch_valid,
			"vfx_played": 0,
		}
	var audio_batch: Dictionary = _audio_root.consume_visible_events(events)
	if audio_batch.is_empty():
		reset_session()
		return {
			"audio_batch": {},
			"vfx_batch": vfx_batch,
			"audio_batch_valid": false,
			"vfx_batch_valid": true,
			"vfx_played": 0,
		}
	var vfx_played := 0
	if is_instance_valid(_vfx_director):
		vfx_played = _vfx_director.play_batch(vfx_batch)
	_previous_view = current_view
	_pending_view.clear()
	return {
		"audio_batch": audio_batch,
		"vfx_batch": vfx_batch,
		"audio_batch_valid": true,
		"vfx_batch_valid": vfx_batch_valid,
		"vfx_played": vfx_played,
	}


func consume_visible_error(error: Dictionary) -> Dictionary:
	return _audio_root.consume_visible_error(error)


func play_local_selection(cell: Vector2i) -> void:
	if not _is_public_cell(cell):
		return
	play_local_cue("sfx.board.select", cell)
	var view := _feedback_view()
	if view.is_empty() or not is_instance_valid(_vfx_director):
		return
	_local_sequence += 1
	var batch: Dictionary = ObserverVfxPolicy.derive_local_selection_batch(
		str(view.get("match_id", "")),
		int(view.get("action_index", -1)),
		int(view.get("visible_event_cursor", -1)),
		_local_sequence,
		[cell.x, cell.y],
		str(view.get("viewer_side", "")),
		_motion_profile()
	)
	_vfx_director.play_batch(batch)


func play_local_cue(cue_key: String, cell: Vector2i = Vector2i.ZERO) -> bool:
	var position_public: Array = [cell.x, cell.y] if _is_public_cell(cell) else []
	var view := _feedback_view()
	var session_public_id := str(view.get("match_id", "local"))
	return _audio_root.play_local_cue(cue_key, position_public, session_public_id)


func reset_session() -> void:
	_previous_view.clear()
	_pending_view.clear()
	_local_sequence = 0
	_audio_root.reset_session()
	if is_instance_valid(_vfx_director):
		_vfx_director.clear_all()


func _exit_tree() -> void:
	if is_instance_valid(_audio_root) and is_instance_valid(_board_emitter):
		_audio_root.unregister_board_emitter(_board_emitter)
	_board_emitter = null
	_vfx_director = null


func get_audio_root() -> VeilfrontAudioRoot:
	return _audio_root


func get_feedback_snapshot() -> Dictionary:
	return {
		"has_previous_view": not _previous_view.is_empty(),
		"has_pending_view": not _pending_view.is_empty(),
		"board_emitter_bound": is_instance_valid(_board_emitter),
		"vfx_bound": is_instance_valid(_vfx_director),
		"vfx": _vfx_director.get_pool_snapshot() \
			if is_instance_valid(_vfx_director) else {},
	}


func _feedback_view() -> Dictionary:
	return _pending_view if not _pending_view.is_empty() else _previous_view


func _starts_new_public_timeline(view: Dictionary) -> bool:
	var baseline := _feedback_view()
	if baseline.is_empty():
		return false
	return str(view.get("match_id", "")) != str(baseline.get("match_id", "")) \
		or str(view.get("viewer_side", "")) != str(baseline.get("viewer_side", "")) \
		or int(view.get("action_index", -1)) < int(baseline.get("action_index", -1)) \
		or int(view.get("visible_event_cursor", -1)) \
			< int(baseline.get("visible_event_cursor", -1))


func _motion_profile() -> String:
	var settings_manager := get_node_or_null("/root/SettingsManager")
	if settings_manager != null \
	and settings_manager.has_method("is_reduced_motion_enabled") \
	and bool(settings_manager.call("is_reduced_motion_enabled")):
		return "reduced"
	return "standard"


func _is_public_cell(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= 9 and cell.y >= 1 and cell.y <= 24
