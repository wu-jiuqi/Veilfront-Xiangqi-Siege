extends RefCounted

const ProtoCanonical = preload("res://scripts/prototype/core/canonical.gd")
const ProtoRuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const ProtoMoveRules = preload("res://scripts/prototype/core/move_rules.gd")
const ProtoSeededRandom = preload("res://scripts/prototype/core/seeded_random.gd")
const ProtoProjector = preload("res://scripts/prototype/view/player_view_projector.gd")
const ProtoReplay = preload("res://scripts/prototype/replay/replay_runner.gd")

const FormalCanonical = preload("res://scripts/game/domain/canonical.gd")
const FormalRuleEngine = preload("res://scripts/game/domain/rule_engine.gd")
const FormalSeededRandom = preload("res://scripts/game/domain/seeded_random.gd")
const FormalVisibilityPolicy = preload("res://scripts/game/domain/visibility_policy.gd")
const ViewerContext = preload("res://scripts/game/projection/viewer_context.gd")
const ObserverProjector = preload("res://scripts/game/projection/observer_projector.gd")
const PublicActionPreviewer = preload("res://scripts/game/projection/public_action_previewer.gd")
const VisibleOutcomeProjector = preload("res://scripts/game/projection/visible_outcome_projector.gd")
const FormalMatchApplication = preload("res://scripts/game/application/formal_match_application.gd")
const SourceMapper = preload("res://tests/game/migration/source_channel_mapper.gd")

const DEFAULT_ROUND_LIMIT: int = 50


static func capture_source(seed_value: int, round_limit: int = DEFAULT_ROUND_LIMIT) -> Dictionary:
	var configuration: Dictionary = {"full_round_limit_hypothesis": round_limit}
	var state: Dictionary = ProtoRuleEngine.create_match(seed_value, configuration)
	var policy_rng: Dictionary = ProtoSeededRandom.create_state(_policy_seed(seed_value))
	var red_context: RefCounted = ViewerContext.create_trusted("red")
	var black_context: RefCounted = ViewerContext.create_trusted("black")
	var intents: Array = []
	var steps: Array = []
	var failure: String = ""
	while not bool(state["terminal"]):
		var prepared: Dictionary = ProtoRuleEngine.prepare_action(state)
		if not bool(prepared.get("ok", false)):
			failure = "source_prepare_failed"
			break
		var actor_side: String = str(state["active_side"])
		var selection: Dictionary = ProtoMoveRules.choose_legal_action_fast(
			state,
			actor_side,
			ProtoProjector.visibility_context(state, actor_side),
			policy_rng
		)
		var intent: Dictionary = selection.get("intent", {}).duplicate(true)
		var active_view: Dictionary = SourceMapper.player_view(state, actor_side, seed_value)
		var preview: Dictionary = SourceMapper.action_preview(active_view, intent)
		var result: Dictionary = ProtoRuleEngine.submit_action(state, intent, {
			"trusted_generated_action": true,
			"include_state_summary": false,
			"preparation_token": str(prepared.get("preparation", {}).get("token", "")),
		})
		if not bool(result.get("ok", false)) or not bool(result.get("consumed", false)):
			failure = "source_submit_failed:%s" % ProtoCanonical.json(intent)
			break
		intents.append(intent.duplicate(true))
		var mapped_state: Dictionary = SourceMapper.full_state(state, seed_value)
		var next_side: String = str(state.get("active_side", ""))
		steps.append(_channel_step(
			intents.size() - 1,
			intent,
			mapped_state,
			SourceMapper.player_view(state, "red", seed_value),
			SourceMapper.player_view(state, "black", seed_value),
			SourceMapper.visible_events(state, "red"),
			SourceMapper.visible_events(state, "black"),
			preview,
			SourceMapper.visible_error(result, "seed-%d-action-%d" % [seed_value, intents.size() - 1], int(state["action_index"])),
			red_context,
			black_context,
			SourceMapper.action_previews(state, "red") if next_side == "red" else [],
			SourceMapper.action_previews(state, "black") if next_side == "black" else [],
			true
		))
	var record: Dictionary = _capture_record(seed_value, state, intents, steps, failure)
	var replay: Dictionary = ProtoReplay.capture(seed_value, intents, configuration)
	record["visible_error_corpus"] = _source_visible_error_corpus(seed_value)
	record["visible_error_corpus_digest"] = FormalCanonical.digest(record["visible_error_corpus"])
	record["authoritative_replay_semantics"] = SourceMapper.authoritative_replay_semantics(
		replay, SourceMapper.full_state(state, seed_value)
	)
	record["authoritative_replay_semantics_digest"] = FormalCanonical.digest(
		record["authoritative_replay_semantics"]
	)
	record["red_observer_replay_digest"] = _observer_replay_digest(steps, "red")
	record["black_observer_replay_digest"] = _observer_replay_digest(steps, "black")
	return record


