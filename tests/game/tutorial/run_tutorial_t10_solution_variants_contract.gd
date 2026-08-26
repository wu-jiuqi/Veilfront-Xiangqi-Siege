extends SceneTree

const FormalLocalSession = preload("res://scripts/game/application/formal_local_session.gd")
const Catalog = preload("res://scripts/game/tutorial/tutorial_chapter_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	var presentation: TutorialPresentationTrack = Catalog.presentation("T10")
	var contact_step: Dictionary = presentation.steps[1]
	var targets: Array = contact_step.get("targets", [])
	_expect(targets.size() >= 2, "T10 contact objective must expose at least two solution targets")
	var session: RefCounted = FormalLocalSession.create_tutorial(Catalog.authority("T10"))
	_expect(session != null, "T10 formal session could not be created")
	if session != null:
		var legal_targets: Array = []
		for preview: Dictionary in session.current_payload().get("action_previews", []):
			if str(preview.get("piece_id", "")) == "rr10" \
			and str(preview.get("action_type", "")) == "move" \
			and preview.get("target_cell", []) in targets:
				legal_targets.append(preview.get("target_cell", []))
		_expect(legal_targets.size() >= 2, "T10 declared solution targets are not formal ActionPreviews")
	if _failures.is_empty():
		print("TUTORIAL_T10_SOLUTION_VARIANTS_CONTRACT_PASS variants=%d" % targets.size())
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
