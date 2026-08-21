extends RefCounted

const RuleEngine = preload("res://scripts/game/domain/rule_engine.gd")
const Canonical = preload("res://scripts/game/domain/canonical.gd")
const NormalizedIntentCodec = preload("res://scripts/game/domain/normalized_intent_codec.gd")
const ViewerContext = preload("res://scripts/game/projection/viewer_context.gd")
const ObserverProjector = preload("res://scripts/game/projection/observer_projector.gd")
const PublicActionPreviewer = preload("res://scripts/game/projection/public_action_previewer.gd")
const VisibleOutcomeProjector = preload("res://scripts/game/projection/visible_outcome_projector.gd")
const ObserverReplayValidator = preload("res://scripts/game/application/observer_replay_validator.gd")
const ScenarioBootstrap = preload("res://scripts/game/domain/scenario_bootstrap.gd")

var _state: Dictionary = {}
var _viewer_context: RefCounted
var _preparation: Dictionary = {}
var _observer_frames: Array = []
var _initial_player_view: Dictionary = {}
var _tutorial_scenario: TutorialScenarioDefinition


static func create_trusted(
	seed_value: int,
	bound_seat: String,
	configuration: Dictionary = {}
) -> RefCounted:
	assert(bound_seat in ["red", "black"])
	var application: RefCounted = new()
	application._state = RuleEngine.create_match(seed_value, configuration)
	application._viewer_context = ViewerContext.create_trusted(bound_seat)
	application._prepare_authority_turn()
	application._initial_player_view = application.current_player_view().duplicate(true)
	return application


static func create_trusted_scenario(
	scenario: TutorialScenarioDefinition,
	configuration: Dictionary = {}
) -> RefCounted:
	if scenario == null or not scenario.is_valid_definition():
		return null
	var application: RefCounted = new()
	var base_state: Dictionary = RuleEngine.create_match(scenario.seed_value, configuration)
	var bootstrap_result: Dictionary = ScenarioBootstrap.create_validated(base_state, scenario)
	if not bool(bootstrap_result.get("ok", false)):
		return null
	application._state = bootstrap_result.get("state", {}).duplicate(true)
	application._tutorial_scenario = scenario
	application._viewer_context = ViewerContext.create_trusted(scenario.bound_seat)
	application._prepare_authority_turn()
	application._initial_player_view = application.current_player_view().duplicate(true)
	return application


func current_player_view() -> Dictionary:
	return ObserverProjector.project_player_view(_state, _viewer_context)


func current_visible_events() -> Array:
	return VisibleOutcomeProjector.project_visible_events(_state, _viewer_context)


func current_action_previews() -> Array:
	return _action_previews_for_view(current_player_view())


func preview_intent(intent: Dictionary) -> Dictionary:
	var player_view: Dictionary = current_player_view()
	var preview: Dictionary = PublicActionPreviewer.preview_intent(player_view, intent)
	if str(player_view.get("active_side", "")) != str(player_view.get("viewer_side", "")):
		preview["classification"] = "KNOWN_ILLEGAL"
		preview["message_key"] = "action.known_illegal"
	return preview


func submit_intent(normalized_intent: Dictionary) -> Dictionary:
	var encoded: Dictionary = NormalizedIntentCodec.encode(normalized_intent)
	if not bool(encoded.get("ok", false)):
		return _safe_rejection(normalized_intent, "invalid_request")
	var intent_id: String = str(normalized_intent["intent_id"])
	var expected_index: int = int(normalized_intent["expected_action_index"])
	if expected_index != int(_state["action_index"]):
		return _safe_rejection(normalized_intent, "stale_intent")
	if str(_state["active_side"]) != str(_viewer_context.call("side")):
		return _safe_rejection(normalized_intent, "known_illegal")
	var domain_intent: Dictionary = NormalizedIntentCodec.to_domain_intent(normalized_intent)
	var preview: Dictionary = PublicActionPreviewer.preview_intent(
		current_player_view(), domain_intent
	)
	var result: Dictionary = RuleEngine.submit_action(_state, domain_intent, {
		"trusted_generated_action": false,
		"include_state_summary": false,
		"preparation_token": str(_preparation.get("token", "")),
		"public_classification": str(preview.get("classification", "KNOWN_ILLEGAL")),
	})
	var visible_error: Dictionary = VisibleOutcomeProjector.project_visible_error(
		result, intent_id, expected_index
	)
	if bool(result.get("consumed", false)) and not bool(_state.get("terminal", false)):
		_prepare_authority_turn()
	var frame: Dictionary = _compose_safe_frame(
		_state, _viewer_context, visible_error, _observer_frames.size() + 1
	)
	_observer_frames.append(frame)
	return {
		"ok": bool(result.get("ok", false)),
		"consumed": bool(result.get("consumed", false)),
		"player_view": frame["player_view_or_digest"].duplicate(true),
		"visible_events": frame["visible_events"].duplicate(true),
		"visible_error": frame["visible_error"].duplicate(true),
		"action_previews": frame["action_previews"].duplicate(true),
	}