static func capture_formal(
	seed_value: int,
	intents: Array,
	round_limit: int = DEFAULT_ROUND_LIMIT
) -> Dictionary:
	var configuration: Dictionary = {"full_round_limit_hypothesis": round_limit}
	var state: Dictionary = FormalRuleEngine.create_match(seed_value, configuration)
	var red_context: RefCounted = ViewerContext.create_trusted("red")
	var black_context: RefCounted = ViewerContext.create_trusted("black")
	var applied_intents: Array = []
	var steps: Array = []
	var execution_results: Array = []
	var failure: String = ""
	for intent_value: Variant in intents:
		if bool(state["terminal"]):
			failure = "formal_terminal_before_source"
			break
		var prepared: Dictionary = FormalRuleEngine.prepare_action(state)
		if not bool(prepared.get("ok", false)):
			failure = "formal_prepare_failed"
			break
		var intent: Dictionary = _normalize_domain_intent(intent_value as Dictionary)
		var actor_context: RefCounted = red_context if str(state["active_side"]) == "red" else black_context
		var preview: Dictionary = PublicActionPreviewer.preview_intent(
			ObserverProjector.project_player_view(state, actor_context), intent
		)
		var result: Dictionary = FormalRuleEngine.submit_action(state, intent, {
			"trusted_generated_action": true,
			"include_state_summary": false,
			"preparation_token": str(prepared.get("preparation", {}).get("token", "")),
			"public_classification": str(preview.get("classification", "TENTATIVE")),
		})
		if not bool(result.get("ok", false)) or not bool(result.get("consumed", false)):
			failure = "formal_submit_failed:%s" % FormalCanonical.json(intent)
			break
		applied_intents.append(intent.duplicate(true))
		execution_results.append(_execution_result(result))
		steps.append(_channel_step(
			applied_intents.size() - 1,
			intent,
			state,
			ObserverProjector.project_player_view(state, red_context),
			ObserverProjector.project_player_view(state, black_context),
			VisibleOutcomeProjector.project_visible_events(state, red_context),
			VisibleOutcomeProjector.project_visible_events(state, black_context),
			preview,
			VisibleOutcomeProjector.project_visible_error(
				result, "seed-%d-action-%d" % [seed_value, applied_intents.size() - 1], int(state["action_index"])
			),
			red_context,
			black_context,
			[],
			[],
			false
		))
	var record: Dictionary = _capture_record(seed_value, state, applied_intents, steps, failure)
	record["visible_error_corpus"] = _formal_visible_error_corpus(seed_value)
	record["visible_error_corpus_digest"] = FormalCanonical.digest(record["visible_error_corpus"])
	record["authoritative_replay_semantics"] = SourceMapper.authoritative_replay_semantics({
		"normalized_intents": applied_intents,
		"execution_results": execution_results,
		"domain_events": state.get("events", []),
	}, state)
	record["authoritative_replay_semantics_digest"] = FormalCanonical.digest(
		record["authoritative_replay_semantics"]
	)
	record["red_observer_replay_digest"] = _observer_replay_digest(steps, "red")
	record["black_observer_replay_digest"] = _observer_replay_digest(steps, "black")
	return record


