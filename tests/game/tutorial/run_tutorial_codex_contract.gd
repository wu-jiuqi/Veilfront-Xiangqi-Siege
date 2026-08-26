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
	_expect(str(first.get("title", "")) == "棋盘、区域与完整轮", "codex first title is missing")
	_expect(not str(first.get("body", "")).is_empty(), "codex first page lacks a text layer")
	_expect(str(first.get("image_path", "")).ends_with("page_00_board_turns.png"), "codex first image is wrong")
	(codex.get_node("%NextButton") as Button).pressed.emit()
	await _wait_for_image(codex)
	var second := codex.get_public_snapshot()
	_expect(int(second.get("page_index", -1)) == 1, "codex next button did not advance")
	_expect(str(second.get("image_path", "")).ends_with("page_01_pawn.png"), "codex second image is wrong")
	var emissions := {"closed": 0}
	codex.closed.connect(func() -> void: emissions["closed"] += 1)
	(codex.get_node("%CloseButton") as Button).pressed.emit()
	_expect(int(emissions["closed"]) == 1 and not codex.visible, "codex close did not emit and hide")
	codex.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TUTORIAL_CODEX_CONTRACT_PASS pages=18 text_layer=true")
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
