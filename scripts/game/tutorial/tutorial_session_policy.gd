class_name TutorialSessionPolicy
extends RefCounted

const REQUEST_RESTART: String = "restart"
const REQUEST_SKIP: String = "skip"

var _pending_request: String = ""


func begin_request(request_name: String) -> bool:
	if request_name not in [REQUEST_RESTART, REQUEST_SKIP] or not _pending_request.is_empty():
		return false
	_pending_request = request_name
	return true


func resolve_request(request_name: String) -> bool:
	if request_name != _pending_request:
		return false
	_pending_request = ""
	return true


func clear() -> void:
	_pending_request = ""