static func compare_records(expected: Dictionary, actual: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	for field: String in ["seed", "failure", "terminal", "winner", "win_reason", "action_count"]:
		if expected.get(field) != actual.get(field):
			failures.append("%s expected=%s actual=%s" % [field, expected.get(field), actual.get(field)])
	for channel: String in [
		"visible_error_corpus_digest", "authoritative_replay_semantics_digest",
		"red_observer_replay_digest", "black_observer_replay_digest",
	]:
		if expected.get(channel) != actual.get(channel):
			failures.append("record_channel=%s expected=%s actual=%s" % [
				channel, FormalCanonical.digest(expected.get(channel)), FormalCanonical.digest(actual.get(channel)),
			])
	var expected_steps: Array = expected.get("steps", [])
	var actual_steps: Array = actual.get("steps", [])
	if expected_steps.size() != actual_steps.size():
		failures.append("step_count expected=%d actual=%d" % [expected_steps.size(), actual_steps.size()])
	var shared_count: int = mini(expected_steps.size(), actual_steps.size())
	for index: int in shared_count:
		var expected_step: Dictionary = expected_steps[index]
		var actual_step: Dictionary = actual_steps[index]
		for channel: String in [
			"intent_digest", "state_digest", "event_digest", "red_player_view_digest",
			"black_player_view_digest", "red_visible_event_digest",
			"black_visible_event_digest", "visible_error_digest", "action_preview_digest",
			"replay_checkpoint_digest",
		]:
			if expected_step.get(channel) != actual_step.get(channel):
				failures.append("action=%d channel=%s expected=%s actual=%s" % [
					index, channel, expected_step.get(channel), actual_step.get(channel),
				])
				break
		if not failures.is_empty():
			break
	return failures


static func compare_live(
	seed_value: int,
	round_limit: int = DEFAULT_ROUND_LIMIT,
	_source_preview_mutation: String = ""
) -> Dictionary:
	var configuration: Dictionary = {"full_round_limit_hypothesis": round_limit}
	var source_state: Dictionary = ProtoRuleEngine.create_match(seed_value, configuration)
	var formal_state: Dictionary = FormalRuleEngine.create_match(seed_value, configuration)
	var policy_rng: Dictionary = ProtoSeededRandom.create_state(_policy_seed(seed_value))
	var red_context: RefCounted = ViewerContext.create_trusted("red")
	var black_context: RefCounted = ViewerContext.create_trusted("black")
	var action_offset: int = 0
	var intents: Array = []
	var source_execution_results: Array = []
	var formal_execution_results: Array = []
	while not bool(source_state["terminal"]):
		if bool(formal_state["terminal"]):
			return _live_failure(seed_value, action_offset, "terminal", source_state, formal_state)
		var source_prepared: Dictionary = ProtoRuleEngine.prepare_action(source_state)
		var formal_prepared: Dictionary = FormalRuleEngine.prepare_action(formal_state)
		if not bool(source_prepared.get("ok", false)) or not bool(formal_prepared.get("ok", false)):
			return {"ok": false, "failure": "seed=%d action=%d prepare" % [seed_value, action_offset]}
		var actor_side: String = str(source_state["active_side"])
		var selection: Dictionary = ProtoMoveRules.choose_legal_action_fast(
			source_state,
			actor_side,
			ProtoProjector.visibility_context(source_state, actor_side),
			policy_rng
		)
		var intent: Dictionary = selection.get("intent", {}).duplicate(true)
		var actor_context: RefCounted = red_context if actor_side == "red" else black_context
		var source_active_view: Dictionary = SourceMapper.player_view(
			source_state, actor_side, seed_value
		)
		var formal_active_view: Dictionary = ObserverProjector.project_player_view(
			formal_state, actor_context
		)
		if source_active_view != formal_active_view:
			return _live_failure(seed_value, action_offset, "active_player_view", source_active_view, formal_active_view)
		var source_preview: Dictionary = SourceMapper.action_preview(source_active_view, intent)
		var formal_preview: Dictionary = PublicActionPreviewer.preview_intent(formal_active_view, intent)
		if source_preview != formal_preview:
			return _live_failure(seed_value, action_offset, "action_preview", source_preview, formal_preview)
		var source_result: Dictionary = ProtoRuleEngine.submit_action(source_state, intent, {
			"trusted_generated_action": true,
			"include_state_summary": false,
			"preparation_token": str(source_prepared.get("preparation", {}).get("token", "")),
		})
		var formal_result: Dictionary = FormalRuleEngine.submit_action(formal_state, intent, {
			"trusted_generated_action": true,
			"include_state_summary": false,
			"preparation_token": str(formal_prepared.get("preparation", {}).get("token", "")),
			"public_classification": str(formal_preview.get("classification", "TENTATIVE")),
		})
		if not bool(source_result.get("ok", false)) or not bool(formal_result.get("ok", false)):
			return _live_failure(seed_value, action_offset, "submit", source_result, formal_result)
		source_execution_results.append(_execution_result(source_result))
		formal_execution_results.append(_execution_result(formal_result))
		var mapped_state: Dictionary = SourceMapper.full_state(source_state, seed_value)
		if mapped_state != formal_state:
			return _live_failure(seed_value, action_offset, "state", mapped_state, formal_state)
		if mapped_state.get("events", []) != formal_state.get("events", []):
			return _live_failure(seed_value, action_offset, "event", mapped_state.get("events", []), formal_state.get("events", []))
		var next_side: String = str(source_state.get("active_side", ""))
		var source_red_channels: Dictionary = SourceMapper.player_view_with_action_previews(
			source_state, "red", seed_value, next_side == "red"
		)
		var source_red: Dictionary = source_red_channels["player_view"]
		var formal_red: Dictionary = ObserverProjector.project_player_view(formal_state, red_context)
		if source_red != formal_red:
			return _live_failure(seed_value, action_offset, "red_player_view", source_red, formal_red)
		var source_black_channels: Dictionary = SourceMapper.player_view_with_action_previews(
			source_state, "black", seed_value, next_side == "black"
		)
		var source_black: Dictionary = source_black_channels["player_view"]
		var formal_black: Dictionary = ObserverProjector.project_player_view(formal_state, black_context)
		if source_black != formal_black:
			return _live_failure(seed_value, action_offset, "black_player_view", source_black, formal_black)
		var source_red_events: Array = SourceMapper.visible_events(source_state, "red")
		var formal_red_events: Array = VisibleOutcomeProjector.project_visible_events(formal_state, red_context)
		if source_red_events != formal_red_events:
			return _live_failure(seed_value, action_offset, "red_visible_event", source_red_events, formal_red_events)
		var source_black_events: Array = SourceMapper.visible_events(source_state, "black")
		var formal_black_events: Array = VisibleOutcomeProjector.project_visible_events(formal_state, black_context)
		if source_black_events != formal_black_events:
			return _live_failure(seed_value, action_offset, "black_visible_event", source_black_events, formal_black_events)
		var intent_id: String = "seed-%d-action-%d" % [seed_value, action_offset]
		var source_error: Dictionary = SourceMapper.visible_error(
			source_result, intent_id, int(source_state["action_index"])
		)
		var formal_error: Dictionary = VisibleOutcomeProjector.project_visible_error(
			formal_result, intent_id, int(formal_state["action_index"])
		)
		if source_error != formal_error:
			return _live_failure(seed_value, action_offset, "visible_error", source_error, formal_error)
		intents.append(intent.duplicate(true))
		var formal_red_frame: Dictionary = FormalMatchApplication._compose_safe_frame_from_dtos(
			formal_red, formal_red_events, formal_error,
			FormalMatchApplication._action_previews_for_view(formal_red), action_offset + 1
		)
		var formal_black_frame: Dictionary = FormalMatchApplication._compose_safe_frame_from_dtos(
			formal_black, formal_black_events, formal_error,
			FormalMatchApplication._action_previews_for_view(formal_black), action_offset + 1
		)
		var source_red_previews: Array = source_red_channels["action_previews"]
		var source_black_previews: Array = source_black_channels["action_previews"]
		if _source_preview_mutation == "drop_first" and action_offset == 0:
			if not source_red_previews.is_empty():
				source_red_previews.remove_at(0)
			elif not source_black_previews.is_empty():
				source_black_previews.remove_at(0)
		var source_red_frame: Dictionary = FormalMatchApplication._compose_safe_frame_from_dtos(
			source_red, source_red_events, source_error,
			source_red_previews, action_offset + 1
		)
		var source_black_frame: Dictionary = FormalMatchApplication._compose_safe_frame_from_dtos(
			source_black, source_black_events, source_error,
			source_black_previews, action_offset + 1
		)
		if source_red_frame != formal_red_frame or source_black_frame != formal_black_frame:
			return _live_failure(
				seed_value, action_offset, "observer_replay_frame",
				[source_red_frame, source_black_frame], [formal_red_frame, formal_black_frame]
			)
		action_offset += 1
	if not bool(formal_state["terminal"]):
		return _live_failure(seed_value, action_offset, "terminal", source_state, formal_state)
	var source_error_corpus: Array = _source_visible_error_corpus(seed_value)
	var formal_error_corpus: Array = _formal_visible_error_corpus(seed_value)
	if source_error_corpus != formal_error_corpus:
		return _live_failure(seed_value, action_offset, "visible_error_corpus", source_error_corpus, formal_error_corpus)
	var source_replay_semantics: Dictionary = SourceMapper.authoritative_replay_semantics(
		{
			"intents": intents,
			"execution_results": source_execution_results,
			"action_events": source_state.get("events", []),
		},
		SourceMapper.full_state(source_state, seed_value)
	)
	var formal_replay_semantics: Dictionary = SourceMapper.authoritative_replay_semantics(
		{
			"normalized_intents": intents,
			"execution_results": formal_execution_results,
			"domain_events": formal_state.get("events", []),
		},
		formal_state
	)
	if source_replay_semantics != formal_replay_semantics:
		return _live_failure(seed_value, action_offset, "authoritative_replay", source_replay_semantics, formal_replay_semantics)
	return {
		"ok": true,
		"seed": seed_value,
		"action_count": action_offset,
		"visible_error_checked": source_error_corpus.size() + action_offset,
		"authoritative_replay_checked": 1,
		"observer_replay_frames_checked": action_offset * 2,
		"failure": "",
	}


static func compare_live_range(
	start_seed: int,
	seed_count: int,
	round_limit: int = DEFAULT_ROUND_LIMIT
) -> Dictionary:
	var visible_error_checked: int = 0
	var authoritative_replay_checked: int = 0
	var observer_replay_frames_checked: int = 0
	for offset: int in seed_count:
		var result: Dictionary = compare_live(start_seed + offset, round_limit)
		if not bool(result.get("ok", false)):
			return result
		visible_error_checked += int(result.get("visible_error_checked", 0))
		authoritative_replay_checked += int(result.get("authoritative_replay_checked", 0))
		observer_replay_frames_checked += int(result.get("observer_replay_frames_checked", 0))
	return {
		"ok": true,
		"completed": seed_count,
		"visible_error_checked": visible_error_checked,
		"authoritative_replay_checked": authoritative_replay_checked,
		"observer_replay_frames_checked": observer_replay_frames_checked,
		"failure": "",
	}


static func _channel_step(
	action_offset: int,
	intent: Dictionary,
	state: Dictionary,
	red_view: Dictionary,
	black_view: Dictionary,
	red_events: Array,
	black_events: Array,
	preview: Dictionary,
	visible_error: Dictionary,
	red_context: RefCounted,
	black_context: RefCounted,
	red_frame_previews: Array,
	black_frame_previews: Array,
	use_source_dtos: bool
) -> Dictionary:
	var intents_prefix: Array = state.get("events", []).slice(0, action_offset + 1).map(
		func(event_value: Variant) -> Variant: return (event_value as Dictionary).get("intent", {})
	)
	var state_digest: String = FormalCanonical.digest(state)
	var event_digest: String = FormalCanonical.digest(state.get("events", []))
	var red_frame: Dictionary
	var black_frame: Dictionary
	if use_source_dtos:
		red_frame = FormalMatchApplication._compose_safe_frame_from_dtos(
			red_view, red_events, visible_error, red_frame_previews, action_offset + 1
		)
		black_frame = FormalMatchApplication._compose_safe_frame_from_dtos(
			black_view, black_events, visible_error, black_frame_previews, action_offset + 1
		)
	else:
		red_frame = FormalMatchApplication._compose_safe_frame(
			state, red_context, visible_error, action_offset + 1
		)
		black_frame = FormalMatchApplication._compose_safe_frame(
			state, black_context, visible_error, action_offset + 1
		)
	return {
		"action_offset": action_offset,
		"intent": intent.duplicate(true),
		"intent_digest": FormalCanonical.digest(intent),
		"state_digest": state_digest,
		"event_digest": event_digest,
		"red_player_view_digest": FormalCanonical.digest(red_view),
		"black_player_view_digest": FormalCanonical.digest(black_view),
		"red_visible_event_digest": FormalCanonical.digest(red_events),
		"black_visible_event_digest": FormalCanonical.digest(black_events),
		"visible_error_digest": FormalCanonical.digest(visible_error),
		"action_preview_digest": FormalCanonical.digest(preview),
		"red_observer_frame_digest": FormalCanonical.digest(red_frame),
		"black_observer_frame_digest": FormalCanonical.digest(black_frame),
		"replay_checkpoint_digest": FormalCanonical.digest(SourceMapper.replay_checkpoint(
			intents_prefix, state_digest, event_digest
		)),
	}


static func _source_visible_error_corpus(seed_value: int) -> Array:
	var state: Dictionary = ProtoRuleEngine.create_match(seed_value)
	var prepared: Dictionary = ProtoRuleEngine.prepare_action(state)
	var known_result: Dictionary = ProtoRuleEngine.submit_action(state, {
		"piece_id": "missing-piece", "action_type": "move", "target_cell": [1, 2], "skill_type": "",
	}, {
		"trusted_generated_action": false,
		"include_state_summary": false,
		"preparation_token": str(prepared.get("preparation", {}).get("token", "")),
	})
	return [
		SourceMapper.visible_error(known_result, "known-illegal", 0),
		SourceMapper.visible_error(_rejection_result("application", "stale_intent"), "stale-intent", 0),
		SourceMapper.visible_error(_rejection_result("application", "invalid_request"), "invalid-request", 0),
		SourceMapper.visible_error(_source_hidden_contact_result(seed_value), "hidden-contact", 1),
	]


static func _formal_visible_error_corpus(seed_value: int) -> Array:
	var application: RefCounted = FormalMatchApplication.create_trusted(seed_value, "red")
	var known_result: Dictionary = application.submit_intent(_application_intent(
		"known-illegal", 0, "missing-piece", "move", [1, 2]
	))
	var stale_result: Dictionary = application.submit_intent(_application_intent(
		"stale-intent", -1, "", "pass", []
	))
	var invalid_result: Dictionary = application.submit_intent({"intent_id": "invalid-request"})
	return [
		known_result.get("visible_error", {}).duplicate(true),
		stale_result.get("visible_error", {}).duplicate(true),
		invalid_result.get("visible_error", {}).duplicate(true),
		VisibleOutcomeProjector.project_visible_error(
			_formal_hidden_contact_result(seed_value), "hidden-contact", 1
		),
	]


static func _observer_replay_digest(steps: Array, side: String) -> String:
	var frames: Array = []
	for step: Dictionary in steps:
		frames.append(str(step.get("%s_observer_frame_digest" % side, "")))
	return FormalCanonical.digest(frames)


static func _application_intent(
	intent_id: String,
	expected_action_index: int,
	piece_id: String,
	action_type: String,
	target_cell: Array
) -> Dictionary:
	return {
		"schema_version": "veilfront-intent-v1",
		"intent_id": intent_id,
		"expected_action_index": expected_action_index,
		"piece_id": piece_id,
		"action_type": action_type,
		"target_cell": target_cell.duplicate(),
		"skill_type": "",
		"confirmation_token": "",
	}


static func _rejection_result(category: String, code: String) -> Dictionary:
	return {
		"ok": false,
		"consumed": false,
		"error": {"category": category, "code": code, "fields": []},
	}


static func _source_hidden_contact_result(seed_value: int) -> Dictionary:
	var state: Dictionary = ProtoRuleEngine.create_match(seed_value)
	_prepare_hidden_horse_leg_state(state)
	var prepared: Dictionary = ProtoRuleEngine.prepare_action(state)
	return ProtoRuleEngine.submit_action(state, {
		"piece_id": "red-horse-1", "action_type": "move", "target_cell": [7, 11], "skill_type": "",
	}, {
		"trusted_generated_action": false,
		"include_state_summary": false,
		"preparation_token": str(prepared.get("preparation", {}).get("token", "")),
		"public_classification": "TENTATIVE",
	})


static func _formal_hidden_contact_result(seed_value: int) -> Dictionary:
	var state: Dictionary = FormalRuleEngine.create_match(seed_value)
	_prepare_hidden_horse_leg_state(state)
	var prepared: Dictionary = FormalRuleEngine.prepare_action(state)
	return FormalRuleEngine.submit_action(state, {
		"piece_id": "red-horse-1", "action_type": "move", "target_cell": [7, 11], "skill_type": "",
	}, {
		"trusted_generated_action": false,
		"include_state_summary": false,
		"preparation_token": str(prepared.get("preparation", {}).get("token", "")),
		"public_classification": "TENTATIVE",
	})


static func _prepare_hidden_horse_leg_state(state: Dictionary) -> void:
	state["board"].clear()
	for piece_value: Variant in state["pieces"].values():
		var piece: Dictionary = piece_value
		piece["alive"] = false
		piece["in_reserve"] = false
		piece["position"] = []
	var red_horse: Dictionary = state["pieces"]["red-horse-1"]
	red_horse["alive"] = true
	red_horse["position"] = [5, 10]
	state["board"]["5,10"] = "red-horse-1"
	var black_horse: Dictionary = state["pieces"]["black-horse-1"]
	black_horse["alive"] = true
	black_horse["hidden"] = true
	black_horse["position"] = [6, 10]
	state["board"]["6,10"] = "black-horse-1"


static func _execution_result(result: Dictionary) -> Dictionary:
	return {
		"ok": bool(result.get("ok", false)),
		"consumed": bool(result.get("consumed", false)),
		"error": result.get("error", {}).duplicate(true),
	}


static func _capture_record(
	seed_value: int,
	state: Dictionary,
	intents: Array,
	steps: Array,
	failure: String
) -> Dictionary:
	return {
		"seed": seed_value,
		"failure": failure,
		"terminal": bool(state.get("terminal", false)),
		"winner": str(state.get("winner", "")),
		"win_reason": str(state.get("win_reason", "")),
		"action_count": int(state.get("action_index", 0)),
		"intents": intents.duplicate(true),
		"steps": steps.duplicate(true),
	}


static func _policy_seed(seed_value: int) -> int:
	return int((seed_value * 1103515245 + 12345) & 0x7fffffff)


static func _live_failure(
	seed_value: int,
	action_offset: int,
	channel: String,
	expected: Variant,
	actual: Variant
) -> Dictionary:
	return {
		"ok": false,
		"failure": "seed=%d action=%d channel=%s expected=%s actual=%s" % [
			seed_value, action_offset, channel,
			FormalCanonical.digest(expected), FormalCanonical.digest(actual),
		],
	}


static func _normalize_domain_intent(intent: Dictionary) -> Dictionary:
	var target: Array = []
	for coordinate_value: Variant in intent.get("target_cell", []):
		target.append(int(coordinate_value))
	return {
		"piece_id": str(intent.get("piece_id", "")),
		"action_type": str(intent.get("action_type", "")),
		"target_cell": target,
		"skill_type": str(intent.get("skill_type", "")),
	}
