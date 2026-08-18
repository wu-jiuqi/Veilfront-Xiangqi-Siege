class_name TutorialSessionPolicy
extends RefCounted

var _retry_allowed: bool = false
var _skip_allowed: bool = false


func configure(track: TutorialPresentationTrack) -> void:
	_retry_allowed = track != null and track.retry_allowed
	_skip_allowed = track != null and track.skip_allowed


func can_retry() -> bool:
	return _retry_allowed


func can_skip() -> bool:
	return _skip_allowed
