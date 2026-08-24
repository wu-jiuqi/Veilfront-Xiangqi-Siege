class_name BoardAudioEmitterPool
extends Node2D

signal cue_emitted(cue_key: String, world_position: Vector2)
signal cue_dropped(cue_key: String, reason: String)

const BoardCoordinateMapper = preload(
	"res://scripts/game/presentation/board/board_coordinate_mapper.gd"
)

@export var cell_size: Vector2 = Vector2(128.0, 128.0)
@export_enum("red", "black") var presentation_side: String = "red"
@export var dry_run: bool = false

var _players: Array[AudioStreamPlayer2D] = []
var _started_at: Dictionary = {}
var _groups: Dictionary = {}


func _ready() -> void:
	for child: Node in get_children():
		if child is AudioStreamPlayer2D:
			_players.append(child)
	var root_audio: Node = get_node_or_null("/root/AudioRoot")
	if root_audio != null and root_audio.has_method("register_board_emitter"):
		root_audio.call("register_board_emitter", self)


func _exit_tree() -> void:
	stop_all()
	var root_audio: Node = get_node_or_null("/root/AudioRoot")
	if root_audio != null and root_audio.has_method("unregister_board_emitter"):
		root_audio.call("unregister_board_emitter", self)


func set_presentation_side(side: String) -> void:
	if side in ["red", "black"]:
		presentation_side = side


func play_cue(
	cue: Dictionary,
	definition: AudioCueDefinition,
	stream: AudioStream
) -> bool:
	if str(cue.get("spatial_mode", "")) != "board_2d" \
	or definition == null or stream == null:
		cue_dropped.emit(str(cue.get("cue_key", "")), "invalid_board_cue")
		return false
	var position_value: Variant = cue.get("position_public", [])
	if not position_value is Array:
		cue_dropped.emit(str(cue.get("cue_key", "")), "position_not_public")
		return false
	var cell := BoardCoordinateMapper.coordinate_from_variant(position_value)
	if not BoardCoordinateMapper.is_authority_cell_valid(cell):
		cue_dropped.emit(str(cue.get("cue_key", "")), "position_not_public")
		return false
	var world_position := BoardCoordinateMapper.authority_to_world(
		cell, presentation_side, cell_size
	)
	if dry_run:
		cue_emitted.emit(str(cue.get("cue_key", "")), world_position)
		return true
	var player: AudioStreamPlayer2D = _available_player()
	if player == null:
		cue_dropped.emit(str(cue.get("cue_key", "")), "board_pool_exhausted")
		return false
	player.position = world_position
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
	_started_at[player.get_instance_id()] = Time.get_ticks_msec()
	_groups[player.get_instance_id()] = definition.concurrency_group
	cue_emitted.emit(str(cue.get("cue_key", "")), world_position)
	return true


func preset_player_count() -> int:
	return _players.size()


func stop_all() -> void:
	for player: AudioStreamPlayer2D in _players:
		player.stop()
		player.stream = null
	_started_at.clear()
	_groups.clear()


func active_count_for_group(group: String) -> int:
	var count: int = 0
	for player: AudioStreamPlayer2D in _players:
		if player.playing and str(_groups.get(player.get_instance_id(), "")) == group:
			count += 1
	return count


func _available_player() -> AudioStreamPlayer2D:
	for player: AudioStreamPlayer2D in _players:
		if not player.playing:
			return player
	var oldest: AudioStreamPlayer2D
	var oldest_time: int = 9223372036854775807
	for player: AudioStreamPlayer2D in _players:
		var started: int = int(_started_at.get(player.get_instance_id(), 0))
		if started < oldest_time:
			oldest_time = started
			oldest = player
	return oldest


func _stable_fraction(cue_id: String, channel: String) -> float:
	var digest: String = (cue_id + ":" + channel).sha256_text()
	var value: int = digest.substr(0, 6).hex_to_int()
	return float(value) / float(0xFFFFFF)
