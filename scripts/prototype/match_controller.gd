extends Node

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const PlayerViewProjector = preload("res://scripts/prototype/view/player_view_projector.gd")
const AiPlayerView = preload("res://scripts/prototype/ai/ai_player_view.gd")
const AiPublicRules = preload("res://scripts/prototype/ai/ai_public_rules.gd")
const AiMemory = preload("res://scripts/prototype/ai/ai_memory.gd")
const AiDecisionEngine = preload("res://scripts/prototype/ai/ai_decision_engine.gd")
const AiSeedDeriver = preload("res://scripts/prototype/ai/ai_seed_deriver.gd")

signal human_view_updated(player_view: Dictionary)
signal action_feedback(feedback: Dictionary)

@export var human_side: String = MatchState.RED
@export var default_full_round_limit_hypothesis: int = MatchState.DEFAULT_FULL_ROUND_LIMIT_HYPOTHESIS
@export var ai_easy_profile: Resource
@export var ai_medium_profile: Resource
@export var ai_hard_profile: Resource
@export var ai_expert_profile: Resource

var _full_state: Dictionary = {}
var _prepared_token: String = ""
var _human_view: Dictionary = {}
var _human_previews: Array = []
var _match_ai_seed: int = 0
var _ai_memory: Dictionary = {}
var _ai_difficulty_id: String = "medium"
var _last_ai_decision_audit: Dictionary = {}


func initialize(seed_value: int, round_limit: int = -1, difficulty_id: String = "") -> void:
	if not difficulty_id.is_empty():
		assert(set_ai_difficulty(difficulty_id))
	var effective_limit: int = default_full_round_limit_hypothesis if round_limit <= 0 else round_limit
	_full_state = MatchState.create(seed_value, {
		"full_round_limit_hypothesis": effective_limit,
	})
	_match_ai_seed = seed_value + 880021
	_ai_memory = _empty_ai_memory()
	_last_ai_decision_audit = {}
	_prepared_token = ""
	_prepare_active_action()
	_publish_human_view()


func restart_same_seed() -> void:
	if _human_view.is_empty():
		return
	initialize(
		int(_human_view["match_seed"]),
		int(_human_view["full_round_limit_hypothesis"]),
		_ai_difficulty_id
	)


func get_human_player_view() -> Dictionary:
	return _human_view.duplicate(true)


func get_human_action_previews() -> Array:
	return _human_previews.duplicate(true)


func set_ai_difficulty(difficulty_id: String) -> bool:
	if difficulty_id not in ["easy", "medium", "hard", "expert"]:
		return false
	_ai_difficulty_id = difficulty_id
	return _profile_for_difficulty() != null


func get_ai_difficulty_snapshot() -> Dictionary:
	var profile: Resource = _profile_for_difficulty()
	if profile == null:
		return {}
	return {
		"difficulty_id": _ai_difficulty_id,
		"profile_id": str(profile.profile_id),
		"conclusion_status": str(profile.conclusion_status),
		"candidate_limit_hypothesis": int(profile.candidate_limit),
		"random_score_span_hypothesis": int(profile.random_score_span),
		"strategy_mode_hypothesis": str(profile.strategy_mode),
	}


# Controlled non-UI test evidence. The UI adapter must never call this method
# or forward the returned audit into PlayerView, signals, screenshots or logs.
func get_last_ai_decision_audit_for_test() -> Dictionary:
	return _last_ai_decision_audit.duplicate(true)


func can_human_submit() -> bool:
	return not _human_view.is_empty() and not bool(_human_view["terminal"]) \
		and str(_human_view["active_side"]) == human_side and not _prepared_token.is_empty()


func can_step_ai() -> bool:
	return not _human_view.is_empty() and not bool(_human_view["terminal"]) \
		and str(_human_view["active_side"]) != human_side and not _prepared_token.is_empty()