func advance_trusted_scripted_pass() -> Dictionary:
	if bool(_state.get("terminal", false)) \
	or str(_state.get("active_side", "")) == str(_viewer_context.call("side")):
		return {
			"ok": false,
			"consumed": false,
			"player_view": current_player_view(),
			"visible_events": current_visible_events(),
			"visible_error": {},
			"action_previews": current_action_previews(),
		}
	var actor_side := str(_state.get("active_side", ""))
	var action_index := int(_state.get("action_index", 0))
	var domain_intent := {
		"piece_id": "",
		"action_type": "pass",
		"target_cell": [],
		"skill_type": "",
	}
	var result: Dictionary = RuleEngine.submit_action(_state, domain_intent, {
		"trusted_generated_action": true,
		"include_state_summary": false,
		"preparation_token": str(_preparation.get("token", "")),
		"public_classification": "KNOWN_LEGAL",
	})
	if bool(result.get("consumed", false)) and not bool(_state.get("terminal", false)):
		_prepare_authority_turn()
	var frame: Dictionary = _compose_safe_frame(
		_state,
		_viewer_context,
		{},
		_observer_frames.size() + 1
	)
	_observer_frames.append(frame)
	return {
		"ok": bool(result.get("ok", false)),
		"consumed": bool(result.get("consumed", false)),
		"scripted_actor_side": actor_side,
		"scripted_action_index": action_index,
		"player_view": frame["player_view_or_digest"].duplicate(true),
		"visible_events": frame["visible_events"].duplicate(true),
		"visible_error": {},
		"action_previews": frame["action_previews"].duplicate(true),
	}


func submit_trusted_timeout(expected_action_index: int) -> Dictionary:
	if bool(_state.get("terminal", false)) \
	or expected_action_index != int(_state.get("action_index", -1)) \
	or str(_state.get("active_side", "")) != str(_viewer_context.call("side")):
		return {
			"ok": false,
			"consumed": false,
			"error_code": "stale_or_unauthorized_timeout",
			"player_view": current_player_view(),
			"visible_events": current_visible_events(),
			"visible_error": {},
			"action_previews": current_action_previews(),
		}
	var result: Dictionary = RuleEngine.submit_timeout_random_move(_state, {
		"include_state_summary": false,
		"preparation_token": str(_preparation.get("token", "")),
	})
	if bool(result.get("consumed", false)) and not bool(_state.get("terminal", false)):
		_prepare_authority_turn()
	var frame: Dictionary = _compose_safe_frame(
		_state, _viewer_context, {}, _observer_frames.size() + 1
	)
	_observer_frames.append(frame)
	return {
		"ok": bool(result.get("ok", false)),
		"consumed": bool(result.get("consumed", false)),
		"player_view": frame["player_view_or_digest"].duplicate(true),
		"visible_events": frame["visible_events"].duplicate(true),
		"visible_error": {},
		"action_previews": frame["action_previews"].duplicate(true),
	}


