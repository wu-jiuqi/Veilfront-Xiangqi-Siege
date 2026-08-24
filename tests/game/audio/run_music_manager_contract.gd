extends SceneTree

const START_SCREEN_SCENE := "res://scenes/game/frontend/start_screen.tscn"
const SETTINGS_SCENE := "res://scenes/game/frontend/settings_screen.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/game/frontend/level_select.tscn"
const RUNTIME_BGM := "res://assets/audio/bgm/bgm_match_standard_loop_v01.ogg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("MusicManager") as VeilfrontMusicManager
	assert(manager != null, "MusicManager autoload must instantiate from its preset scene")
	var player := manager.get_node("%MusicPlayer") as AudioStreamPlayer
	assert(player != null, "MusicManager must preset one non-positional music player")
	assert(player.bus == &"Music", "shared BGM must route through the Music bus")
	assert(player.stream != null and player.stream.resource_path == RUNTIME_BGM)
	var ogg_stream := player.stream as AudioStreamOggVorbis
	assert(ogg_stream != null, "runtime BGM must use OGG Vorbis")
	assert(ogg_stream.loop, "runtime BGM must loop on the AudioStream resource")
	assert(is_zero_approx(ogg_stream.loop_offset), "shared BGM loop must restart from sample zero")
	assert(manager.is_scene_excluded(START_SCREEN_SCENE))
	assert(not manager.is_scene_excluded(SETTINGS_SCENE))

	assert(change_scene_to_file(START_SCREEN_SCENE) == OK)
	await scene_changed
	await process_frame
	assert(not player.playing, "start screen and start menu must remain silent")
	assert(change_scene_to_file(SETTINGS_SCENE) == OK)
	await scene_changed
	await process_frame
	assert(player.playing, "settings and all non-start regions must share the BGM")
	player.seek(5.0)
	var position_before_route_change := player.get_playback_position()
	assert(change_scene_to_file(LEVEL_SELECT_SCENE) == OK)
	await scene_changed
	await process_frame
	var position_after_route_change := player.get_playback_position()
	assert(player.playing)
	assert(
		position_after_route_change >= position_before_route_change - 0.5,
		"routing between non-start regions must not restart the shared BGM"
	)
	assert(change_scene_to_file(START_SCREEN_SCENE) == OK)
	await scene_changed
	await process_frame
	assert(not player.playing, "returning to the start menu must stop the shared BGM")
	var loaded_scene := current_scene
	current_scene = null
	loaded_scene.queue_free()
	player.stream = null
	ogg_stream = null
	player = null
	manager.queue_free()
	manager = null
	for _frame: int in 3:
		await process_frame
	await create_timer(0.1).timeout
	print("MUSIC_MANAGER_CONTRACT_PASS format=ogg loop=true shared_regions=true start_menu=silent")
	quit(0)
