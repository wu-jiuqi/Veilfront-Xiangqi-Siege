class_name VeilfrontAudioRoot
extends Node

signal cue_played(cue: Dictionary)
signal cue_dropped(cue: Dictionary, reason: String)
signal batch_processed(batch: Dictionary)

const ObserverPolicy = preload("res://scripts/game/audio/observer_audio_policy.gd")

@export var sfx_catalog: SfxCatalog
@export var dry_run: bool = false

@onready var _deduplicator: AudioCueDeduplicator = $AudioCueDeduplicator
@onready var _global_sfx_pool: Node = $GlobalSfxPool

var _previous_view: Dictionary = {}
var _pending_view: Dictionary = {}
var _board_emitter: BoardAudioEmitterPool
var _local_sequence: int = 0
var _group_last_played_ms: Dictionary = {}
var _global_started_at: Dictionary = {}
var _global_priorities: Dictionary = {}
var _global_groups: Dictionary = {}


func _ready() -> void:
	if sfx_catalog == null or not sfx_catalog.validation_errors().is_empty():
		push_error("AudioRoot 缺少合法的 SFX Catalog。")


func _exit_tree() -> void:
	stop_all()


func consume_player_view(view: Dictionary) -> void:
	_pending_view = view.duplicate(true)


func consume_visible_events(events: Array) -> Dictionary:
	if _pending_view.is_empty():
		return {}
	var batch: Dictionary = process_observer_frame(_pending_view, events)
	_pending_view.clear()
	return batch


func consume_visible_error(error: Dictionary) -> Dictionary:
	if _previous_view.is_empty():
		return {}
	var batch: Dictionary = ObserverPolicy.project_visible_error(_previous_view, error)
	_submit_batch(batch)
	return batch


func process_observer_frame(
	current_view: Dictionary,
	visible_events: Array,
	visible_error: Dictionary = {}
) -> Dictionary:
	var batch: Dictionary = ObserverPolicy.project_frame(
		_previous_view, current_view, visible_events, visible_error
	)
	if batch.is_empty():
		return {}
	_previous_view = current_view.duplicate(true)
	_submit_batch(batch)
	return batch


func play_local_cue(
	cue_key: String,
	position_public: Array = [],
	session_public_id: String = "local"
) -> bool:
	_local_sequence += 1
	var action_index: int = int(_previous_view.get("action_index", -1))
	var cue: Dictionary = ObserverPolicy.local_cue(
		session_public_id, action_index, _local_sequence, cue_key, position_public
	)
	return submit_cue(cue)


func submit_cue(cue: Dictionary) -> bool:
	if sfx_catalog == null:
		cue_dropped.emit(cue.duplicate(true), "catalog_missing")
		return false
	var cue_id: String = str(cue.get("cue_id", ""))
	if not _deduplicator.accept_cue(cue_id):
		cue_dropped.emit(cue.duplicate(true), "duplicate_cue")
		return false
	var definition: AudioCueDefinition = sfx_catalog.definition_for(
		str(cue.get("cue_key", ""))
	)
	if definition == null or not definition.is_valid_definition():
		cue_dropped.emit(cue.duplicate(true), "definition_missing")
		return false
	if str(cue.get("concurrency_group", "")) != definition.concurrency_group \
	or str(cue.get("priority", "")) != definition.priority:
		cue_dropped.emit(cue.duplicate(true), "definition_contract_mismatch")
		return false
	var spatial_mode: String = str(cue.get("spatial_mode", ""))
	if spatial_mode not in definition.spatial_modes_allowed:
		cue_dropped.emit(cue.duplicate(true), "spatial_mode_disallowed")
		return false
	if not _passes_cooldown_and_concurrency(definition):
		cue_dropped.emit(cue.duplicate(true), "concurrency_limited")
		return false
	var stream: AudioStream = _stable_stream(definition, cue_id)
	if stream == null:
		cue_dropped.emit(cue.duplicate(true), "stream_missing")
		return false
	if str(cue.get("priority", "")) == "critical":
		_stop_noncritical_global_players()
	var played: bool
	if spatial_mode == "board_2d":
		played = _board_emitter != null \
			and _board_emitter.play_cue(cue, definition, stream)
		if not played:
			cue_dropped.emit(cue.duplicate(true), "board_pool_unbound_or_exhausted")
	else:
		played = _play_global(cue, definition, stream)
	if played:
		_group_last_played_ms[definition.concurrency_group] = Time.get_ticks_msec()
		cue_played.emit(cue.duplicate(true))
	return played


func register_board_emitter(emitter: BoardAudioEmitterPool) -> void:
	_board_emitter = emitter
	if _board_emitter != null:
		_board_emitter.dry_run = dry_run


