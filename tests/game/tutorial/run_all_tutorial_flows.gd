extends SceneTree

const TUTORIAL_LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")
const TutorialChapterCatalog = preload("res://scripts/game/tutorial/tutorial_chapter_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level_ids := TutorialChapterCatalog.TUTORIAL_IDS.duplicate()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			level_ids = [argument.trim_prefix("--level=").to_upper()]
	for level_id: String in level_ids:
		print("TUTORIAL_FLOW_STAGE chapter=%s" % level_id)
		await _run_chapter(level_id)
	if _failures.is_empty():
		print("ALL_TUTORIAL_FLOWS_PASS chapters=%d" % level_ids.size())
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
		print("TUTORIAL_FLOW_STAGE chapter=%s step=%s type=%s" % [level_id, checkpoint_before, step_type])
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
				var origin := _piece_position(screen, str(step.get("actor", "")))
				var target_value: Array = step.get("target", [])
				if action_mode == "move":
					(screen.find_child("MoveButton", true, false) as Button).pressed.emit()
				screen.handle_board_point(origin)
				if action_mode == "bombard":
					(screen.find_child("SkillButton", true, false) as Button).pressed.emit()
				screen.handle_board_point(Vector2i(int(target_value[0]), int(target_value[1])))
				var confirm_button_name := "SkillButton" if action_mode == "bombard" else "MoveButton"
				var confirm_button := screen.find_child(confirm_button_name, true, false) as Button
				var expected_text := "确认轰炸" if action_mode == "bombard" else "确认移动"
				_expect(
					confirm_button != null and confirm_button.text == expected_text and not confirm_button.disabled,
					"%s step %s did not expose enabled inline %s confirmation" % [
						level_id,
						checkpoint_before,
						action_mode,
					]
				)
				if confirm_button != null:
					confirm_button.pressed.emit()
			"sacrifice_cancel", "sacrifice_confirm":
				overlay.find_child("ContinueButton", true, false).pressed.emit()
				var advisor_origin := _piece_position(screen, str(step.get("actor", "")))
				screen.handle_board_point(advisor_origin)
				if step_type == "sacrifice_cancel":
					screen.handle_cancel_or_marker(advisor_origin)
				else:
					var sacrifice_confirm := screen.find_child("SkillButton", true, false) as Button
					_expect(
						sacrifice_confirm != null
						and sacrifice_confirm.text == "确认复活"
						and not sacrifice_confirm.disabled,
						"%s step %s did not expose enabled inline sacrifice confirmation" % [
							level_id,
							checkpoint_before,
						]
					)
					if sacrifice_confirm != null:
						sacrifice_confirm.pressed.emit()
			"predict":
				var predict_target: Array = step.get("target", [])
				screen.handle_board_point(Vector2i(int(predict_target[0]), int(predict_target[1])))
			"observe":
				overlay.find_child("ContinueButton", true, false).pressed.emit()
			"quiz":
				var options_value: Variant = step.get("options", [])
				var options: Array = options_value if options_value is Array else []
				for option_index: int in mini(options.size(), 3):
					var option_button := overlay.find_child(
						"Option%d" % option_index,
						true,
						false
					) as Button
					_expect(
						option_button != null and option_button.visible and not option_button.disabled,
						"%s step %s did not expose quiz option %d" % [
							level_id,
							checkpoint_before,
							option_index,
						]
					)
				var correct_button := overlay.find_child(
					"Option%d" % int(step.get("correct", 0)),
					true,
					false
				) as Button
				if correct_button != null:
					correct_button.pressed.emit()
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
