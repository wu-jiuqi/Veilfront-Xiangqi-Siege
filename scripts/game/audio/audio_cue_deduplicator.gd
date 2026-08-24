class_name AudioCueDeduplicator
extends Node

@export_range(32, 8192, 1) var history_limit: int = 2048

var _seen_batch_digests: Dictionary = {}
var _batch_order: Array[String] = []
var _seen_cue_ids: Dictionary = {}
var _cue_order: Array[String] = []


func accept_batch(batch_digest: String) -> bool:
	if batch_digest.is_empty() or _seen_batch_digests.has(batch_digest):
		return false
	_seen_batch_digests[batch_digest] = true
	_batch_order.append(batch_digest)
	_trim(_seen_batch_digests, _batch_order)
	return true


func accept_cue(cue_id: String) -> bool:
	if cue_id.is_empty() or _seen_cue_ids.has(cue_id):
		return false
	_seen_cue_ids[cue_id] = true
	_cue_order.append(cue_id)
	_trim(_seen_cue_ids, _cue_order)
	return true


func reset_history() -> void:
	_seen_batch_digests.clear()
	_batch_order.clear()
	_seen_cue_ids.clear()
	_cue_order.clear()


func _trim(seen: Dictionary, order: Array[String]) -> void:
	while order.size() > history_limit:
		seen.erase(order.pop_front())
