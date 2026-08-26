extends SceneTree

const TutorialChapterCatalog = preload("res://scripts/game/tutorial/tutorial_chapter_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	for level_id: String in TutorialChapterCatalog.TUTORIAL_IDS:
		_check_chapter_resources(level_id)
	_check_t1_fixed_position()
	_check_t10_presentation()
	if _failures.is_empty():
		print("TUTORIAL_CHAPTER_CONTENT_CONTRACT_PASS chapters=18")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_CHAPTER_CONTENT_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_chapter_resources(level_id: String) -> void:
	var slug := level_id.to_lower()
	var authority_path := "res://resources/game/tutorials/authority/%s.tres" % slug
	var presentation_path := "res://resources/game/tutorials/presentation/%s.tres" % slug
	_expect(ResourceLoader.exists(authority_path), "%s authority Resource is missing" % level_id)
	_expect(ResourceLoader.exists(presentation_path), "%s presentation Resource is missing" % level_id)
	if not ResourceLoader.exists(authority_path) or not ResourceLoader.exists(presentation_path):
		return
	var authority: Resource = load(authority_path)
	var presentation: Resource = load(presentation_path)
	_expect(str(authority.get("level_id")) == level_id, "%s authority ID mismatch" % level_id)
	_expect(str(presentation.get("level_id")) == level_id, "%s presentation ID mismatch" % level_id)
	_expect((presentation.get("steps") as Array).size() > 0, "%s has no tutorial steps" % level_id)


func _check_t1_fixed_position() -> void:
	var path := "res://resources/game/tutorials/authority/t1.tres"
	if not ResourceLoader.exists(path):
		return
	var authority: Resource = load(path)
	var positions: Dictionary = {}
	for piece_value: Variant in authority.get("initial_pieces"):
		var piece: Dictionary = piece_value
		positions[str(piece.get("id", ""))] = piece.get("position", [])
	_expect(positions.get("rp1", []) == [5, 10], "T1 red pawn must start at (5,10)")
	_expect(positions.get("bs1", []) == [5, 12], "T1 black pawn must start at (5,12)")
	_expect(positions.get("bc1", []) == [5, 13], "T1 black cannon must start at (5,13)")
	_expect(positions.size() == 4, "T1 must use the four-piece HTML fixed position")


func _check_t10_presentation() -> void:
	var path := "res://resources/game/tutorials/presentation/t10.tres"
	if not ResourceLoader.exists(path):
		return
	var presentation: Resource = load(path)
	_expect(str(presentation.get("title")) == "第一面战旗", "T10 title must match the approved HTML")
	_expect((presentation.get("steps") as Array).size() == 6, "T10 must contain six approved graybox steps")
	var contact_step: Dictionary = (presentation.get("steps") as Array)[1]
	_expect((contact_step.get("targets", []) as Array).size() >= 2, "T10 must keep at least two legal solution variants")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
