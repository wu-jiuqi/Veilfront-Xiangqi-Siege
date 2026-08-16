extends SceneTree

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const Projector = preload("res://scripts/prototype/view/player_view_projector.gd")
const AiPlayerView = preload("res://scripts/prototype/ai/ai_player_view.gd")
const PublicRules = preload("res://scripts/prototype/ai/ai_public_rules.gd")
const Memory = preload("res://scripts/prototype/ai/ai_memory.gd")
const DecisionEngine = preload("res://scripts/prototype/ai/ai_decision_engine.gd")
const AiSeedDeriver = preload("res://scripts/prototype/ai/ai_seed_deriver.gd")

const DIFFICULTIES: Dictionary = {
	"easy": "res://resources/prototype/ai/prototype_low_budget_hypothesis.tres",
	"medium": "res://resources/prototype/ai/prototype_default_hypothesis.tres",
	"hard": "res://resources/prototype/ai/prototype_high_budget_hypothesis.tres",
	"expert": "res://resources/prototype/ai/prototype_expert_tactical_hypothesis.tres",
}
const DIFFICULTY_IDS: Array[String] = ["easy", "medium", "hard", "expert"]

var failures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = _parse_options()
	var requested_seeds: int = int(options["seeds"])
	var start_seed: int = int(options["start_seed"])
	var records: Array = []
	var actions_by_seed: Dictionary = {}
	var per_difficulty: Dictionary = {}
	for difficulty_id: String in DIFFICULTY_IDS:
		per_difficulty[difficulty_id] = {
			"records": 0,
			"determinism_mismatches": 0,
			"hidden_equivalence_mismatches": 0,
			"mapping_failures": 0,
			"submit_failures": 0,
			"evaluated_candidates_total": 0,
			"evaluated_candidates_min": 2147483647,
			"evaluated_candidates_max": 0,
			"selected_kind_counts": {},
			"selected_action_ids": {},
			"profile_config_digest": "",
		}

	for seed_offset: int in requested_seeds:
		var seed_value: int = start_seed + seed_offset
		actions_by_seed[seed_value] = {}
		for difficulty_id: String in DIFFICULTY_IDS:
			var record: Dictionary = _run_record(seed_value, difficulty_id)
			records.append(record)
			_accumulate(per_difficulty[difficulty_id], record)
			actions_by_seed[seed_value][difficulty_id] = str(record.get("selected_action_id", ""))
			if not bool(record.get("ok", false)):
				failures.append({
					"seed": seed_value,
					"difficulty_id": difficulty_id,
					"failure_codes": record.get("failure_codes", []).duplicate(),
				})

	var differences: Dictionary = _difference_statistics(actions_by_seed)
	var summary: Dictionary = {
		"schema_version": "player-view-ai-seed-matrix-summary-v1",
		"simulation_mode": "player_view_ai_one_decision_fairness_matrix",
		"start_seed": start_seed,
		"requested_seeds_per_difficulty": requested_seeds,
		"difficulty_count": DIFFICULTY_IDS.size(),
		"records_count": records.size(),
		"failure_count": failures.size(),
		"failures": failures.duplicate(true),
		"determinism_mismatch_count": _sum_metric(per_difficulty, "determinism_mismatches"),
		"hidden_equivalence_mismatch_count": _sum_metric(per_difficulty, "hidden_equivalence_mismatches"),
		"mapping_failure_count": _sum_metric(per_difficulty, "mapping_failures"),
		"submit_failure_count": _sum_metric(per_difficulty, "submit_failures"),
		"per_difficulty": _finalize_difficulty_stats(per_difficulty),
		"difference_statistics": differences,
		"records_digest": Canonical.digest(records),
		"contract_1000_seeds_satisfied": false,
		"scope_note": "Producer PlayerView AI one-decision fairness matrix; not independent QA and not the Contract v2 1000-seed gate.",
	}
	var manifest_ok: bool = _write_manifest(str(options["manifest_path"]), records, summary)
	if not manifest_ok:
		summary["failure_count"] = int(summary["failure_count"]) + 1
		summary["failures"].append({"failure_codes": ["manifest_write_failed"]})
	print("PLAYER_VIEW_AI_SEED_MATRIX_SUMMARY ", Canonical.json(summary))
	quit(0 if int(summary["failure_count"]) == 0 else 1)


