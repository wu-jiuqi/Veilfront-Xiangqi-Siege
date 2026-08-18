extends SceneTree

const RuleEngine = preload("res://scripts/game/domain/rule_engine.gd")
const ViewerContext = preload("res://scripts/game/projection/viewer_context.gd")
const ObserverProjector = preload("res://scripts/game/projection/observer_projector.gd")
const PublicActionPreviewer = preload("res://scripts/game/projection/public_action_previewer.gd")
const VisibleOutcomeProjector = preload("res://scripts/game/projection/visible_outcome_projector.gd")
const FormalMatchApplication = preload("res://scripts/game/application/formal_match_application.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: Dictionary = RuleEngine.create_match(471001, {"full_round_limit_hypothesis": 50})
	var red_context: RefCounted = ViewerContext.create_trusted("red")
	var black_context: RefCounted = ViewerContext.create_trusted("black")
	var red_before: Dictionary = ObserverProjector.project_player_view(state, red_context)
	var selected_preview: Dictionary = PublicActionPreviewer.generate_action_intents(red_before)[0]
	var intent: Dictionary = {
		"piece_id": str(selected_preview["piece_id"]),
		"action_type": str(selected_preview["action_type"]),
		"target_cell": selected_preview["target_cell"].duplicate(),
		"skill_type": str(selected_preview["skill_type"]),
	}
	var prepared: Dictionary = RuleEngine.prepare_action(state)
	var result: Dictionary = RuleEngine.submit_action(state, intent, {
		"trusted_generated_action": false,
		"include_state_summary": false,
		"preparation_token": str(prepared.get("preparation", {}).get("token", "")),
		"public_classification": str(selected_preview.get("classification", "TENTATIVE")),
	})
	if not bool(result.get("consumed", false)):
		push_error("OBSERVER_LIVE_FRAME_CONTRACT_FAIL fixture_not_consumed")
		quit(1)
		return
	var red_view: Dictionary = ObserverProjector.project_player_view(state, red_context)
	var black_view: Dictionary = ObserverProjector.project_player_view(state, black_context)
	var red_expected_previews: Array = []
	var black_expected_previews: Array = PublicActionPreviewer.generate_action_intents(black_view)
	var visible_error: Dictionary = VisibleOutcomeProjector.project_visible_error(
		result, "red-first-action", 0
	)
	var red_frame: Dictionary = FormalMatchApplication._compose_safe_frame(
		state, red_context, visible_error, 1
	)
	var black_frame: Dictionary = FormalMatchApplication._compose_safe_frame(
		state, black_context, visible_error, 1
	)
	if red_frame["action_previews"] != red_expected_previews \
	or black_frame["action_previews"] != black_expected_previews \
	or red_frame["player_view_or_digest"] != red_view \
	or black_frame["player_view_or_digest"] != black_view:
		push_error("OBSERVER_LIVE_FRAME_CONTRACT_FAIL red_to_black_post_settlement_semantics")
		quit(1)
		return
	var legacy_red_previews: Array = [selected_preview]
	var legacy_black_previews: Array = []
	if legacy_red_previews == red_frame["action_previews"] \
	or legacy_black_previews == black_frame["action_previews"]:
		push_error("OBSERVER_LIVE_FRAME_CONTRACT_FAIL legacy_mutation_was_not_rejected")
		quit(1)
		return
	var black_selected_preview: Dictionary = black_frame["action_previews"][0]
	var black_intent: Dictionary = {
		"piece_id": str(black_selected_preview["piece_id"]),
		"action_type": str(black_selected_preview["action_type"]),
		"target_cell": black_selected_preview["target_cell"].duplicate(),
		"skill_type": str(black_selected_preview["skill_type"]),
	}
	prepared = RuleEngine.prepare_action(state)
	result = RuleEngine.submit_action(state, black_intent, {
		"trusted_generated_action": false,
		"include_state_summary": false,
		"preparation_token": str(prepared.get("preparation", {}).get("token", "")),
		"public_classification": str(black_selected_preview.get("classification", "TENTATIVE")),
	})
	if not bool(result.get("consumed", false)):
		push_error("OBSERVER_LIVE_FRAME_CONTRACT_FAIL black_fixture_not_consumed")
		quit(1)
		return
	visible_error = VisibleOutcomeProjector.project_visible_error(result, "black-first-action", 1)
	red_frame = FormalMatchApplication._compose_safe_frame(state, red_context, visible_error, 2)
	black_frame = FormalMatchApplication._compose_safe_frame(state, black_context, visible_error, 2)
	if black_frame["action_previews"] != [] \
	or red_frame["action_previews"] != PublicActionPreviewer.generate_action_intents(
		red_frame["player_view_or_digest"]
	):
		push_error("OBSERVER_LIVE_FRAME_CONTRACT_FAIL black_to_red_post_settlement_semantics")
		quit(1)
		return
	if [black_selected_preview] == black_frame["action_previews"] \
	or [] == red_frame["action_previews"]:
		push_error("OBSERVER_LIVE_FRAME_CONTRACT_FAIL reverse_legacy_mutation_was_not_rejected")
		quit(1)
		return
	print("OBSERVER_LIVE_FRAME_CONTRACT_PASS")
	quit(0)
