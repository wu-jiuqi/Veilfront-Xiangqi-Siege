extends SceneTree

const Canonical = preload("res://scripts/game/domain/canonical.gd")
const ChallengeCatalog = preload("res://scripts/game/challenge/challenge_catalog.gd")
const ChallengeSession = preload("res://scripts/game/challenge/challenge_session.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for level_id: String in ["C1", "C2", "C3"]:
		var definition: Resource = ChallengeCatalog.definition(level_id)
		var first: RefCounted = ChallengeSession.create(definition)
		var second: RefCounted = ChallengeSession.create(definition)
		for round_index: int in 8:
			var first_payload: Dictionary = first.current_payload()
			var second_payload: Dictionary = second.current_payload()
			_expect(
				Canonical.digest(first_payload) == Canonical.digest(second_payload),
				"%s diverged before round %d" % [level_id, round_index],
			)
			if bool(first_payload.get("player_view", {}).get("terminal", false)):
				break
			var first_pass := _find_pass(first_payload.get("action_previews", []))
			var second_pass := _find_pass(second_payload.get("action_previews", []))
			var first_red: Dictionary = first.submit_preview(first_pass)
			var second_red: Dictionary = second.submit_preview(second_pass)
			_expect(bool(first_red.get("consumed", false)), "%s first red pass failed" % level_id)
			_expect(bool(second_red.get("consumed", false)), "%s second red pass failed" % level_id)
			var first_black: Dictionary = first.advance_scripted_opponent()
			var second_black: Dictionary = second.advance_scripted_opponent()
			_expect(bool(first_black.get("consumed", false)), "%s first opponent action failed" % level_id)
			_expect(bool(second_black.get("consumed", false)), "%s second opponent action failed" % level_id)
			_expect(
				Canonical.digest(first_black) == Canonical.digest(second_black),
				"%s diverged after round %d" % [level_id, round_index],
			)

	if _failures.is_empty():
		print("CHALLENGE_DETERMINISM_PASS levels=3 rounds=8")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("CHALLENGE_DETERMINISM_FAIL failures=%d" % _failures.size())
	quit(1)


func _find_pass(previews: Array) -> Dictionary:
	for preview: Dictionary in previews:
		if str(preview.get("action_type", "")) == "pass":
			return preview
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
