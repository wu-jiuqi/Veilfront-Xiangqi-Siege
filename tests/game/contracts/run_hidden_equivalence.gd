extends SceneTree

const Canonical = preload("res://scripts/game/domain/canonical.gd")
const RuleEngine = preload("res://scripts/game/domain/rule_engine.gd")
const FullStateCodec = preload("res://scripts/game/domain/full_state_codec.gd")
const DomainEventCodec = preload("res://scripts/game/domain/domain_event_codec.gd")
const NormalizedIntentCodec = preload("res://scripts/game/domain/normalized_intent_codec.gd")
const AuthoritativeReplay = preload("res://scripts/game/domain/authoritative_replay.gd")
const ViewerContext = preload("res://scripts/game/projection/viewer_context.gd")
const ObserverProjector = preload("res://scripts/game/projection/observer_projector.gd")
const PublicActionPreviewer = preload("res://scripts/game/projection/public_action_previewer.gd")
const VisibleOutcomeProjector = preload("res://scripts/game/projection/visible_outcome_projector.gd")
const FormalMatchApplication = preload("res://scripts/game/application/formal_match_application.gd")
const PlayerViewCodec = preload("res://scripts/game/contracts/player_view_codec.gd")
const VisibleEventCodec = preload("res://scripts/game/contracts/visible_event_codec.gd")
const VisibleErrorCodec = preload("res://scripts/game/contracts/visible_error_codec.gd")
const ActionPreviewCodec = preload("res://scripts/game/contracts/action_preview_codec.gd")

var _failures: Array[String] = []
var _checks: int = 0
var _red_context: RefCounted


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_red_context = ViewerContext.create_trusted("red")
	_check_hidden_flag_pair()
	_check_hidden_horse_pair()
	_check_hidden_elephant_pair()
	_check_hidden_cannon_pair()
	_check_hidden_rng_pair()
	_check_private_marker_pair()
	_check_codec_round_trips_and_rejections()
	_check_authoritative_replay_boundary()
	_check_observer_replay_boundary()
	if _failures.is_empty():
		print("HIDDEN_EQUIVALENCE_PASS pairs=6 checks=%d" % _checks)
		quit(0)
		return
	for failure: String in _failures:
		push_error("HIDDEN_EQUIVALENCE_FAIL %s" % failure)
	print("HIDDEN_EQUIVALENCE_FAILED checks=%d failures=%d" % [_checks, _failures.size()])
	quit(1)


func _check_hidden_flag_pair() -> void:
	var states: Array = _state_pair()
	states[0]["flags"][0]["position"] = [1, 9]
	states[1]["flags"][0]["position"] = [9, 16]
	states[0]["rng"]["state"] = 101
	states[1]["rng"]["state"] = 202
	_assert_hidden_pair("HIDDEN-FLAG-PAIR", states[0], states[1],
		_hidden_result("route_unknown_blocked"), _hidden_result("target_unknown_occupied"))


func _check_hidden_horse_pair() -> void:
	var states: Array = _state_pair()
	_move_hidden_piece(states[0], "black-horse-1", [2, 20])
	_move_hidden_piece(states[1], "black-horse-1", [8, 20])
	_assert_hidden_pair("HIDDEN-HORSE-PAIR", states[0], states[1],
		_hidden_result("route_unknown_blocked"), _hidden_result("target_unknown_occupied"))


func _check_hidden_elephant_pair() -> void:
	var states: Array = _state_pair()
	states[0]["vision_sources"]["black"]["elephant_block_fields"] = {
		"black-elephant-1": [[1, 10], [2, 10], [3, 10]],
	}
	states[1]["vision_sources"]["black"]["elephant_block_fields"] = {
		"secret-source-b": [[7, 14], [8, 14], [9, 14]],
	}
	_assert_hidden_pair("HIDDEN-ELEPHANT-PAIR", states[0], states[1],
		_hidden_result("route_unknown_blocked"), _hidden_result("target_unknown_occupied"))


