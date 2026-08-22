extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")
const TutorialChapterCatalog = preload("res://scripts/game/tutorial/tutorial_chapter_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for level_id: String in TutorialChapterCatalog.TUTORIAL_IDS:
		await _run_chapter(level_id)
	if _failures.is_empty():
		print("ALL_TUTORIAL_FLOWS_PASS chapters=11")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("ALL_TUTORIAL_FLOWS_FAIL failures=%d" % _failures.size())
	quit(1)


func _run_chapter(level_id: String) -> void:
	root.set_meta("veilfront_selected_level_id", level_id)
	var level: Control = TUTORIAL_LEVEL_SCENE.instantiate() as Control
	root.add_child(level)
	await process_frame
	await process_frame
	var screen: Control = level.get_node("MatchScreen") as Control
	var overlay: Control = level.get_node("TutorialOverlay") as Control
	var director: Node = level.get_node("TutorialDirector")
	var presentation: TutorialPresentationTrack = TutorialChapterCatalog.presentation(level_id)

	for step: Dictionary in presentation.steps:
		var checkpoint_before := str(director.get_public_checkpoint_id())
		var step_type := str(step.get("type", ""))
		match step_type:
			"cancel_selection":
				var cancel_origin := _piece_position(screen, str(step.get("actor", "")))
				screen.handle_board_point(cancel_origin)
				screen.handle_cancel_or_marker(cancel_origin)
			"annotate":
				var marker_target: Array = step.get("target", [])
				screen.apply_marker(Vector2i(int(marker_target[0]), int(marker_target[1])), str(step.get("marker", "")))
			"move", "bombard", "reject":
				var action_mode := "move" if step_type == "reject" else step_type
				var action_button: Button = (
					screen.find_child("BombardButton", true, false) if action_mode == "bombard" \
					else screen.find_child("MoveButton", true, false)
				) as Button
				action_button.pressed.emit()
				var origin := _piece_position(screen, str(step.get("actor", "")))
				var target_value: Array = step.get("target", [])
				screen.handle_board_point(origin)
				screen.handle_board_point(Vector2i(int(target_value[0]), int(target_value[1])))
				action_button.pressed.emit()
			"sacrifice_cancel", "sacrifice_confirm":
				screen.find_child("ResurrectButton", true, false).pressed.emit()
				var advisor_origin := _piece_position(screen, str(step.get("actor", "")))
				screen.handle_board_point(advisor_origin)
				if step_type == "sacrifice_cancel":
					screen.handle_cancel_or_marker(advisor_origin)
				else:
					screen.find_child("ResurrectButton", true, false).pressed.emit()
			"predict":
				var predict_target: Array = step.get("target", [])
				screen.handle_board_point(Vector2i(int(predict_target[0]), int(predict_target[1])))
			"observe":
				overlay.find_child("ContinueButton", true, false).pressed.emit()
			"quiz":
				overlay.find_child("Option%d" % int(step.get("correct", 0)), true, false).pressed.emit()
		await process_frame
		await process_frame
		var checkpoint_after := str(director.get_public_checkpoint_id())
		if checkpoint_after == checkpoint_before:
			var snapshot: Dictionary = screen.get_presentation_snapshot()
			_failures.append(
				"%s step %s did not advance; mode=%s state=%s previews=%d prepared=%s" % [
					level_id,
					checkpoint_before,
					str(snapshot.get("action_mode", "")),
					str(snapshot.get("interaction_state", "")),
					int(snapshot.get("preview_count", 0)),
					str(snapshot.get("prepared_preview_id", "")),
				]
			)

	var checkpoint := str(director.get_public_checkpoint_id())
	_expect(
		checkpoint == "completed",
		"%s did not reach chapter completion; stopped_at=%s" % [level_id, checkpoint]
	)
	level.queue_free()
	await process_frame


func _piece_position(screen: Control, piece_id: String) -> Vector2i:
	for piece: Dictionary in screen.get_player_view_snapshot().get("pieces", []):
		if str(piece.get("id", "")) == piece_id:
			var position: Array = piece.get("position", [])
			if position.size() == 2:
				return Vector2i(int(position[0]), int(position[1]))
	_failures.append("piece %s is not present in the current PlayerView" % piece_id)
	return Vector2i.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
