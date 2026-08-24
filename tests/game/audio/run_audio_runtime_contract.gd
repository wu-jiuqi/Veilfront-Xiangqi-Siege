extends SceneTree

const AUDIO_ROOT_SCENE := preload("res://scenes/game/audio/audio_root.tscn")
const BOARD_POOL_SCENE := preload("res://scenes/game/audio/board_audio_emitter_pool.tscn")
const CATALOG := preload("res://resources/game/audio/sfx_catalog.tres")

var _checks: int = 0
var _played: Array[Dictionary] = []
var _dropped: Array[Dictionary] = []
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_catalog_and_sources()
	_check_buses()
	await _check_preset_pools_and_deduplication()
	await _check_concurrency_group_limit()
	_check_dependency_boundary()
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(failure)
		print("AUDIO_RUNTIME_CONTRACT_FAIL failures=%d" % _failures.size())
		quit(1)
		return
	print("AUDIO_RUNTIME_CONTRACT_PASS checks=%d cues=%d wav=31 pools=8+8" % [
		_checks, CATALOG.cue_keys().size(),
	])
	quit(0)


func _check_catalog_and_sources() -> void:
	_expect(CATALOG is SfxCatalog, "SFX Catalog type did not load")
	_expect(CATALOG.validation_errors().is_empty(), "SFX Catalog validation failed")
	_expect(CATALOG.cue_keys().size() >= 12, "fewer than 12 core cue definitions")
	var families: Dictionary = {}
	var stream_paths: Dictionary = {}
	for definition: AudioCueDefinition in CATALOG.definitions:
		var parts: PackedStringArray = definition.cue_key.split(".")
		if parts.size() >= 2:
			families[parts[1]] = true
		for stream: AudioStream in definition.streams:
			var source_path: String = stream.resource_path
			stream_paths[source_path] = true
			_expect(source_path.begins_with("res://assets/audio/sfx/"),
				"catalog references non-project audio source")
			_expect(FileAccess.file_exists(source_path), "catalog stream file is missing")
			_expect(stream is AudioStreamWAV, "short SFX was not imported as WAV")
			if stream is AudioStreamWAV:
				var wav := stream as AudioStreamWAV
				_expect(wav.format == AudioStreamWAV.FORMAT_16_BITS, "WAV is not 16-bit PCM")
				_expect(not wav.stereo, "board/runtime SFX must be mono")
				_expect(wav.mix_rate == 48000, "WAV is not 48 kHz")
	_expect(families.size() >= 12, "catalog exposes fewer than 12 logical families")
	_expect(stream_paths.size() == 31, "expected 31 traceable original WAV files")


func _check_buses() -> void:
	for bus_name: StringName in [
		&"Master", &"Music", &"SFX", &"SFX_UI", &"SFX_Board", &"SFX_System",
	]:
		_expect(AudioServer.get_bus_index(bus_name) >= 0, "missing audio bus: %s" % bus_name)
	var sfx_index: int = AudioServer.get_bus_index(&"SFX")
	for child_bus: StringName in [&"SFX_UI", &"SFX_Board", &"SFX_System"]:
		var child_index: int = AudioServer.get_bus_index(child_bus)
		_expect(AudioServer.get_bus_send(child_index) == &"SFX", "%s does not route through SFX" % child_bus)
	AudioServer.set_bus_mute(sfx_index, true)
	_expect(AudioServer.is_bus_mute(sfx_index), "SFX setting cannot mute its parent bus")
	AudioServer.set_bus_mute(sfx_index, false)
	_expect(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"Master")) >= 1,
		"Master safety limiter is missing")