func _check_hidden_cannon_pair() -> void:
	var states: Array = _state_pair()
	_move_hidden_piece(states[0], "black-cannon-1", [2, 19])
	_move_hidden_piece(states[1], "black-cannon-1", [8, 19])
	_assert_hidden_pair("HIDDEN-CANNON-PAIR", states[0], states[1],
		_hidden_result("cannon_path_invalid"), _hidden_result("target_unknown_occupied"))


func _check_hidden_rng_pair() -> void:
	var states: Array = _state_pair()
	states[0]["rng"]["state"] = 777
	states[0]["rng"]["draw_index"] = 4
	states[0]["rng"]["records"] = [{"private_future": "bombard-a"}]
	states[1]["rng"]["state"] = 888
	states[1]["rng"]["draw_index"] = 9
	states[1]["rng"]["records"] = [{"private_future": "resurrect-b"}]
	_assert_hidden_pair("HIDDEN-RNG-PAIR", states[0], states[1],
		_hidden_result("route_unknown_blocked"), _hidden_result("target_unknown_occupied"))


func _check_private_marker_pair() -> void:
	var states: Array = _state_pair()
	var markers_a: Array = [{"cell": [1, 1], "kind": "circle"}]
	var markers_b: Array = [{"cell": [9, 24], "kind": "cross"}]
	_expect(Canonical.digest(markers_a) != Canonical.digest(markers_b),
		"PRIVATE-MARKER-PAIR setup did not differ")
	_expect(Canonical.digest(states[0]) == Canonical.digest(states[1]),
		"PRIVATE-MARKER-PAIR changed authority digest")
	_assert_hidden_pair("PRIVATE-MARKER-PAIR", states[0], states[1],
		_hidden_result("route_unknown_blocked"), _hidden_result("route_unknown_blocked"), false)
	var illegal_state: Dictionary = states[0].duplicate(true)
	illegal_state["private_markers"] = markers_a
	_expect(not bool(FullStateCodec.encode(illegal_state).get("ok", true)),
		"PRIVATE-MARKER-PAIR FullState codec accepted local markers")


func _assert_hidden_pair(
	pair_id: String,
	state_a: Dictionary,
	state_b: Dictionary,
	result_a: Dictionary,
	result_b: Dictionary,
	expect_authority_difference: bool = true
) -> void:
	if expect_authority_difference:
		_expect(Canonical.digest(state_a) != Canonical.digest(state_b),
			"%s authority setup did not differ" % pair_id)
	var view_a: Dictionary = ObserverProjector.project_player_view(state_a, _red_context)
	var view_b: Dictionary = ObserverProjector.project_player_view(state_b, _red_context)
	_expect(_bytes(view_a) == _bytes(view_b), "%s PlayerView leaked hidden fact" % pair_id)
	var previews_a: Array = PublicActionPreviewer.generate_action_intents(view_a)
	var previews_b: Array = PublicActionPreviewer.generate_action_intents(view_b)
	_expect(_bytes(previews_a) == _bytes(previews_b), "%s ActionPreview leaked hidden fact" % pair_id)
	var events_a: Array = VisibleOutcomeProjector.project_visible_events(state_a, _red_context)
	var events_b: Array = VisibleOutcomeProjector.project_visible_events(state_b, _red_context)
	_expect(_bytes(events_a) == _bytes(events_b), "%s VisibleEvent leaked hidden fact" % pair_id)
	var error_a: Dictionary = VisibleOutcomeProjector.project_visible_error(result_a, "paired-intent", 0)
	var error_b: Dictionary = VisibleOutcomeProjector.project_visible_error(result_b, "paired-intent", 0)
	_expect(_bytes(error_a) == _bytes(error_b), "%s VisibleError shape leaked hidden cause" % pair_id)
	var frame_a: Dictionary = _observer_frame(view_a, events_a, error_a, previews_a)
	var frame_b: Dictionary = _observer_frame(view_b, events_b, error_b, previews_b)
	_expect(_bytes(frame_a) == _bytes(frame_b), "%s ObserverReplay frame leaked hidden fact" % pair_id)
	_expect(bool(PlayerViewCodec.encode(view_a).get("ok", false)), "%s PlayerView codec rejected projection" % pair_id)
	for preview: Dictionary in previews_a:
		_expect(bool(ActionPreviewCodec.encode(preview).get("ok", false)),
			"%s ActionPreview codec rejected projection" % pair_id)
	if not error_a.is_empty():
		_expect(bool(VisibleErrorCodec.encode(error_a).get("ok", false)),
			"%s VisibleError codec rejected projection" % pair_id)