func submit_trusted_tutorial_transition(step_id: String) -> Dictionary:
	var result: Dictionary = RuleEngine.resolve_tutorial_transition(
		_state,
		_tutorial_scenario,
		step_id
	)
	if not bool(result.get("ok", false)):
		return {
			"ok": false,
			"player_view": current_player_view(),
			"visible_events": current_visible_events(),
			"visible_error": {},
			"action_previews": current_action_previews(),
		}
	_prepare_authority_turn()
	var frame: Dictionary = _compose_safe_frame(
		_state, _viewer_context, {}, _observer_frames.size() + 1
	)
	_observer_frames.append(frame)
	return {
		"ok": true,
		"applied": bool(result.get("applied", false)),
		"domain_event": result.get("event", {}).duplicate(true),
		"player_view": frame["player_view_or_digest"].duplicate(true),
		"visible_events": frame["visible_events"].duplicate(true),
		"visible_error": {},
		"action_previews": frame["action_previews"].duplicate(true),
	}


func apply_trusted_tutorial_effect(step_id: String) -> Dictionary:
	return submit_trusted_tutorial_transition(step_id)


func observer_replay_record() -> Dictionary:
	var initial_view: Dictionary = _initial_player_view.duplicate(true)
	var record: Dictionary = {
		"schema_version": "veilfront-observer-replay-v2",
		"match_id": str(initial_view["match_id"]),
		"rules_revision": str(initial_view["rules_revision"]),
		"viewer_side": str(initial_view["viewer_side"]),
		"initial_player_view": initial_view,
		"frames": _observer_frames.duplicate(true),
		"final_player_view_digest": Canonical.digest(current_player_view()),
		"codec_versions": {
			"observer_replay": "veilfront-observer-replay-v2",
			"player_view": "veilfront-player-view-v1",
			"visible_event": "veilfront-visible-event-v1",
			"visible_error": "veilfront-visible-error-v1",
			"action_preview": "veilfront-action-preview-v1",
		},
		"audit_digest": "",
	}
	record["audit_digest"] = Canonical.digest(record)
	return record


func validate_observer_replay_record(record: Dictionary) -> Dictionary:
	return ObserverReplayValidator.validate(record, str(_viewer_context.call("side")))


static func _compose_safe_frame(
	state_snapshot: Dictionary,
	seat_context: RefCounted,
	public_error: Dictionary,
	sequence: int
) -> Dictionary:
	assert(seat_context != null and bool(seat_context.call("is_valid")))
	var player_view: Dictionary = ObserverProjector.project_player_view(
		state_snapshot, seat_context
	)
	return _compose_safe_frame_from_dtos(
		player_view,
		VisibleOutcomeProjector.project_visible_events(state_snapshot, seat_context),
		public_error,
		_action_previews_for_view(player_view),
		sequence
	)


static func _compose_safe_frame_from_dtos(
	player_view: Dictionary,
	public_events: Array,
	public_error: Dictionary,
	action_previews: Array,
	sequence: int
) -> Dictionary:
	return {
		"frame_sequence": sequence,
		"action_index": int(player_view.get("action_index", 0)),
		"player_view_or_digest": player_view.duplicate(true),
		"visible_events": public_events.duplicate(true),
		"visible_error": public_error.duplicate(true),
		"action_previews": action_previews.duplicate(true),
	}


static func _action_previews_for_view(player_view: Dictionary) -> Array:
	if bool(player_view.get("terminal", false)) \
	or str(player_view.get("active_side", "")) != str(player_view.get("viewer_side", "")):
		return []
	return PublicActionPreviewer.generate_action_intents(player_view)


func _prepare_authority_turn() -> void:
	var prepared_result: Dictionary = RuleEngine.prepare_action(_state)
	_preparation = prepared_result.get("preparation", {}).duplicate(true)


func _safe_rejection(intent: Dictionary, public_code: String) -> Dictionary:
	var intent_id: String = str(intent.get("intent_id", "invalid-intent"))
	var action_index: int = int(_state.get("action_index", 0))
	var domain_result: Dictionary = {
		"ok": false,
		"consumed": false,
		"error": {
			"category": "known_illegal" if public_code == "known_illegal" else "application",
			"code": public_code,
			"fields": [],
		},
	}
	return {
		"ok": false,
		"consumed": false,
		"player_view": current_player_view(),
		"visible_events": current_visible_events(),
		"visible_error": VisibleOutcomeProjector.project_visible_error(
			domain_result, intent_id, action_index
		),
		"action_previews": current_action_previews(),
	}
