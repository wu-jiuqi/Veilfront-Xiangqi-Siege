extends SceneTree

const PlayerView = preload("res://scripts/prototype/ai/ai_player_view.gd")
const PublicRules = preload("res://scripts/prototype/ai/ai_public_rules.gd")
const Memory = preload("res://scripts/prototype/ai/ai_memory.gd")
const DecisionEngine = preload("res://scripts/prototype/ai/ai_decision_engine.gd")
const DifficultyConfig = preload("res://scripts/prototype/ai/ai_difficulty_config.gd")


func _initialize() -> void:
	run_suite()
	print("AI fairness prototype tests passed")
	quit(0)


static func run_suite() -> void:
	_test_hidden_equivalent_pair_is_indistinguishable()
	_test_unknown_player_view_field_is_rejected()
	_test_semantic_collection_order_is_canonical()
	_test_seed_change_is_auditable()
	_test_hypothesis_resources_load()


static func _test_hidden_equivalent_pair_is_indistinguishable() -> void:
	var hidden_state_a: Dictionary = {
		"public_projection": _base_projection(),
		"hidden_enemy_pieces": [{"id": "enemy-hidden-a", "position": [8, 23]}],
		"unpublished_bombardment_cells": [[1, 7], [2, 7], [3, 7]],
	}
	var hidden_state_b: Dictionary = {
		"public_projection": _base_projection(),
		"hidden_enemy_pieces": [{"id": "enemy-hidden-b", "position": [4, 18]}],
		"unpublished_bombardment_cells": [[6, 12], [7, 12], [8, 12]],
	}
	var view_a: RefCounted = PlayerView.new(_test_projection_boundary(hidden_state_a))
	var view_b: RefCounted = PlayerView.new(_test_projection_boundary(hidden_state_b))
	var rules: RefCounted = PublicRules.new(_public_rules())
	var memory: RefCounted = Memory.new(_empty_memory())
	var config: Resource = DifficultyConfig.new()
	var result_a: Dictionary = DecisionEngine.new().decide(view_a, rules, memory, 424242, config)
	var result_b: Dictionary = DecisionEngine.new().decide(view_b, rules, memory, 424242, config)
	assert(result_a.ok and result_b.ok, "paired AI decisions must both succeed")
	assert(result_a.action == result_b.action, "hidden differences must not change the action")
	assert(
		result_a.audit.input_projection_summary == result_b.audit.input_projection_summary,
		"hidden differences must not change the AI input projection summary"
	)
	assert(
		result_a.audit.decision_input_digest == result_b.audit.decision_input_digest,
		"the complete decision input digest must match for the paired case"
	)


static func _test_unknown_player_view_field_is_rejected() -> void:
	var projection: Dictionary = _base_projection()
	projection["hidden_enemy_pieces"] = []
	var view: RefCounted = PlayerView.new(projection)
	assert(not view.is_valid(), "PlayerView must reject fields outside its public allowlist")
	var result: Dictionary = DecisionEngine.new().decide(
		view,
		PublicRules.new(_public_rules()),
		Memory.new(_empty_memory()),
		7,
		DifficultyConfig.new()
	)
	assert(not result.ok and result.error_code == "invalid_ai_input")


static func _test_semantic_collection_order_is_canonical() -> void:
	var projection_a: Dictionary = _base_projection()
	var projection_b: Dictionary = _base_projection()
	projection_b.legal_actions.reverse()
	projection_b.visible_pieces.reverse()
	var view_a: RefCounted = PlayerView.new(projection_a)
	var view_b: RefCounted = PlayerView.new(projection_b)
	assert(view_a.input_summary().projection_digest == view_b.input_summary().projection_digest)
	var engine: RefCounted = DecisionEngine.new()
	var rules: RefCounted = PublicRules.new(_public_rules())
	var memory: RefCounted = Memory.new(_empty_memory())
	var config: Resource = DifficultyConfig.new()
	var result_a: Dictionary = engine.decide(view_a, rules, memory, 101, config)
	var result_b: Dictionary = engine.decide(view_b, rules, memory, 101, config)
	assert(result_a.action == result_b.action, "serialization order must not change the decision")


static func _test_seed_change_is_auditable() -> void:
	var result: Dictionary = DecisionEngine.new().decide(
		PlayerView.new(_base_projection()),
		PublicRules.new(_public_rules()),
		Memory.new(_empty_memory()),
		9001,
		DifficultyConfig.new()
	)
	assert(result.ok)
	assert(result.audit.candidate_sampling.ai_seed == 9001)
	assert(result.audit.has("candidates") and result.audit.has("random_sampling"))
	assert(result.audit.has("budget") and result.audit.has("final_action"))


static func _test_hypothesis_resources_load() -> void:
	for path: String in [
		"res://resources/prototype/ai/prototype_low_budget_hypothesis.tres",
		"res://resources/prototype/ai/prototype_default_hypothesis.tres",
		"res://resources/prototype/ai/prototype_high_budget_hypothesis.tres",
	]:
		var config: Resource = ResourceLoader.load(path)
		assert(config != null, "AI prototype config must load: %s" % path)
		assert(config.conclusion_status == "hypothesis")


static func _test_projection_boundary(state_fixture: Dictionary) -> Dictionary:
	# This fixture stands in for the technology-owned one-way projection. The AI is
	# handed only this value; the hidden sibling fields are intentionally unreachable.
	return state_fixture.public_projection.duplicate(true)


static func _base_projection() -> Dictionary:
	return {
		"schema_version": "player-view-ai-v1",
		"decision_id": "turn-12-red",
		"viewer_side": "red",
		"turn_index": 12,
		"visible_pieces": [
			{"id": "red-rook-1", "side": "red", "piece_type": "rook", "position": [4, 10], "status_tags": []},
			{"id": "black-pawn-2", "side": "black", "piece_type": "pawn", "position": [4, 12], "status_tags": ["visible"]},
		],
		"public_flags": [
			{"id": "flag-a", "position": [3, 12], "owner": "neutral", "capture_progress": 0},
		],
		"public_walls": [
			{"side": "red", "status": "intact"},
			{"side": "black", "status": "intact"},
		],
		"legal_actions": [
			{
				"id": "move:red-rook-1:4,10:4,12",
				"kind": "move",
				"actor_id": "red-rook-1",
				"origin": [4, 10],
				"target": [4, 12],
				"visible_captures": [{"piece_id": "black-pawn-2", "piece_type": "pawn"}],
				"reveal_cell_count": 3,
				"occupies_flag": false,
				"attacks_wall": false,
				"path_length": 2,
			},
			{
				"id": "move:red-rook-1:4,10:3,12",
				"kind": "move",
				"actor_id": "red-rook-1",
				"origin": [4, 10],
				"target": [3, 12],
				"visible_captures": [],
				"reveal_cell_count": 5,
				"occupies_flag": true,
				"attacks_wall": false,
				"path_length": 3,
			},
		],
		"public_events": [
			{"id": "event-11", "event_type": "move", "actor_side": "black", "position": [4, 12]},
		],
	}


static func _public_rules() -> Dictionary:
	return {
		"schema_version": "public-ai-rules-v1",
		"board_width": 9,
		"board_height": 24,
		"piece_values": {"pawn": 10, "rook": 50, "general": 10000},
		"action_kind_bias": {"move": 0, "bombard": 4},
	}


static func _empty_memory() -> Dictionary:
	return {
		"schema_version": "ai-memory-v1",
		"recent_action_ids": [],
		"action_visit_counts": {},
		"last_visible_piece_turns": {},
	}
