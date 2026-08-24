extends SceneTree

const ChallengeCatalog = preload("res://scripts/game/challenge/challenge_catalog.gd")
const ChallengeSession = preload("res://scripts/game/challenge/challenge_session.gd")

const EXPECTED_BLACK: Dictionary = {
	"C1": [["black-elephant-1", "elephant", [5, 16]]],
	"C2": [
		["black-elephant-1", "elephant", [3, 16]],
		["black-elephant-2", "elephant", [7, 16]],
	],
	"C3": [
		["black-horse-1", "horse", [3, 16]],
		["black-horse-2", "horse", [7, 16]],
	],
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for level_id: String in ["C1", "C2", "C3"]:
		var definition: Resource = ChallengeCatalog.definition(level_id)
		_expect(definition != null and definition.is_valid_definition(), "%s definition is invalid" % level_id)
		if definition == null:
			continue
		var red_count := 0
		var black_records: Array = []
		for piece: Dictionary in definition.initial_pieces:
			if str(piece.get("side", "")) == "red":
				red_count += 1
			else:
				black_records.append([
					str(piece.get("id", "")),
					str(piece.get("piece_type", "")),
					piece.get("position", []).duplicate(),
				])
		_expect(red_count == 16, "%s must contain the full red army" % level_id)
		_expect(black_records == EXPECTED_BLACK[level_id], "%s black force does not match the approved layout" % level_id)

		var session: RefCounted = ChallengeSession.create(definition)
		_expect(session != null, "%s session could not be created" % level_id)
		if session == null:
			continue
		var payload: Dictionary = session.current_payload()
		var view: Dictionary = payload.get("player_view", {})
		_expect(view.get("flags", []).is_empty(), "%s initial PlayerView exposed flags" % level_id)
		_expect(_visible_enemy_count(view) == 0, "%s enemy force must begin inside fog" % level_id)
		_expect(_previews_stay_in_challenge(payload.get("action_previews", [])), "%s offered an action beyond row 16" % level_id)

	if _failures.is_empty():
		print("CHALLENGE_INITIAL_STATE_CONTRACT_PASS levels=3 flags=0 fogged=true")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("CHALLENGE_INITIAL_STATE_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _visible_enemy_count(player_view: Dictionary) -> int:
	var count := 0
	for piece: Dictionary in player_view.get("pieces", []):
		if str(piece.get("side", "")) == "black":
			count += 1
	return count


func _previews_stay_in_challenge(previews: Array) -> bool:
	for preview: Dictionary in previews:
		var target: Array = preview.get("target_cell", [])
		if target.size() == 2 and int(target[1]) > 16:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