func _check_codec_round_trips_and_rejections() -> void:
	var state: Dictionary = RuleEngine.create_match(471001, {"full_round_limit_hypothesis": 50})
	var encoded_state: Dictionary = FullStateCodec.encode(state)
	_expect(bool(encoded_state.get("ok", false)), "FullState encode failed")
	var decoded_state: Dictionary = FullStateCodec.decode(str(encoded_state.get("bytes", "")))
	_expect(bool(decoded_state.get("ok", false)),
		"FullState canonical round trip failed")
	_expect(decoded_state.get("value", {}) == state, "FullState round trip changed 64-bit authority values")
	var unknown_state: Dictionary = state.duplicate(true)
	unknown_state["debug_seed"] = 471001
	_expect(not bool(FullStateCodec.encode(unknown_state).get("ok", true)),
		"FullState accepted unknown authority field")
	var prepared: Dictionary = RuleEngine.prepare_action(state)
	var result: Dictionary = RuleEngine.submit_action(state, {
		"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": "",
	}, {"trusted_generated_action": true, "preparation_token": prepared["preparation"]["token"]})
	var event: Dictionary = result.get("event", {})
	var encoded_event: Dictionary = DomainEventCodec.encode(event)
	_expect(bool(encoded_event.get("ok", false)), "DomainEvent encode failed")
	var decoded_event: Dictionary = DomainEventCodec.decode(str(encoded_event.get("bytes", "")))
	_expect(bool(decoded_event.get("ok", false)),
		"DomainEvent canonical round trip failed")
	_expect(decoded_event.get("value", {}) == event, "DomainEvent round trip changed 64-bit random samples")
	var normalized_intent: Dictionary = _pass_intent(0)
	var encoded_intent: Dictionary = NormalizedIntentCodec.encode(normalized_intent)
	_expect(bool(encoded_intent.get("ok", false)), "NormalizedIntent encode failed")
	_expect(bool(NormalizedIntentCodec.decode(str(encoded_intent.get("bytes", ""))).get("ok", false)),
		"NormalizedIntent canonical round trip failed")
	var offboard_intent: Dictionary = normalized_intent.duplicate(true)
	offboard_intent["action_type"] = "move"
	offboard_intent["piece_id"] = "red-rook-1"
	offboard_intent["target_cell"] = [0, 25]
	_expect(not bool(NormalizedIntentCodec.encode(offboard_intent).get("ok", true)),
		"NormalizedIntent accepted off-board coordinate")


func _check_authoritative_replay_boundary() -> void:
	var replay: Dictionary = AuthoritativeReplay.capture(
		471001,
		[{"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": ""}],
		{"full_round_limit_hypothesis": 50, "match_id": "audit-custom-match"}
	)
	_expect(bool(AuthoritativeReplay.verify(replay).get("ok", false)),
		"AuthoritativeReplay custom match replay failed")
	_expect(str(replay.get("schema_version", "")) == "veilfront-authoritative-replay-v2",
		"AuthoritativeReplay schema was not revised for rules-input binding")
	var binding: Dictionary = replay.get("rules_input_binding", {})
	_expect(str(binding.get("source_commit", "")) == "6253678157157091584b253470e709bad17c534f",
		"AuthoritativeReplay omitted RC3 source binding")
	_expect(str(binding.get("hq_successor_sha256", "")) == "f6b07d8cbdc7db4492c33e8b4b028aca2906cccc8baf5921273aaa012d48e19b",
		"AuthoritativeReplay omitted HQ successor binding")
	_expect(not str(binding.get("formal_rules_bundle_sha256", "")).is_empty(),
		"AuthoritativeReplay omitted formal rules bundle binding")
	var codec_tamper: Dictionary = replay.duplicate(true)
	codec_tamper["codec_versions"]["full_state"] = "unknown-state-v9"
	_expect(not bool(AuthoritativeReplay.verify(codec_tamper).get("ok", true)),
		"AuthoritativeReplay accepted codec tamper")
	var rules_tamper: Dictionary = replay.duplicate(true)
	rules_tamper["rules_revision"] = "unapproved-rules"
	_expect(not bool(AuthoritativeReplay.verify(rules_tamper).get("ok", true)),
		"AuthoritativeReplay accepted rules tamper")
	var unknown_root: Dictionary = replay.duplicate(true)
	unknown_root["debug"] = true
	_expect(not bool(AuthoritativeReplay.verify(unknown_root).get("ok", true)),
		"AuthoritativeReplay accepted unknown root field")
	if replay.has("rules_input_binding"):
		for field_name: String in [
			"source_commit", "hq_successor_sha256", "formal_rules_bundle_sha256",
			"implementation_revision", "canonical_revision",
		]:
			var binding_tamper: Dictionary = replay.duplicate(true)
			binding_tamper["rules_input_binding"][field_name] = "tampered-%s" % field_name
			_expect(not bool(AuthoritativeReplay.verify(binding_tamper).get("ok", true)),
				"AuthoritativeReplay accepted rules binding tamper: %s" % field_name)


