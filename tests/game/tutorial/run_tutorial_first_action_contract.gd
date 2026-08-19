extends SceneTree

const FormalLocalSession = preload("res://scripts/game/application/formal_local_session.gd")
const TutorialChapterCatalog = preload("res://scripts/game/tutorial/tutorial_chapter_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	for level_id: String in TutorialChapterCatalog.TUTORIAL_IDS:
		_check_first_action(level_id)
	if _failures.is_empty():
		print("TUTORIAL_FIRST_ACTION_CONTRACT_PASS chapters=11")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_FIRST_ACTION_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_first_action(level_id: String) -> void:
	var authority: TutorialScenarioDefinition = TutorialChapterCatalog.authority(level_id)
	var presentation: TutorialPresentationTrack = TutorialChapterCatalog.presentation(level_id)
	var session: RefCounted = FormalLocalSession.create_tutorial(authority)
	_expect(session != null, "%s formal tutorial session was not created" % level_id)
	if session == null:
		return
	var first_action: Dictionary = {}
	for step: Dictionary in presentation.steps:
		if str(step.get("type", "")) in ["move", "bombard", "reject"]:
			first_action = step
			break
	_expect(not first_action.is_empty(), "%s has no formal first action" % level_id)
	if first_action.is_empty():
		return
	var expected_action := "move" if str(first_action.get("type", "")) == "reject" else str(first_action.get("type", ""))
	var found := false
	for preview: Dictionary in session.current_payload().get("action_previews", []):
		if str(preview.get("piece_id", "")) == str(first_action.get("actor", "")) \
		and str(preview.get("action_type", "")) == expected_action \
		and preview.get("target_cell", []) == first_action.get("target", []):
			found = true
			break
	_expect(found, "%s first HTML action has no matching formal ActionPreview" % level_id)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
