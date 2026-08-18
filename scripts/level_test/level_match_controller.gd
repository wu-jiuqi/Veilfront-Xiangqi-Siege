extends "res://scripts/prototype/match_controller.gd"

const SeededRandom = preload("res://scripts/prototype/core/seeded_random.gd")
const LevelScenario = preload("res://scripts/level_test/level_scenario.gd")
const SafeRandomAi = preload("res://scripts/level_test/safe_random_ai.gd")

@export var safety_profile: Resource

var _level_id: int = 1
var _policy_rng: Dictionary = {}


func initialize(seed_value: int, round_limit: int = -1, selector_id: String = "easy") -> void:
	_level_id = LevelScenario.level_from_selector(selector_id)
	_ai_difficulty_id = selector_id
	_match_seed = seed_value
	_round_limit = LevelScenario.ROUND_LIMIT
	_full_state = MatchState.create(seed_value, {
		"full_round_limit_hypothesis": LevelScenario.ROUND_LIMIT,
	})
	LevelScenario.configure(_full_state, _level_id)
	_match_ai_seed = seed_value + 880021
	_policy_rng = SeededRandom.create_state(seed_value + 991337 + _level_id * 101)
	_ai_memory = _empty_ai_memory()
	_last_ai_decision_audit = {}
	_prepared_token = ""
	_prepare_active_action()
	_publish_human_view()


func get_ai_difficulty_snapshot() -> Dictionary:
	return {
		"difficulty_id": _ai_difficulty_id,
		"profile_id": "level-threat-safe-random-ai-v2",
		"conclusion_status": "owner_requested_level_test",
		"candidate_limit_hypothesis": -1,
		"random_score_span_hypothesis": -1,
		"strategy_mode_hypothesis": "visible-threat-safe-capture-random",
		"level_id": _level_id,
		"level_title": LevelScenario.title(_level_id),
	}


func get_level_status() -> Dictionary:
	var enemy_alive: int = 0
	for piece_value: Variant in _full_state.get("pieces", {}).values():
		var piece: Dictionary = piece_value
		if str(piece.get("side", "")) == MatchState.BLACK \
		and bool(piece.get("alive", false)) and not bool(piece.get("in_reserve", false)):
			enemy_alive += 1
	return {
		"level_id": _level_id,
		"level_title": LevelScenario.title(_level_id),
		"enemy_alive": enemy_alive,
		"enemy_total": LevelScenario.enemy_count(_level_id),
	}


func submit_human_intent(intent: Dictionary) -> Dictionary:
	if not can_human_submit():
		return {"ok": false, "consumed": false, "error": "human_input_not_available"}
	var public_preview: Dictionary = _find_public_preview(intent)
	if public_preview.is_empty() \
	or public_preview["classification"] == PlayerViewProjector.KNOWN_ILLEGAL:
		return {"ok": false, "consumed": false, "error": "known_illegal"}
	var result: Dictionary = RuleEngine.submit_action(_full_state, intent, {
		"preparation_token": _prepared_token,
		"include_state_summary": false,
	})
	if bool(result.get("consumed", false)):
		_prepared_token = ""
		_apply_objective_terminal()
		_prepare_active_action()
	_publish_human_view()
	var feedback: Dictionary = {
		"ok": bool(result.get("ok", false)),
		"consumed": bool(result.get("consumed", false)),
		"source": "human",
		"public_code": "",
	}
	if bool(result.get("consumed", false)):
		var events: Array = _human_view.get("player_events", [])
		if not events.is_empty():
			feedback["public_code"] = str(events.back().get("public_code", ""))
	action_feedback.emit(feedback.duplicate(true))
	return feedback


func step_ai() -> Dictionary:
	if not can_step_ai():
		return {"ok": false, "consumed": false, "error": "ai_step_not_available"}
	if safety_profile == null:
		return {"ok": false, "consumed": false, "error": "safety_profile_missing"}
	var ai_side: String = str(_full_state["active_side"])
	var ai_player_view: Dictionary = PlayerViewProjector.project(_full_state, ai_side)
	var previews: Array = PlayerViewProjector.generate_action_intents(ai_player_view)
	var projection: Dictionary = PlayerViewProjector.export_ai_projection_from_view(ai_player_view)
	var public_rules: RefCounted = AiPublicRules.new(_public_ai_rules())
	var decision: Dictionary = SafeRandomAi.choose(
		projection,
		_policy_rng,
		public_rules,
		safety_profile
	)
	if not bool(decision.get("ok", false)):
		return {"ok": false, "consumed": false, "error": str(decision.get("error", "ai_decision_failed"))}
	var selected_action: Dictionary = decision["action"]
	var selected_id: String = str(selected_action.get("id", ""))
	var mapping: Dictionary = _map_ai_action_or_error(previews, selected_id)
	if not bool(mapping.get("ok", false)):
		return mapping
	_last_ai_decision_audit = decision["audit"].duplicate(true)
	_last_ai_decision_audit["controller_context"] = {
		"level_id": _level_id,
		"input_projection_digest": Canonical.digest(projection),
		"selected_action_id": selected_id,
		"action_id_mapped": true,
		"uses_player_view_only": true,
	}
	var result: Dictionary = RuleEngine.submit_action(_full_state, mapping["intent"], {
		"preparation_token": _prepared_token,
		"include_state_summary": false,
	})
	if not bool(result.get("consumed", false)):
		return {"ok": false, "consumed": false, "error": "ai_intent_not_consumed"}
	_prepared_token = ""
	_apply_objective_terminal()
	_prepare_active_action()
	_publish_human_view()
	var feedback: Dictionary = {
		"ok": true,
		"consumed": true,
		"source": "ai",
		"level_id": _level_id,
	}
	action_feedback.emit(feedback.duplicate(true))
	return feedback