func submit_human_intent(intent: Dictionary) -> Dictionary:
	if not can_human_submit():
		return {"ok": false, "consumed": false, "error": "human_input_not_available"}
	var public_preview: Dictionary = _find_public_preview(intent)
	if public_preview.is_empty() or public_preview["classification"] == PlayerViewProjector.KNOWN_ILLEGAL:
		return {"ok": false, "consumed": false, "error": "known_illegal"}
	var result: Dictionary = RuleEngine.submit_action(_full_state, intent, {
		"preparation_token": _prepared_token,
		"include_state_summary": false,
	})
	if bool(result.get("consumed", false)):
		_prepared_token = ""
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
	var ai_side: String = str(_full_state["active_side"])
	var ai_player_view: Dictionary = PlayerViewProjector.project(_full_state, ai_side)
	var previews: Array = PlayerViewProjector.generate_action_intents(ai_player_view)
	var projection: Dictionary = PlayerViewProjector.export_ai_projection_from_view(ai_player_view)
	var ai_view: RefCounted = AiPlayerView.new(projection)
	var public_rules: RefCounted = AiPublicRules.new(_public_ai_rules())
	var memory: RefCounted = AiMemory.new(_ai_memory)
	var config: Resource = _profile_for_difficulty()
	if config == null:
		return {"ok": false, "consumed": false, "error": "ai_profile_missing"}
	var decision_id: String = str(projection["decision_id"])
	var ai_seed: int = AiSeedDeriver.derive(_match_ai_seed, decision_id)
	var decision: Dictionary = AiDecisionEngine.new().decide(
		ai_view,
		public_rules,
		memory,
		ai_seed,
		config
	)
	if not bool(decision.get("ok", false)):
		return {"ok": false, "consumed": false, "error": "ai_decision_failed"}
	var selected_id: String = str(decision.get("action", {}).get("id", ""))
	_last_ai_decision_audit = decision["audit"].duplicate(true)
	_last_ai_decision_audit["controller_context"] = {
		"difficulty_id": _ai_difficulty_id,
		"profile_id": str(config.profile_id),
		"profile_config_digest": Canonical.digest(config.audit_snapshot()),
		"input_projection_digest": str(
			decision["audit"].get("input_projection_summary", {}).get("projection_digest", "")
		),
		"ai_seed": ai_seed,
		"selected_action_id": selected_id,
		"action_id_mapped": false,
	}
	var mapping: Dictionary = _map_ai_action_or_error(previews, selected_id)
	if not bool(mapping.get("ok", false)):
		return mapping
	var intent: Dictionary = mapping["intent"]
	_last_ai_decision_audit["controller_context"]["action_id_mapped"] = true
	var result: Dictionary = RuleEngine.submit_action(_full_state, intent, {
		"preparation_token": _prepared_token,
		"include_state_summary": false,
	})
	if not bool(result.get("consumed", false)):
		return {"ok": false, "consumed": false, "error": "ai_intent_not_consumed"}
	_update_ai_memory(
		ai_player_view,
		selected_id,
		str(decision.get("action", {}).get("actor_id", "")),
		projection,
		decision.get("action", {})
	)
	_prepared_token = ""
	_prepare_active_action()
	_publish_human_view()
	var feedback: Dictionary = {
		"ok": true,
		"consumed": true,
		"source": "ai",
		"difficulty_id": _ai_difficulty_id,
	}
	action_feedback.emit(feedback.duplicate(true))
	return feedback


func _prepare_active_action() -> void:
	if _full_state.is_empty() or bool(_full_state["terminal"]):
		_prepared_token = ""
		return
	var prepared: Dictionary = RuleEngine.prepare_action(_full_state)
	_prepared_token = str(prepared.get("preparation", {}).get("token", "")) \
		if bool(prepared.get("ok", false)) else ""


func _publish_human_view() -> void:
	if _full_state.is_empty():
		_human_view = {}
		_human_previews = []
	else:
		_human_view = PlayerViewProjector.project(_full_state, human_side).duplicate(true)
		_human_previews = PlayerViewProjector.generate_action_intents(_human_view).duplicate(true)
	human_view_updated.emit(_human_view.duplicate(true))


