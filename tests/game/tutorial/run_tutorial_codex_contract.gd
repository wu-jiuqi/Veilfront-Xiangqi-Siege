extends SceneTree

const CODEX_SCENE: PackedScene = preload("res://scenes/game/ui/tutorial_codex.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var codex := CODEX_SCENE.instantiate() as TutorialCodex
	root.add_child(codex)
	await process_frame
	_expect(not codex.visible, "codex must start closed")
	codex.open_codex()
	await _wait_for_image(codex)
	var first := codex.get_public_snapshot()
	_expect(bool(first.get("visible", false)), "codex did not open")
	_expect(int(first.get("page_count", 0)) == 18, "codex must expose 18 pages")
	_expect(str(first.get("title", "")) == "棋盘与一个完整轮", "codex first title is missing")
	_expect(str(first.get("category", "")) == "基础 · 战场", "codex first category is missing")
	_expect(not str(first.get("key_rule", "")).is_empty(), "codex first page lacks a key rule")
	_expect(str(first.get("steps", "")).count("\n") == 2, "codex first page must expose three steps")
	_expect(not str(first.get("pitfall", "")).is_empty(), "codex first page lacks a pitfall explanation")
	_expect(not str(first.get("visual_caption", "")).is_empty(), "codex first page lacks an image caption")
	_expect(str(first.get("image_path", "")).contains("/comic_v2/"), "codex must load the v2 tutorial image set")
	_expect(str(first.get("image_path", "")).ends_with("page_00_board_turns.png"), "codex first image is wrong")
	for expected_index: int in range(1, 18):
		(codex.get_node("%NextButton") as Button).pressed.emit()
		await _wait_for_image(codex)
		var page := codex.get_public_snapshot()
		_expect(int(page.get("page_index", -1)) == expected_index, "codex next button did not advance to %d" % expected_index)
		_expect(not str(page.get("key_rule", "")).is_empty(), "codex page %d lacks a key rule" % expected_index)
		_expect(str(page.get("steps", "")).count("\n") == 2, "codex page %d must expose three steps" % expected_index)
		_expect(not str(page.get("pitfall", "")).is_empty(), "codex page %d lacks a pitfall explanation" % expected_index)
		_expect(not str(page.get("visual_caption", "")).is_empty(), "codex page %d lacks an image caption" % expected_index)
		_expect(str(page.get("image_path", "")).contains("/comic_v2/"), "codex page %d did not load the v2 image set" % expected_index)
	var emissions := {"closed": 0}
	codex.closed.connect(func() -> void: emissions["closed"] += 1)
	(codex.get_node("%CloseButton") as Button).pressed.emit()
	_expect(int(emissions["closed"]) == 1 and not codex.visible, "codex close did not emit and hide")
	codex.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TUTORIAL_CODEX_CONTRACT_PASS pages=18 layers=key,steps,pitfall,caption")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _wait_for_image(codex: TutorialCodex) -> void:
	for _frame: int in 180:
		if not str(codex.get_public_snapshot().get("image_path", "")).is_empty():
			return
		await process_frame
