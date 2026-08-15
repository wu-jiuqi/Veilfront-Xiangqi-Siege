extends Node

const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const PlayerViewProjector = preload("res://scripts/prototype/view/player_view_projector.gd")

signal human_view_updated(player_view: Dictionary)

@export var human_side: String = MatchState.RED

var _full_state: Dictionary = {}


func initialize(seed_value: int) -> void:
	_full_state = MatchState.create(seed_value)
	human_view_updated.emit(get_human_player_view())


func get_human_player_view() -> Dictionary:
	if _full_state.is_empty():
		return {}
	return PlayerViewProjector.project(_full_state, human_side).duplicate(true)