func _check_observer_replay_boundary() -> void:
	var application: RefCounted = FormalMatchApplication.create_trusted(
		471001, "red", {"full_round_limit_hypothesis": 50}
	)
	var initial_record: Dictionary = application.observer_replay_record()
	_expect(str(initial_record.get("schema_version", "")) == "veilfront-observer-replay-v2",
		"ObserverReplay schema was not revised for frame integrity")
	_expect(not str(initial_record.get("audit_digest", "")).is_empty(),
		"ObserverReplay omitted audit digest")
	_expect(bool(application.validate_observer_replay_record(initial_record).get("ok", false)),
		"empty ObserverReplay failed validation")
	var live_result: Dictionary = application.submit_intent(_pass_intent(0))
	_expect(bool(live_result.get("ok", false)), "application pass submission failed")
	var record: Dictionary = application.observer_replay_record()
	_expect(bool(application.validate_observer_replay_record(record).get("ok", false)),
		"ObserverReplay failed validation")
	var frames: Array = record.get("frames", [])
	_expect(frames.size() == 1, "ObserverReplay did not capture one frame")
	if frames.size() == 1:
		var frame: Dictionary = frames[0]
		_expect(_bytes(frame.get("player_view_or_digest", {})) == _bytes(live_result.get("player_view", {})),
			"ObserverReplay PlayerView differs from live DTO")
		_expect(_bytes(frame.get("visible_events", [])) == _bytes(live_result.get("visible_events", [])),
			"ObserverReplay VisibleEvent differs from live DTO")
		_expect(_bytes(frame.get("visible_error", {})) == _bytes(live_result.get("visible_error", {})),
			"ObserverReplay VisibleError differs from live DTO")
		_expect(_bytes(frame.get("action_previews", [])) == _bytes(live_result.get("action_previews", [])),
			"ObserverReplay ActionPreview differs from live DTO")
	var tampered_side: Dictionary = record.duplicate(true)
	tampered_side["viewer_side"] = "black"
	_expect(not bool(application.validate_observer_replay_record(tampered_side).get("ok", true)),
		"ObserverReplay accepted tampered viewer side")
	var tampered_digest: Dictionary = record.duplicate(true)
	tampered_digest["final_player_view_digest"] = "0".repeat(64)
	_expect(not bool(application.validate_observer_replay_record(tampered_digest).get("ok", true)),
		"ObserverReplay accepted tampered final digest")
	var forbidden_field: Dictionary = record.duplicate(true)
	forbidden_field["seed"] = 471001
	_expect(not bool(application.validate_observer_replay_record(forbidden_field).get("ok", true)),
		"ObserverReplay accepted authority seed")
	var forbidden_frame: Dictionary = record.duplicate(true)
	forbidden_frame["frames"][0]["domain_events"] = []
	_expect(not bool(application.validate_observer_replay_record(forbidden_frame).get("ok", true)),
		"ObserverReplay accepted raw domain event field")
	var legal_event_tamper: Dictionary = record.duplicate(true)
	legal_event_tamper["frames"][0]["visible_events"] = []
	_expect(not bool(application.validate_observer_replay_record(legal_event_tamper).get("ok", true)),
		"ObserverReplay accepted legal-shape VisibleEvent tamper")
	var rejection_application: RefCounted = FormalMatchApplication.create_trusted(
		471001, "red", {"full_round_limit_hypothesis": 50}
	)
	var illegal_intent: Dictionary = _pass_intent(0)
	illegal_intent["intent_id"] = "known-illegal-frame"
	illegal_intent["piece_id"] = "missing-piece"
	illegal_intent["action_type"] = "move"
	illegal_intent["target_cell"] = [5, 5]
	var rejection_result: Dictionary = rejection_application.submit_intent(illegal_intent)
	_expect(not bool(rejection_result.get("ok", true)), "known-illegal replay fixture unexpectedly succeeded")
	var rejection_record: Dictionary = rejection_application.observer_replay_record()
	_expect(bool(rejection_application.validate_observer_replay_record(rejection_record).get("ok", false)),
		"known-illegal ObserverReplay failed baseline validation")
	var legal_error_tamper: Dictionary = rejection_record.duplicate(true)
	legal_error_tamper["frames"][0]["visible_error"] = {}
	_expect(not bool(rejection_application.validate_observer_replay_record(legal_error_tamper).get("ok", true)),
		"ObserverReplay accepted legal-shape VisibleError tamper")
	var legal_preview_tamper: Dictionary = rejection_record.duplicate(true)
	legal_preview_tamper["frames"][0]["action_previews"] = []
	_expect(not bool(rejection_application.validate_observer_replay_record(legal_preview_tamper).get("ok", true)),
		"ObserverReplay accepted legal-shape ActionPreview tamper")
	var black_application: RefCounted = FormalMatchApplication.create_trusted(
		471001, "black", {"full_round_limit_hypothesis": 50}
	)
	_expect(black_application.current_action_previews().is_empty(),
		"inactive bound seat received action previews")
	var black_result: Dictionary = black_application.submit_intent(_pass_intent(0))
	_expect(not bool(black_result.get("ok", true)) and not bool(black_result.get("consumed", true)),
		"inactive bound seat consumed the active seat turn")
	_expect(str(black_result.get("visible_error", {}).get("public_code", "")) == "known_illegal",
		"inactive bound seat rejection used the wrong public error shape")


