extends SceneTree

const FRONTEND_AUDIO_SCENE := preload("res://scenes/game/audio/frontend_audio_feedback.tscn")
const START_SCREEN_SCENE := preload("res://scenes/game/frontend/start_screen.tscn")
const SETTINGS_SCENE := preload("res://scenes/game/frontend/settings_screen.tscn")
const LEVEL_SELECT_SCENE := preload("res://scenes/game/frontend/level_select.tscn")
const LAN_LOBBY_SCENE := preload("res://scenes/game/frontend/formal_lan_lobby.tscn")
const FORMAL_APP_SCENE := preload("res://scenes/game/app/formal_lan_game_app.tscn")
const GAME_APP_SCENE := preload("res://scenes/game/app/game_app.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_scene_mounts()
	_check_opening_timeline()
	await _check_frontend_runtime()
	await _check_opening_audio_guard()
	print("FRONTEND_AUDIO_FEEDBACK_PASS scenes=6 opening_cues=4 opening_bgm=timeline_guarded dynamic_buttons=true modal_edges=true skip_guard=true")
	quit()


func _check_scene_mounts() -> void:
	for scene: PackedScene in [START_SCREEN_SCENE, SETTINGS_SCENE, LEVEL_SELECT_SCENE, LAN_LOBBY_SCENE]:
		var instance := scene.instantiate()
		var feedback_nodes := instance.find_children("FrontendAudioFeedback", "", true, false)
		assert(feedback_nodes.size() == 1, "%s must contain exactly one preset frontend audio node" % scene.resource_path)
		assert(feedback_nodes[0].get_node_or_null("AudioRoot") is VeilfrontAudioRoot)
		instance.free()
	for scene: PackedScene in [FORMAL_APP_SCENE, GAME_APP_SCENE]:
		var instance := scene.instantiate()
		var overlay_feedback := instance.get_node("GlobalOverlayAudioFeedback") as FrontendAudioFeedback
		assert(overlay_feedback != null, "%s must cover application-level dialogs" % scene.resource_path)
		assert(overlay_feedback.control_root_path == NodePath("../GlobalOverlayHost"), "application audio must stay scoped to global dialogs")
		instance.free()


func _check_opening_timeline() -> void:
	var start_screen := START_SCREEN_SCENE.instantiate()
	var player := start_screen.get_node("SequencePlayer") as AnimationPlayer
	var animation := player.get_animation(&"opening_sequence")
	var method_track := -1
	for track_index: int in animation.get_track_count():
		if animation.track_get_type(track_index) == Animation.TYPE_METHOD:
			method_track = track_index
			break
	assert(method_track >= 0, "opening sequence must own a method track for exact SFX timing")
	var expected_times: Array[float] = [0.32, 0.72, 1.45, 4.65]
	var expected_keys: Array[String] = [
		"sfx.opening.gate_strain", "sfx.opening.gate_open",
		"sfx.opening.fog_reveal", "sfx.opening.menu_reveal",
	]
	assert(animation.track_get_key_count(method_track) == expected_times.size())
	for key_index: int in expected_times.size():
		assert(is_equal_approx(animation.track_get_key_time(method_track, key_index), expected_times[key_index]))
		var method_value: Dictionary = animation.track_get_key_value(method_track, key_index)
		assert(method_value.get("method") == &"_play_opening_cue")
		assert(method_value.get("args", [])[0] == expected_keys[key_index])
	start_screen.free()


func _check_frontend_runtime() -> void:
	var host := Control.new()
	root.add_child(host)
	var static_button := Button.new()
	static_button.name = "ApplyButton"
	host.add_child(static_button)
	var feedback := FRONTEND_AUDIO_SCENE.instantiate() as FrontendAudioFeedback
	feedback.dry_run = true
	host.add_child(feedback)
	await process_frame
	var played: Array[String] = []
	feedback.audio_root().cue_played.connect(func(cue: Dictionary) -> void:
		played.append(str(cue.get("cue_key", "")))
	)
	feedback.refresh_bindings()
	static_button.focus_entered.emit()
	static_button.pressed.emit()
	assert(played == ["sfx.ui.focus", "sfx.ui.confirm"], "static frontend button must emit focus and semantic confirm cues")

	var dynamic_button := Button.new()
	dynamic_button.name = "BackButton"
	host.add_child(dynamic_button)
	await process_frame
	dynamic_button.pressed.emit()
	assert(played.back() == "sfx.ui.cancel", "dynamic frontend buttons must be bound without runtime node creation")

	var dialog_scene := load("res://scenes/game/ui/terracotta_modal_dialog.tscn") as PackedScene
	var dialog := dialog_scene.instantiate() as TerracottaModalDialog
	host.add_child(dialog)
	await process_frame
	dialog.show()
	dialog.hide()
	assert(played.has("sfx.ui.modal_open") and played.has("sfx.ui.modal_close"), "modal visibility edges must emit open and close cues")
	host.queue_free()
	await process_frame


func _check_opening_audio_guard() -> void:
	var start_screen := START_SCREEN_SCENE.instantiate() as Control
	var feedback := start_screen.get_node("FrontendAudioFeedback") as FrontendAudioFeedback
	var sequence_player := start_screen.get_node("SequencePlayer") as AnimationPlayer
	var opening_music := start_screen.get_node("OpeningMusic") as AudioStreamPlayer
	feedback.dry_run = true
	root.add_child(start_screen)
	await process_frame
	var played: Array[String] = []
	feedback.audio_root().cue_played.connect(func(cue: Dictionary) -> void:
		played.append(str(cue.get("cue_key", "")))
	)
	start_screen.set("_opening_audio_enabled", false)
	start_screen.call("_play_opening_cue", "sfx.opening.gate_open")
	assert(played.is_empty(), "menu-ready and reduced-motion paths must not burst opening cues")
	start_screen.set("_opening_audio_enabled", true)
	start_screen.call("_play_opening_cue", "sfx.opening.gate_open")
	assert(played == ["sfx.opening.gate_open"], "normal opening path must forward its timeline cue")
	start_screen.call(&"request_entry")
	sequence_player.advance(0.02)
	assert(opening_music.playing, "normal opening path must start its timeline BGM")
	start_screen.call(&"_enter_menu_ready_immediately")
	assert(not opening_music.playing, "menu-ready and reduced-motion paths must stop the opening BGM")
	start_screen.queue_free()
	await process_frame
