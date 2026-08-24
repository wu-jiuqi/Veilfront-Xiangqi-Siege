class_name ChallengeOpponentPolicy
extends RefCounted

const PlayerViewCodec = preload("res://scripts/game/contracts/player_view_codec.gd")
const ActionPreviewCodec = preload("res://scripts/game/contracts/action_preview_codec.gd")

var _decision_seed: int = 1
var _playable_max_y: int = 16


static func create(decision_seed: int, playable_max_y: int) -> RefCounted:
	if decision_seed <= 0 or playable_max_y < 1 or playable_max_y > 24:
		return null
	var policy := ChallengeOpponentPolicy.new()
	policy._decision_seed = decision_seed
	policy._playable_max_y = playable_max_y
	return policy


func choose_action(player_view: Dictionary, action_previews: Array) -> Dictionary:
	if not bool(PlayerViewCodec.encode(player_view).get("ok", false)) \
	or str(player_view.get("viewer_side", "")) != "black" \
	or str(player_view.get("active_side", "")) != "black":
		return {"ok": false, "error_code": "invalid_public_input", "preview": {}}
	var valid_previews: Array[Dictionary] = []
	for preview_value: Variant in action_previews:
		if not preview_value is Dictionary:
			return {"ok": false, "error_code": "invalid_public_input", "preview": {}}
		var preview: Dictionary = preview_value
		if not bool(ActionPreviewCodec.encode(preview).get("ok", false)):
			return {"ok": false, "error_code": "invalid_public_input", "preview": {}}
		if str(preview.get("action_type", "")) != "move" \
		or str(preview.get("classification", "")) not in ["KNOWN_LEGAL", "TENTATIVE"]:
			continue
		var target: Array = preview.get("target_cell", [])
		if target.size() != 2 or int(target[1]) > _playable_max_y:
			continue
		valid_previews.append(preview.duplicate(true))

	if valid_previews.is_empty():
		for preview_value: Variant in action_previews:
			if preview_value is Dictionary \
			and str(preview_value.get("action_type", "")) == "pass" \
			and str(preview_value.get("classification", "")) == "KNOWN_LEGAL":
				return {"ok": true, "error_code": "", "preview": preview_value.duplicate(true)}
		return {"ok": false, "error_code": "no_public_action", "preview": {}}

	var pieces: Array = player_view.get("pieces", [])
	var action_index := int(player_view.get("action_index", 0))
	valid_previews.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _rank_less(
			_rank_for(left, pieces, action_index),
			_rank_for(right, pieces, action_index),
		)
	)
	return {"ok": true, "error_code": "", "preview": valid_previews[0].duplicate(true)}


func _rank_for(preview: Dictionary, pieces: Array, action_index: int) -> Array:
	var actor := _piece_by_id(pieces, str(preview.get("piece_id", "")))
	var origin := _coordinate(actor.get("position", []))
	var target := _coordinate(preview.get("target_cell", []))
	var actor_threatened := _attacked_by_visible_side(origin, "red", pieces)
	var target_safe := not _attacked_by_visible_side(target, "red", pieces)
	var target_piece := _piece_at(pieces, target)
	var safe_capture := target_safe and not target_piece.is_empty() \
		and str(target_piece.get("side", "")) == "red"
	return [
		0 if actor_threatened else 1,
		0 if target_safe else 1,
		0 if safe_capture else 1,
		0 if str(preview.get("classification", "")) == "KNOWN_LEGAL" else 1,
		_stable_tie(str(preview.get("preview_id", "")), action_index),
		str(preview.get("preview_id", "")),
	]


func _rank_less(left: Array, right: Array) -> bool:
	for index: int in mini(left.size(), right.size()):
		if left[index] == right[index]:
			continue
		return left[index] < right[index]
	return left.size() < right.size()


func _attacked_by_visible_side(target: Vector2i, side: String, pieces: Array) -> bool:
	for piece_value: Variant in pieces:
		if not piece_value is Dictionary:
			continue
		var piece: Dictionary = piece_value
		if str(piece.get("side", "")) != side or not bool(piece.get("alive", false)) \
		or bool(piece.get("in_reserve", false)) or piece.get("position", []).is_empty():
			continue
		if _piece_attacks(piece, target, pieces):
			return true
	return false


func _piece_attacks(piece: Dictionary, target: Vector2i, pieces: Array) -> bool:
	var origin := _coordinate(piece.get("position", []))
	var delta := target - origin
	match str(piece.get("piece_type", "")):
		"rook":
			return (delta.x == 0 or delta.y == 0) and _visible_screen_count(origin, target, pieces) == 0
		"cannon":
			return (delta.x == 0 or delta.y == 0) and _visible_screen_count(origin, target, pieces) == 1
		"horse":
			if not ((absi(delta.x) == 2 and absi(delta.y) == 1) \
			or (absi(delta.x) == 1 and absi(delta.y) == 2)):
				return false
			var leg := origin + (
				Vector2i(signi(delta.x), 0) if absi(delta.x) == 2 \
				else Vector2i(0, signi(delta.y))
			)
			return _piece_at(pieces, leg).is_empty()
		"elephant":
			if absi(delta.x) != 2 or absi(delta.y) != 2:
				return false
			return _piece_at(
				pieces,
				origin + Vector2i(signi(delta.x), signi(delta.y)),
			).is_empty()
		"advisor":
			return absi(delta.x) == 1 and absi(delta.y) == 1
		"general":
			return absi(delta.x) + absi(delta.y) == 1
		"pawn":
			var forward := 1 if str(piece.get("side", "")) == "red" else -1
			return (delta.x == 0 and delta.y == forward) \
				or (absi(delta.x) == 1 and delta.y == 0)
	return false


func _visible_screen_count(origin: Vector2i, target: Vector2i, pieces: Array) -> int:
	if origin == target or (origin.x != target.x and origin.y != target.y):
		return 99
	var direction := Vector2i(signi(target.x - origin.x), signi(target.y - origin.y))
	var cursor := origin + direction
	var count := 0
	while cursor != target:
		if not _piece_at(pieces, cursor).is_empty():
			count += 1
		cursor += direction
	return count


func _piece_by_id(pieces: Array, piece_id: String) -> Dictionary:
	for piece_value: Variant in pieces:
		if piece_value is Dictionary and str(piece_value.get("id", "")) == piece_id:
			return piece_value
	return {}


func _piece_at(pieces: Array, target: Vector2i) -> Dictionary:
	for piece_value: Variant in pieces:
		if piece_value is Dictionary and _coordinate(piece_value.get("position", [])) == target:
			return piece_value
	return {}


func _coordinate(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-99, -99)


func _stable_tie(preview_id: String, action_index: int) -> int:
	var value := posmod(_decision_seed + action_index * 7919, 2147483647)
	for index: int in preview_id.length():
		value = posmod(value * 33 + preview_id.unicode_at(index), 2147483647)
	return value