func _find_public_preview(intent: Dictionary) -> Dictionary:
	for preview: Dictionary in _human_previews:
		if str(preview["piece_id"]) == str(intent.get("piece_id", "")) \
		and str(preview["action_type"]) == str(intent.get("action_type", "")) \
		and preview["target_cell"] == intent.get("target_cell", []) \
		and str(preview["skill_type"]) == str(intent.get("skill_type", "")):
			return preview.duplicate(true)
	return {}


func _intent_for_public_action(previews: Array, selected_id: String) -> Dictionary:
	for preview: Dictionary in previews:
		if str(preview["id"]) != selected_id \
		or preview["classification"] == PlayerViewProjector.KNOWN_ILLEGAL:
			continue
		return {
			"piece_id": str(preview["piece_id"]),
			"action_type": str(preview["action_type"]),
			"target_cell": preview["target_cell"].duplicate(),
			"skill_type": str(preview["skill_type"]),
		}
	return {}


func _map_ai_action_or_error(previews: Array, selected_id: String) -> Dictionary:
	var intent: Dictionary = _intent_for_public_action(previews, selected_id)
	if intent.is_empty():
		return {"ok": false, "consumed": false, "error": "ai_action_id_unmapped"}
	return {"ok": true, "intent": intent}


func _public_ai_rules() -> Dictionary:
	return {
		"schema_version": "public-ai-rules-v1",
		"board_width": MatchState.BOARD_WIDTH,
		"board_height": MatchState.BOARD_HEIGHT,
		"piece_values": {
			"pawn": 10, "rook": 50, "horse": 30, "elephant": 25,
			"advisor": 25, "cannon": 45, "general": 10000,
		},
		"action_kind_bias": {"move": 0, "bombard": 0, "pass": -100},
	}


func _profile_for_difficulty() -> Resource:
	match _ai_difficulty_id:
		"easy": return ai_easy_profile
		"hard": return ai_hard_profile
		"expert": return ai_expert_profile
	return ai_medium_profile


func _empty_ai_memory() -> Dictionary:
	return {
		"schema_version": "ai-memory-v1",
		"recent_action_ids": [],
		"action_visit_counts": {},
		"actor_visit_counts": {},
		"last_visible_piece_turns": {},
		"enemy_piece_observations": {},
		"known_captured_enemy_ids": [],
	}


func _update_ai_memory(
	ai_player_view: Dictionary,
	selected_action_id: String,
	selected_actor_id: String,
	projection: Dictionary,
	selected_action: Dictionary
) -> void:
	_ai_memory["recent_action_ids"].append(selected_action_id)
	if _ai_memory["recent_action_ids"].size() > 8:
		_ai_memory["recent_action_ids"].pop_front()
	_ai_memory["action_visit_counts"][selected_action_id] = int(
		_ai_memory["action_visit_counts"].get(selected_action_id, 0)
	) + 1
	if not selected_actor_id.is_empty():
		_ai_memory["actor_visit_counts"][selected_actor_id] = int(
			_ai_memory["actor_visit_counts"].get(selected_actor_id, 0)
		) + 1
	for piece: Dictionary in ai_player_view["pieces"]:
		if piece["side"] != ai_player_view["viewer_side"]:
			_ai_memory["last_visible_piece_turns"][str(piece["id"])] = int(ai_player_view["action_index"])
	for piece: Dictionary in projection.get("visible_pieces", []):
		if str(piece.get("side", "")) == str(projection.get("viewer_side", "")):
			continue
		_ai_memory["enemy_piece_observations"][str(piece["id"])] = {
			"piece_type": str(piece["piece_type"]),
			"position": piece["position"].duplicate(),
			"turn_index": int(projection.get("turn_index", 0)),
		}
	for capture: Dictionary in selected_action.get("visible_captures", []):
		var captured_id: String = str(capture.get("piece_id", ""))
		if captured_id.is_empty():
			continue
		if captured_id not in _ai_memory["known_captured_enemy_ids"]:
			_ai_memory["known_captured_enemy_ids"].append(captured_id)
		_ai_memory["enemy_piece_observations"].erase(captured_id)
	_ai_memory["known_captured_enemy_ids"].sort()