func get_scenario_snapshot_for_test() -> Dictionary:
	var red_pieces: Array = []
	var black_pieces: Array = []
	for piece_value: Variant in _full_state.get("pieces", {}).values():
		var piece: Dictionary = piece_value
		if not bool(piece.get("alive", false)) or bool(piece.get("in_reserve", false)):
			continue
		var record: Dictionary = {
			"id": str(piece["id"]),
			"side": str(piece["side"]),
			"piece_type": str(piece["piece_type"]),
			"position": piece["position"].duplicate(),
		}
		if str(piece["side"]) == MatchState.RED:
			red_pieces.append(record)
		else:
			black_pieces.append(record)
	red_pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	black_pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return {
		"level_id": _level_id,
		"level_title": LevelScenario.title(_level_id),
		"round_limit": int(_full_state["configuration"]["full_round_limit_hypothesis"]),
		"flags": _full_state["flags"].duplicate(true),
		"red_pieces": red_pieces,
		"black_pieces": black_pieces,
		"terminal": bool(_full_state["terminal"]),
		"winner": str(_full_state["winner"]),
		"win_reason": str(_full_state["win_reason"]),
	}


func _publish_human_view() -> void:
	if _full_state.is_empty():
		_human_view = {}
		_human_previews = []
	else:
		_human_view = PlayerViewProjector.project(_full_state, human_side).duplicate(true)
		_filter_player_view_to_playable_area(_human_view)
		_human_previews = []
		for preview: Dictionary in PlayerViewProjector.generate_action_intents(_human_view):
			if _preview_is_inside_playable_area(preview):
				_human_previews.append(preview.duplicate(true))
	human_view_updated.emit(_human_view.duplicate(true))


func _apply_objective_terminal() -> void:
	if bool(_full_state.get("terminal", false)):
		var reason: String = str(_full_state.get("win_reason", ""))
		if reason.begins_with("round_limit"):
			_full_state["winner"] = MatchState.BLACK
			_full_state["win_reason"] = "objective_timeout"
		return
	for piece_value: Variant in _full_state.get("pieces", {}).values():
		var piece: Dictionary = piece_value
		if str(piece.get("side", "")) == MatchState.BLACK \
		and bool(piece.get("alive", false)) and not bool(piece.get("in_reserve", false)):
			return
	_full_state["terminal"] = true
	_full_state["winner"] = MatchState.RED
	_full_state["win_reason"] = "all_enemies_destroyed"


func _preview_is_inside_playable_area(preview: Dictionary) -> bool:
	var action_type: String = str(preview.get("action_type", ""))
	if action_type in ["pass", "resurrect"]:
		return true
	return LevelScenario.is_inside_playable_area(preview.get("target_cell", []))


func _filter_player_view_to_playable_area(view: Dictionary) -> void:
	view["visible_cells"] = _filter_cells(view.get("visible_cells", []))
	view["hidden_detection_cells"] = _filter_cells(view.get("hidden_detection_cells", []))
	for key: String in ["pieces", "capture_ghosts", "contact_intel"]:
		var records: Array = []
		for record: Dictionary in view.get(key, []):
			var position: Array = record.get("position", record.get("cell", []))
			if position.is_empty() or LevelScenario.is_inside_playable_area(position):
				records.append(record)
		view[key] = records
	var overlays: Dictionary = view.get("vision_overlays", {})
	for overlay_key: String in ["rook_paths", "elephant_reveal_zones", "elephant_block_fields"]:
		for source: Dictionary in overlays.get(overlay_key, []):
			source["cells"] = _filter_cells(source.get("cells", []))


func _filter_cells(cells: Array) -> Array:
	var result: Array = []
	for cell: Array in cells:
		if LevelScenario.is_inside_playable_area(cell):
			result.append(cell.duplicate())
	return result
