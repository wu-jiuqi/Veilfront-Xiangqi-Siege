extends RefCounted

const RuleEngine = preload("res://scripts/game/domain/rule_engine.gd")
const Canonical = preload("res://scripts/game/domain/canonical.gd")
const NormalizedIntentCodec = preload("res://scripts/game/domain/normalized_intent_codec.gd")
const ViewerContext = preload("res://scripts/game/projection/viewer_context.gd")
const ObserverProjector = preload("res://scripts/game/projection/observer_projector.gd")
const PublicActionPreviewer = preload("res://scripts/game/projection/public_action_previewer.gd")
const VisibleOutcomeProjector = preload("res://scripts/game/projection/visible_outcome_projector.gd")
const ObserverReplayValidator = preload("res://scripts/game/application/observer_replay_validator.gd")

var _state: Dictionary = {}
var _viewer_context: RefCounted
var _preparation: Dictionary = {}
var _observer_frames: Array = []
var _initial_player_view: Dictionary = {}


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


func current_player_view() -> Dictionary:
	return ObserverProjector.project_player_view(_state, _viewer_context)


func current_visible_events() -> Array:
	return VisibleOutcomeProjector.project_visible_events(_state, _viewer_context)


func current_action_previews() -> Array:
	var player_view: Dictionary = current_player_view()
	if bool(player_view.get("terminal", false)) \
	or str(player_view.get("active_side", "")) != str(player_view.get("viewer_side", "")):
		return []
	return PublicActionPreviewer.generate_action_intents(player_view)


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
	var player_view: Dictionary = current_player_view()
	var visible_events: Array = current_visible_events()
	var action_previews: Array = [] if bool(_state.get("terminal", false)) \
		else current_action_previews()
	var frame: Dictionary = {
		"action_index": int(player_view["action_index"]),
		"player_view_or_digest": player_view.duplicate(true),
		"visible_events": visible_events.duplicate(true),
		"visible_error": visible_error.duplicate(true),
		"action_previews": action_previews.duplicate(true),
	}
	_observer_frames.append(frame)
	return {
		"ok": bool(result.get("ok", false)),
		"consumed": bool(result.get("consumed", false)),
		"player_view": player_view,
		"visible_events": visible_events,
		"visible_error": visible_error,
		"action_previews": action_previews,
	}


func observer_replay_record() -> Dictionary:
	var initial_view: Dictionary = _initial_player_view.duplicate(true)
	return {
		"schema_version": "veilfront-observer-replay-v1",
		"match_id": str(initial_view["match_id"]),
		"rules_revision": str(initial_view["rules_revision"]),
		"viewer_side": str(initial_view["viewer_side"]),
		"initial_player_view": initial_view,
		"frames": _observer_frames.duplicate(true),
		"final_player_view_digest": Canonical.digest(current_player_view()),
		"codec_versions": {
			"player_view": "veilfront-player-view-v1",
			"visible_event": "veilfront-visible-event-v1",
			"visible_error": "veilfront-visible-error-v1",
			"action_preview": "veilfront-action-preview-v1",
		},
	}


func validate_observer_replay_record(record: Dictionary) -> Dictionary:
	return ObserverReplayValidator.validate(record, str(_viewer_context.call("side")))


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