func unregister_board_emitter(emitter: BoardAudioEmitterPool) -> void:
	if _board_emitter == emitter:
		_board_emitter = null


func reset_session() -> void:
	_previous_view.clear()
	_pending_view.clear()
	_deduplicator.reset_history()
	_group_last_played_ms.clear()
	stop_all()
	if _board_emitter != null:
		_board_emitter.stop_all()


func stop_all() -> void:
	for child: Node in _global_sfx_pool.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	_global_started_at.clear()
	_global_priorities.clear()
	_global_groups.clear()


func _submit_batch(batch: Dictionary) -> void:
	if batch.is_empty():
		return
	var batch_digest: String = str(batch.get("batch_digest", ""))
	if not _deduplicator.accept_batch(batch_digest):
		return
	for cue_value: Variant in batch.get("cues", []):
		if cue_value is Dictionary:
			submit_cue(cue_value)
	batch_processed.emit(batch.duplicate(true))


func _play_global(
	cue: Dictionary,
	definition: AudioCueDefinition,
	stream: AudioStream
) -> bool:
	if dry_run:
		return true
	var player: AudioStreamPlayer = _available_global_player(
		definition.bus, str(cue.get("priority", "normal"))
	)
	if player == null:
		return false
	player.bus = definition.bus
	player.stream = stream
	player.volume_db = lerpf(
		definition.volume_db_min,
		definition.volume_db_max,
		_stable_fraction(str(cue.get("cue_id", "")), "volume")
	)
	player.pitch_scale = lerpf(
		definition.pitch_scale_min,
		definition.pitch_scale_max,
		_stable_fraction(str(cue.get("cue_id", "")), "pitch")
	)
	player.play()
	_global_started_at[player.get_instance_id()] = Time.get_ticks_msec()
	_global_priorities[player.get_instance_id()] = str(cue.get("priority", "normal"))
	_global_groups[player.get_instance_id()] = definition.concurrency_group
	return true


func _available_global_player(bus: StringName, priority: String) -> AudioStreamPlayer:
	var prefix: String = "Ui" if bus == &"SFX_UI" else "System"
	var candidates: Array[AudioStreamPlayer] = []
	for child: Node in _global_sfx_pool.get_children():
		if child is AudioStreamPlayer and child.name.begins_with(prefix):
			candidates.append(child)
	for player: AudioStreamPlayer in candidates:
		if not player.playing:
			return player
	var incoming_rank: int = _priority_rank(priority)
	var oldest: AudioStreamPlayer
	var oldest_time: int = 9223372036854775807
	for player: AudioStreamPlayer in candidates:
		var instance_id: int = player.get_instance_id()
		var active_rank: int = _priority_rank(str(_global_priorities.get(instance_id, "low")))
		var started_at: int = int(_global_started_at.get(instance_id, 0))
		if active_rank <= incoming_rank and started_at < oldest_time:
			oldest_time = started_at
			oldest = player
	return oldest


func _passes_cooldown_and_concurrency(definition: AudioCueDefinition) -> bool:
	var now: int = Time.get_ticks_msec()
	var last: int = int(_group_last_played_ms.get(definition.concurrency_group, -1000000))
	if definition.cooldown_ms > 0 and now - last < definition.cooldown_ms:
		return false
	if dry_run:
		return true
	var active_count: int = 0
	for child: Node in _global_sfx_pool.get_children():
		if child is AudioStreamPlayer and child.playing \
		and str(_global_groups.get(child.get_instance_id(), "")) \
		== definition.concurrency_group:
			active_count += 1
	if _board_emitter != null:
		active_count += _board_emitter.active_count_for_group(definition.concurrency_group)
	return active_count < definition.max_instances


func _stable_stream(definition: AudioCueDefinition, cue_id: String) -> AudioStream:
	if definition.streams.is_empty():
		return null
	var digest: String = (cue_id + ":stream").sha256_text()
	var index: int = digest.substr(0, 6).hex_to_int() % definition.streams.size()
	return definition.streams[index]


func _stable_fraction(cue_id: String, channel: String) -> float:
	var digest: String = (cue_id + ":" + channel).sha256_text()
	return float(digest.substr(0, 6).hex_to_int()) / float(0xFFFFFF)


func _stop_noncritical_global_players() -> void:
	for child: Node in _global_sfx_pool.get_children():
		if not child is AudioStreamPlayer:
			continue
		var priority: String = str(_global_priorities.get(child.get_instance_id(), "low"))
		if priority in ["low", "normal"]:
			child.stop()


func _priority_rank(priority: String) -> int:
	match priority:
		"critical": return 3
		"high": return 2
		"normal": return 1
		_: return 0
