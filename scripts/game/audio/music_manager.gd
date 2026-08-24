class_name VeilfrontMusicManager
extends Node

const START_SCREEN_SCENE: String = "res://scenes/game/frontend/start_screen.tscn"

@export var excluded_scene_paths: PackedStringArray = PackedStringArray([START_SCREEN_SCENE])

@onready var _music_player: AudioStreamPlayer = %MusicPlayer


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	_sync_current_scene.call_deferred()


func sync_for_scene(scene_path: String) -> void:
	if scene_path.is_empty() or excluded_scene_paths.has(scene_path):
		if _music_player.playing:
			_music_player.stop()
		return
	if not _music_player.playing:
		_music_player.play()


func is_scene_excluded(scene_path: String) -> bool:
	return excluded_scene_paths.has(scene_path)


func _on_scene_changed() -> void:
	_sync_current_scene()


func _sync_current_scene() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	sync_for_scene(scene.scene_file_path)