func _check_preset_pools_and_deduplication() -> void:
	var audio_root := AUDIO_ROOT_SCENE.instantiate() as VeilfrontAudioRoot
	var board_pool := BOARD_POOL_SCENE.instantiate() as BoardAudioEmitterPool
	audio_root.dry_run = true
	board_pool.dry_run = true
	root.add_child(audio_root)
	root.add_child(board_pool)
	await process_frame
	audio_root.register_board_emitter(board_pool)
	audio_root.cue_played.connect(func(cue: Dictionary) -> void: _played.append(cue))
	audio_root.cue_dropped.connect(func(cue: Dictionary, reason: String) -> void:
		_dropped.append({"cue": cue, "reason": reason})
	)
	_expect(audio_root.get_node("GlobalSfxPool").get_child_count() == 8,
		"AudioRoot global pool is not preset to 8 players")
	_expect(board_pool.preset_player_count() == 8,
		"BoardAudioEmitterPool is not preset to 8 emitters")

	var previous := _view([1, 5], 0)
	audio_root.process_observer_frame(previous, [])
	var current := _view([1, 6], 1)
	var batch: Dictionary = audio_root.process_observer_frame(current, [_move_event()])
	_expect(not batch.is_empty(), "AudioRoot rejected a coherent public frame")
	_expect(_played.size() == 1, "public movement did not reach the board pool exactly once")
	var cue: Dictionary = batch["cues"][0]
	_expect(not audio_root.submit_cue(cue), "duplicate cue replay was accepted")
	_expect(_played.size() == 1, "duplicate cue emitted playback")
	_expect(_dropped.back()["reason"] == "duplicate_cue", "duplicate drop reason was not stable")
	audio_root.stop_all()
	board_pool.stop_all()
	audio_root.queue_free()
	board_pool.queue_free()
	await create_timer(0.1).timeout


func _check_concurrency_group_limit() -> void:
	var audio_root := AUDIO_ROOT_SCENE.instantiate() as VeilfrontAudioRoot
	audio_root.dry_run = false
	root.add_child(audio_root)
	await process_frame
	var local_drops: Array[String] = []
	audio_root.cue_dropped.connect(func(_cue: Dictionary, reason: String) -> void:
		local_drops.append(reason)
	)
	for index: int in 3:
		var cue := {
			"schema_version": "veilfront-audio-cue-v1",
			"cue_id": "concurrency:%d" % index,
			"cue_key": "sfx.ui.activate",
			"source_kind": "local_interaction",
			"action_index": -1,
			"occurrence_index": 0,
			"spatial_mode": "global",
			"position_public": [],
			"priority": "normal",
			"concurrency_group": "ui_action",
			"late_policy": "drop_if_late",
		}
		audio_root.submit_cue(cue)
	_expect(local_drops.has("concurrency_limited"),
		"catalog max_instances did not limit the third ui_action cue")
	audio_root.reset_session()
	for child: Node in audio_root.get_node("GlobalSfxPool").get_children():
		if child is AudioStreamPlayer:
			_expect(not child.playing and child.stream == null,
				"reset_session left a global SFX player active")
	audio_root.queue_free()
	await create_timer(0.1).timeout


func _check_dependency_boundary() -> void:
	var forbidden: Array[String] = [
		"scripts/game/domain", "full_state_codec", "seeded_random", "AuthoritativeReplay",
	]
	for path: String in [
		"res://scripts/game/audio/observer_audio_policy.gd",
		"res://scripts/game/audio/audio_root.gd",
		"res://scripts/game/audio/board_audio_emitter_pool.gd",
	]:
		var file := FileAccess.open(path, FileAccess.READ)
		_expect(file != null, "audio source cannot be scanned")
		var source: String = file.get_as_text()
		for token: String in forbidden:
			_expect(not source.contains(token), "audio source crosses forbidden boundary: %s" % token)


func _view(position: Array, action_index: int) -> Dictionary:
	return {
		"schema_version": "veilfront-player-view-v1",
		"match_id": "audio-runtime-test",
		"rules_revision": "owner-rule-revision-5",
		"viewer_side": "red",
		"board": {"width": 9, "height": 24},
		"active_side": "red" if action_index == 0 else "black",
		"action_index": action_index,
		"full_round_index": 1,
		"round_limit_public": 50,
		"terminal": false,
		"winner": "",
		"win_reason": "",
		"visible_cells": [[1, 1]],
		"hidden_detection_cells": [],
		"pieces": [{
			"id": "rp1", "side": "red", "piece_type": "pawn", "position": position,
			"alive": true, "in_reserve": false, "status_tags": [],
		}],
		"flags": [], "walls": [], "casualties": [], "capture_ghosts": [],
		"vision_overlays": {
			"rook_paths": [], "elephant_reveal_zones": [], "elephant_block_fields": [],
		},
		"contact_intel": [],
		"visible_event_cursor": action_index,
	}


func _move_event() -> Dictionary:
	return {
		"schema_version": "veilfront-visible-event-v1",
		"visible_sequence": 1,
		"action_index": 0,
		"event_type": "move_resolved",
		"actor_side_public": "red",
		"position_public": [1, 6],
		"piece_public": {},
		"message_key": "event.move_resolved",
		"public_payload": {},
		"timing_bucket": "standard",
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