func _state_pair() -> Array:
	var state: Dictionary = RuleEngine.create_match(471001, {"full_round_limit_hypothesis": 50})
	return [state.duplicate(true), state.duplicate(true)]


func _move_hidden_piece(state: Dictionary, piece_id: String, target: Array) -> void:
	var piece: Dictionary = state["pieces"][piece_id]
	var origin_key: String = "%d,%d" % [piece["position"][0], piece["position"][1]]
	state["board"].erase(origin_key)
	var target_key: String = "%d,%d" % [target[0], target[1]]
	if state["board"].has(target_key):
		var displaced_id: String = str(state["board"][target_key])
		state["pieces"][displaced_id]["alive"] = false
		state["pieces"][displaced_id]["position"] = []
		state["board"].erase(target_key)
	piece["position"] = target.duplicate()
	piece["hidden"] = true
	piece["revealed_to"] = []
	state["board"][target_key] = piece_id


func _hidden_result(result_code: String) -> Dictionary:
	return {
		"ok": true,
		"consumed": true,
		"event": {"outcome": {"result_code": result_code}},
	}


func _observer_frame(
	view: Dictionary,
	events: Array,
	error: Dictionary,
	previews: Array
) -> Dictionary:
	return {
		"action_index": int(view["action_index"]),
		"player_view_or_digest": view,
		"visible_events": events,
		"visible_error": error,
		"action_previews": previews,
	}


func _pass_intent(expected_action_index: int) -> Dictionary:
	return {
		"schema_version": "veilfront-intent-v1",
		"intent_id": "pass-%d" % expected_action_index,
		"expected_action_index": expected_action_index,
		"piece_id": "",
		"action_type": "pass",
		"target_cell": [],
		"skill_type": "",
		"confirmation_token": "",
	}


func _bytes(value: Variant) -> String:
	return Canonical.json(value)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