func _run_record(seed_value: int, difficulty_id: String) -> Dictionary:
	var failure_codes: Array[String] = []
	var state_a: Dictionary = MatchState.create(seed_value)
	var state_b: Dictionary = MatchState.clone(state_a)
	MatchState.relocate_piece(state_b, "black-pawn-1", Vector2i(2, 18))
	var view_a: Dictionary = Projector.project(state_a, MatchState.RED)
	var view_b: Dictionary = Projector.project(state_b, MatchState.RED)
	var previews_a: Array = Projector.generate_action_intents(view_a)
	var projection_a: Dictionary = Projector.export_ai_projection_from_view(view_a)
	var projection_b: Dictionary = Projector.export_ai_projection_from_view(view_b)
	var hidden_equivalent: bool = Canonical.digest(view_a) == Canonical.digest(view_b) 		and Canonical.digest(projection_a) == Canonical.digest(projection_b)
	if not hidden_equivalent:
		failure_codes.append("hidden_equivalent_projection_mismatch")
	var profile: Resource = load(str(DIFFICULTIES[difficulty_id])).duplicate(true)
	var ai_seed: int = AiSeedDeriver.derive(
		seed_value + 880021,
		str(projection_a["decision_id"])
	)
	var decision_a: Dictionary = _decide(projection_a, profile, ai_seed)
	var decision_repeat: Dictionary = _decide(projection_a, profile, ai_seed)
	var decision_hidden: Dictionary = _decide(projection_b, profile, ai_seed)
	if not bool(decision_a.get("ok", false)) or not bool(decision_repeat.get("ok", false)) 	or not bool(decision_hidden.get("ok", false)):
		failure_codes.append("decision_failed")
	var deterministic: bool = decision_a.get("action", {}) == decision_repeat.get("action", {}) 		and Canonical.digest(decision_a.get("audit", {})) 			== Canonical.digest(decision_repeat.get("audit", {}))
	if not deterministic:
		failure_codes.append("determinism_mismatch")
	var hidden_decision_equal: bool = decision_a.get("action", {}) == decision_hidden.get("action", {}) 		and Canonical.digest(decision_a.get("audit", {})) 			== Canonical.digest(decision_hidden.get("audit", {}))
	if not hidden_decision_equal:
		failure_codes.append("hidden_equivalent_decision_mismatch")
	var selected_action_id: String = str(decision_a.get("action", {}).get("id", ""))
	var preview: Dictionary = _preview_for_action_id(previews_a, selected_action_id)
	var action_id_mapped: bool = not preview.is_empty()
	if not action_id_mapped:
		failure_codes.append("selected_action_id_unmapped")
	var consumed: bool = false
	var result_code: String = ""
	if action_id_mapped:
		var submitted: Dictionary = RuleEngine.submit_action(
			state_a,
			_intent_from_preview(preview),
			{"include_state_summary": false}
		)
		consumed = bool(submitted.get("ok", false)) and bool(submitted.get("consumed", false))
		if consumed:
			result_code = str(submitted.get("event", {}).get("outcome", {}).get("result_code", ""))
		else:
			failure_codes.append("selected_public_action_not_consumed")
	var audit: Dictionary = decision_a.get("audit", {}).duplicate(true)
	var budget: Dictionary = audit.get("budget", {})
	return {
		"schema_version": "player-view-ai-seed-matrix-record-v1",
		"ok": failure_codes.is_empty(),
		"seed": seed_value,
		"difficulty_id": difficulty_id,
		"profile_id": str(profile.profile_id),
		"profile_config_digest": Canonical.digest(profile.audit_snapshot()),
		"player_view_digest": Canonical.digest(view_a),
		"ai_projection_digest": Canonical.digest(projection_a),
		"input_projection_digest": str(
			audit.get("input_projection_summary", {}).get("projection_digest", "")
		),
		"ai_seed": ai_seed,
		"available_candidates": int(budget.get("available_candidates", 0)),
		"evaluated_candidates": int(budget.get("evaluated_candidates", 0)),
		"candidate_limit_hypothesis": int(budget.get("candidate_limit_hypothesis", 0)),
		"selected_action_id": selected_action_id,
		"selected_kind": str(decision_a.get("action", {}).get("kind", "")),
		"action_id_mapped": action_id_mapped,
		"selected_action_consumed": consumed,
		"public_result_code": result_code,
		"determinism_match": deterministic,
		"hidden_equivalent_projection": hidden_equivalent,
		"hidden_equivalent_action_and_audit": hidden_decision_equal,
		"full_audit_digest": Canonical.digest(audit),
		"decision_audit": audit,
		"failure_codes": failure_codes,
	}


func _decide(projection: Dictionary, profile: Resource, ai_seed: int) -> Dictionary:
	var ai_view: RefCounted = AiPlayerView.new(projection)
	if not ai_view.is_valid():
		return {
			"ok": false,
			"error_code": "invalid_ai_player_view",
			"errors": ai_view.get_validation_errors(),
		}
	return DecisionEngine.new().decide(
		ai_view,
		PublicRules.new(_public_rules()),
		Memory.new(_empty_memory()),
		ai_seed,
		profile
	)


func _preview_for_action_id(previews: Array, selected_action_id: String) -> Dictionary:
	for preview: Dictionary in previews:
		if str(preview["id"]) == selected_action_id 		and str(preview["classification"]) != Projector.KNOWN_ILLEGAL:
			return preview
	return {}


func _intent_from_preview(preview: Dictionary) -> Dictionary:
	return {
		"piece_id": str(preview["piece_id"]),
		"action_type": str(preview["action_type"]),
		"target_cell": preview["target_cell"].duplicate(),
		"skill_type": str(preview["skill_type"]),
	}


