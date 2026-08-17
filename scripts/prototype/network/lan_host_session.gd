extends RefCounted

const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const PlayerViewProjector = preload("res://scripts/prototype/view/player_view_projector.gd")
const LanProtocol = preload("res://scripts/prototype/network/lan_protocol.gd")

const HOST_PEER_ID: int = 1
const CLIENT_SIDE: String = MatchState.BLACK

var _full_state: Dictionary = {}
var _prepared_token: String = ""
var _peer_to_side: Dictionary = {}
var _side_to_peer: Dictionary = {}
var _processed_requests: Dictionary = {}
var _remote_seat_claimed: bool = false


func initialize(
	seed_value: int,
	round_limit: int = MatchState.DEFAULT_FULL_ROUND_LIMIT_HYPOTHESIS
) -> Dictionary:
	if round_limit <= 0:
		return _rejected("round_limit_invalid")
	_full_state = RuleEngine.create_match(seed_value, {
		"full_round_limit_hypothesis": round_limit,
	})
	_peer_to_side.clear()
	_side_to_peer.clear()
	_processed_requests.clear()
	_remote_seat_claimed = false
	_assign_peer(HOST_PEER_ID, MatchState.RED)
	_prepare_active_action()
	return {
		"ok": true,
		"host_peer_id": HOST_PEER_ID,
		"host_side": MatchState.RED,
		"action_index": int(_full_state["action_index"]),
	}


func register_remote_peer(peer_id: int) -> Dictionary:
	if _full_state.is_empty():
		return _rejected("session_not_initialized")
	if peer_id <= HOST_PEER_ID:
		return _rejected("peer_id_invalid")
	if _peer_to_side.has(peer_id):
		return {
			"ok": true,
			"peer_id": peer_id,
			"seat": str(_peer_to_side[peer_id]),
			"reused": true,
		}
	if _side_to_peer.has(CLIENT_SIDE):
		return _rejected("room_full")
	if _remote_seat_claimed:
		return _rejected("reconnect_not_supported")
	_assign_peer(peer_id, CLIENT_SIDE)
	_remote_seat_claimed = true
	return {"ok": true, "peer_id": peer_id, "seat": CLIENT_SIDE, "reused": false}


func unregister_peer(peer_id: int) -> void:
	if peer_id == HOST_PEER_ID or not _peer_to_side.has(peer_id):
		return
	var side: String = str(_peer_to_side[peer_id])
	_peer_to_side.erase(peer_id)
	_side_to_peer.erase(side)
	_processed_requests.erase(peer_id)


func has_peer(peer_id: int) -> bool:
	return _peer_to_side.has(peer_id)


func peer_ids() -> Array[int]:
	var result: Array[int] = []
	for peer_id_value: Variant in _peer_to_side.keys():
		result.append(int(peer_id_value))
	result.sort()
	return result


func side_for_peer(peer_id: int) -> String:
	return str(_peer_to_side.get(peer_id, ""))


func player_delivery_for_peer(peer_id: int) -> Dictionary:
	if not _peer_to_side.has(peer_id) or _full_state.is_empty():
		return {}
	var side: String = str(_peer_to_side[peer_id])
	var player_view: Dictionary = PlayerViewProjector.project(_full_state, side)
	return LanProtocol.build_player_delivery(side, player_view)


func submit_request(peer_id: int, request_value: Variant) -> Dictionary:
	if _full_state.is_empty():
		return _rejected("session_not_initialized")
	if not _peer_to_side.has(peer_id):
		return _rejected("peer_not_seated")
	var validation: Dictionary = LanProtocol.validate_action_request(request_value)
	if not bool(validation.get("ok", false)):
		return _rejected(str(validation.get("error", "request_invalid")))
	var request: Dictionary = validation["request"]
	var request_id: String = str(request["request_id"])
	if _request_seen(peer_id, request_id):
		return _rejected("duplicate_request")
	var request_action_index: int = int(request["action_index"])
	if request_action_index != int(_full_state["action_index"]):
		return _rejected("stale_action_index")
	var side: String = str(_peer_to_side[peer_id])
	if side != str(_full_state["active_side"]):
		return _rejected("not_active_side")
	var intent: Dictionary = request["intent"]
	var public_preview: Dictionary = _find_public_preview(side, intent)
	if public_preview.is_empty() \
	or str(public_preview.get("classification", "")) == PlayerViewProjector.KNOWN_ILLEGAL:
		return _rejected("known_illegal")
	var result: Dictionary = RuleEngine.submit_action(_full_state, intent, {
		"preparation_token": _prepared_token,
		"include_state_summary": false,
	})
	if not bool(result.get("consumed", false)):
		return _rejected(_public_rule_error(result))
	_mark_request_seen(peer_id, request_id)
	_prepared_token = ""
	_prepare_active_action()
	var event: Dictionary = result.get("event", {})
	var outcome: Dictionary = event.get("outcome", {})
	return {
		"ok": true,
		"consumed": true,
		"request_id": request_id,
		"actor_side": side,
		"resolved_action_index": request_action_index,
		"next_action_index": int(_full_state["action_index"]),
		"public_code": str(outcome.get("result_code", "")),
		"terminal": bool(_full_state["terminal"]),
	}


func public_session_snapshot() -> Dictionary:
	if _full_state.is_empty():
		return {}
	return {
		"schema_version": "lan-public-session-v1",
		"action_index": int(_full_state["action_index"]),
		"active_side": str(_full_state["active_side"]),
		"terminal": bool(_full_state["terminal"]),
		"seats": _peer_to_side.duplicate(true),
		"remote_reconnect_supported": false,
	}


func _assign_peer(peer_id: int, side: String) -> void:
	_peer_to_side[peer_id] = side
	_side_to_peer[side] = peer_id
	_processed_requests[peer_id] = {}


func _prepare_active_action() -> void:
	if _full_state.is_empty() or bool(_full_state["terminal"]):
		_prepared_token = ""
		return
	var prepared: Dictionary = RuleEngine.prepare_action(_full_state)
	_prepared_token = str(prepared.get("preparation", {}).get("token", "")) \
		if bool(prepared.get("ok", false)) else ""


func _find_public_preview(side: String, intent: Dictionary) -> Dictionary:
	var player_view: Dictionary = PlayerViewProjector.project(_full_state, side)
	return PlayerViewProjector.preview_intent(player_view, intent).duplicate(true)


func _request_seen(peer_id: int, request_id: String) -> bool:
	var peer_requests: Dictionary = _processed_requests.get(peer_id, {})
	return peer_requests.has(request_id)


func _mark_request_seen(peer_id: int, request_id: String) -> void:
	var peer_requests: Dictionary = _processed_requests.get(peer_id, {})
	peer_requests[request_id] = true
	_processed_requests[peer_id] = peer_requests


func _public_rule_error(result: Dictionary) -> String:
	var error_value: Variant = result.get("error", {})
	if error_value is Dictionary:
		return str(error_value.get("category", "rule_rejected"))
	return "rule_rejected"


func _rejected(code: String) -> Dictionary:
	return {"ok": false, "consumed": false, "error": code}
