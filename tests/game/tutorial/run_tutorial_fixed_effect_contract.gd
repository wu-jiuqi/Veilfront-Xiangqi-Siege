extends SceneTree

const LEVEL_SCENE: PackedScene = preload("res://scenes/game/tutorial/tutorial_level.tscn")
const Catalog = preload("res://scripts/game/tutorial/tutorial_chapter_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for level_id: String in Catalog.TUTORIAL_IDS:
		await _run_chapter(level_id)
	if _failures.is_empty():
		print("TUTORIAL_FIXED_EFFECT_CONTRACT_PASS chapters=11")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TUTORIAL_FIXED_EFFECT_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _run_chapter(level_id: String) -> void:
	root.set_meta("veilfront_selected_level_id", level_id)
	var level: Control = LEVEL_SCENE.instantiate() as Control
	root.add_child(level)
	await process_frame
	await process_frame
	var screen: Control = level.get_node("MatchScreen") as Control
	var overlay: Control = level.get_node("TutorialOverlay") as Control
	for step: Dictionary in Catalog.presentation(level_id).steps:
		await _perform(screen, overlay, step)
		_assert_step_effect(level_id, str(step.get("id", "")), screen.get_player_view_snapshot())
	level.queue_free()
	await process_frame


func _perform(screen: Control, overlay: Control, step: Dictionary) -> void:
	var kind := str(step.get("type", ""))
	match kind:
		"cancel_selection":
			var origin := _piece_cell(screen, str(step.get("actor", "")))
			screen.handle_board_point(origin)
			screen.handle_cancel_or_marker(origin)
		"annotate":
			var target: Array = step.get("target", [])
			screen.apply_marker(Vector2i(int(target[0]), int(target[1])), str(step.get("marker", "")))
		"move", "bombard", "reject":
			var origin := _piece_cell(screen, str(step.get("actor", "")))
			var target: Array = step.get("target", [])
			if kind != "bombard":
				(screen.find_child("MoveButton", true, false) as Button).pressed.emit()
			screen.handle_board_point(origin)
			if kind == "bombard":
				(screen.find_child("SkillButton", true, false) as Button).pressed.emit()
			screen.handle_board_point(Vector2i(int(target[0]), int(target[1])))
			var confirm_button_name := "SkillButton" if kind == "bombard" else "MoveButton"
			(screen.find_child(confirm_button_name, true, false) as Button).pressed.emit()
		"predict":
			var target: Array = step.get("target", [])
			screen.handle_board_point(Vector2i(int(target[0]), int(target[1])))
		"observe":
			overlay.find_child("ContinueButton", true, false).pressed.emit()
		"sacrifice_cancel", "sacrifice_confirm":
			overlay.find_child("ContinueButton", true, false).pressed.emit()
			var origin := _piece_cell(screen, str(step.get("actor", "")))
			screen.handle_board_point(origin)
			if kind == "sacrifice_cancel":
				screen.handle_cancel_or_marker(origin)
			else:
				(screen.find_child("SkillButton", true, false) as Button).pressed.emit()
		"quiz":
			overlay.find_child("Option%d" % int(step.get("correct", 0)), true, false).pressed.emit()
	await process_frame
	await process_frame


func _assert_step_effect(level_id: String, step_id: String, view: Dictionary) -> void:
	match step_id:
		"t0_move":
			_expect(_piece_cell_from_view(view, "rp0") == Vector2i(5, 5), "T0 pawn did not reach tutorial target")
		"t1_cross":
			_expect(_piece_cell_from_view(view, "rp1") == Vector2i(5, 15), "T1 pawn did not complete pass-through")
			_expect(not _piece(view, "bs1").is_empty() and not _piece(view, "bc1").is_empty(), "T1 pass-through incorrectly captured path pieces")
		"t2_hide":
			_expect(_piece(view, "rh2b").get("status_tags", []).has("hidden"), "T2 horse did not enter hidden state")
		"t2_observe":
			_expect(not _piece(view, "rh2b").get("status_tags", []).has("hidden"), "T2 elephant field did not reveal horse")
		"t3_rook":
			_expect(_piece_cell_from_view(view, "br3") == Vector2i(5, 11), "T3 rook did not stop at first field point")
		"t3_pawn":
			_expect(_piece_cell_from_view(view, "bp3") == Vector2i(4, 12), "T3 pawn did not stop at first field point")
		"t3_friend":
			_expect(_piece_cell_from_view(view, "rr3") == Vector2i(7, 10), "T3 friendly rook did not cross field")
		"t4_hidden":
			_expect(_piece_cell_from_view(view, "rr4b") == Vector2i(6, 12), "T4 rook did not stop on hidden contact")
			_expect(_piece(view, "bh4").is_empty(), "T4 hidden horse survived contact")
		"t4_ghost":
			_expect(not view.get("capture_ghosts", []).is_empty(), "T4 scripted casualty has no ghost")
		"t5_bombard":
			_expect(_piece(view, "bp5").is_empty() and _piece(view, "friend5").get("alive", true) == false and _piece(view, "bh5").is_empty(), "T5 fixed bombardment casualties differ from proposal")
		"t6_confirm":
			_expect(_piece(view, "ra6").get("alive", true) == false, "T6 advisor was not sacrificed")
			_expect(bool(_piece(view, "dead-rook-6").get("alive", false)) or bool(_piece(view, "dead-pawn-6").get("alive", false)), "T6 did not revive an eligible casualty")
		"t7_capture":
			_expect(bool(view.get("terminal", false)) and str(view.get("winner", "")) == "red", "T7 actual general death did not end match")
		"t8_breach":
			_expect(_wall_status(view, "black") == "BREACHED", "T8 black wall did not breach")
		"t8_base":
			_expect(_piece_cell_from_view(view, "rr8") == Vector2i(2, 23) and _piece(view, "bc8").is_empty(), "T8 base attack did not resolve")
		"t9_capture", "t10_capture":
			_expect(_first_flag(view).get("capture_progress", 0) == 1, "%s capture did not start at 1/3" % level_id)
		"t9_wait1", "t10_hold":
			_expect(_first_flag(view).get("capture_progress", 0) == 2, "%s capture did not advance to 2/3" % level_id)
		"t9_wait2", "t10_finish":
			_expect(str(_first_flag(view).get("owner", "")) == "red", "%s flag was not captured at 3/3" % level_id)
		"t10_contact":
			_expect(_piece_cell_from_view(view, "rr10") == Vector2i(2, 12), "T10 rook did not stop on hidden horse")
		"t10_bombard":
			_expect(_piece(view, "bp10").is_empty() and _piece(view, "bc10").is_empty(), "T10 fixed bombardment did not clear threats")


func _piece_cell(screen: Control, piece_id: String) -> Vector2i:
	return _piece_cell_from_view(screen.get_player_view_snapshot(), piece_id)


func _piece_cell_from_view(view: Dictionary, piece_id: String) -> Vector2i:
	return BoardCoordinateMapper.coordinate_from_variant(_piece(view, piece_id).get("position", []))


func _piece(view: Dictionary, piece_id: String) -> Dictionary:
	for piece: Dictionary in view.get("pieces", []):
		if str(piece.get("id", "")) == piece_id:
			return piece
	return {}


func _first_flag(view: Dictionary) -> Dictionary:
	return view.get("flags", [])[0] if not view.get("flags", []).is_empty() else {}


func _wall_status(view: Dictionary, side: String) -> String:
	for wall: Dictionary in view.get("walls", []):
		if str(wall.get("side", "")) == side:
			return str(wall.get("status", ""))
	return ""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