func _accumulate(stats: Dictionary, record: Dictionary) -> void:
	stats["records"] = int(stats["records"]) + 1
	if not bool(record.get("determinism_match", false)):
		stats["determinism_mismatches"] = int(stats["determinism_mismatches"]) + 1
	if not bool(record.get("hidden_equivalent_projection", false)) 	or not bool(record.get("hidden_equivalent_action_and_audit", false)):
		stats["hidden_equivalence_mismatches"] = int(stats["hidden_equivalence_mismatches"]) + 1
	if not bool(record.get("action_id_mapped", false)):
		stats["mapping_failures"] = int(stats["mapping_failures"]) + 1
	if not bool(record.get("selected_action_consumed", false)):
		stats["submit_failures"] = int(stats["submit_failures"]) + 1
	var evaluated: int = int(record.get("evaluated_candidates", 0))
	stats["evaluated_candidates_total"] = int(stats["evaluated_candidates_total"]) + evaluated
	stats["evaluated_candidates_min"] = mini(int(stats["evaluated_candidates_min"]), evaluated)
	stats["evaluated_candidates_max"] = maxi(int(stats["evaluated_candidates_max"]), evaluated)
	var kind: String = str(record.get("selected_kind", ""))
	stats["selected_kind_counts"][kind] = int(stats["selected_kind_counts"].get(kind, 0)) + 1
	var action_id: String = str(record.get("selected_action_id", ""))
	stats["selected_action_ids"][action_id] = int(stats["selected_action_ids"].get(action_id, 0)) + 1
	stats["profile_config_digest"] = str(record.get("profile_config_digest", ""))


func _finalize_difficulty_stats(per_difficulty: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for difficulty_id: String in DIFFICULTY_IDS:
		var stats: Dictionary = per_difficulty[difficulty_id].duplicate(true)
		var count: int = int(stats["records"])
		stats["evaluated_candidates_average"] = (
			float(stats["evaluated_candidates_total"]) / float(count) if count > 0 else 0.0
		)
		stats["unique_selected_action_count"] = stats["selected_action_ids"].size()
		stats.erase("selected_action_ids")
		result[difficulty_id] = stats
	return result


func _difference_statistics(actions_by_seed: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"easy_vs_medium_different": 0,
		"medium_vs_hard_different": 0,
		"easy_vs_hard_different": 0,
		"hard_vs_expert_different": 0,
		"medium_vs_expert_different": 0,
		"all_four_same": 0,
	}
	for actions: Dictionary in actions_by_seed.values():
		var easy: String = str(actions.get("easy", ""))
		var medium: String = str(actions.get("medium", ""))
		var hard: String = str(actions.get("hard", ""))
		var expert: String = str(actions.get("expert", ""))
		if easy != medium:
			result["easy_vs_medium_different"] = int(result["easy_vs_medium_different"]) + 1
		if medium != hard:
			result["medium_vs_hard_different"] = int(result["medium_vs_hard_different"]) + 1
		if easy != hard:
			result["easy_vs_hard_different"] = int(result["easy_vs_hard_different"]) + 1
		if hard != expert:
			result["hard_vs_expert_different"] = int(result["hard_vs_expert_different"]) + 1
		if medium != expert:
			result["medium_vs_expert_different"] = int(result["medium_vs_expert_different"]) + 1
		if easy == medium and medium == hard and hard == expert:
			result["all_four_same"] = int(result["all_four_same"]) + 1
	return result


func _sum_metric(per_difficulty: Dictionary, key: String) -> int:
	var total: int = 0
	for stats: Dictionary in per_difficulty.values():
		total += int(stats[key])
	return total


func _write_manifest(path: String, records: Array, summary: Dictionary) -> bool:
	if path.is_empty():
		return true
	var absolute_directory: String = ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	for record: Dictionary in records:
		file.store_line(Canonical.json(record))
	file.store_line(Canonical.json(summary))
	file.close()
	return true


func _parse_options() -> Dictionary:
	var result: Dictionary = {
		"seeds": 100,
		"start_seed": 471001,
		"manifest_path": "user://prototype/test-output/player_view_ai_seed_matrix_100x3.jsonl",
	}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < args.size():
		var token: String = args[index]
		if token in ["--seeds", "--start-seed", "--manifest-path"] and index + 1 < args.size():
			index += 1
			match token:
				"--seeds": result["seeds"] = int(args[index])
				"--start-seed": result["start_seed"] = int(args[index])
				"--manifest-path": result["manifest_path"] = args[index]
		index += 1
	result["seeds"] = maxi(1, int(result["seeds"]))
	return result


func _public_rules() -> Dictionary:
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


func _empty_memory() -> Dictionary:
	return {
		"schema_version": "ai-memory-v1",
		"recent_action_ids": [],
		"action_visit_counts": {},
		"last_visible_piece_turns": {},
	}
