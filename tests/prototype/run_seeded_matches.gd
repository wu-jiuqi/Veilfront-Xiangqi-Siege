extends SceneTree

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const MatchSimulator = preload("res://scripts/prototype/simulation/match_simulator.gd")

const COMPACT_RECORD_SCHEMA_VERSION := "seeded-match-compact-record-v2"
const BATCH_SUMMARY_SCHEMA_VERSION := "seeded-match-batch-summary-v2"
const MANIFEST_HEADER_SCHEMA_VERSION := "seeded-match-manifest-header-v2"
const MANIFEST_SUMMARY_SCHEMA_VERSION := "seeded-match-manifest-summary-v2"
const EXPECTED_FLAG_REGION := {"x_min": 1, "x_max": 9, "y_min": 9, "y_max": 16}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = _parse_options(OS.get_cmdline_user_args())
	if not options.get("ok", false):
		push_error("SEEDED_MATCH_ARGUMENT_ERROR: %s" % options.get("error", "invalid_arguments"))
		quit(1)
		return
	var seed_count: int = int(options["seeds"])
	var start_seed: int = int(options["start_seed"])
	var round_limit: int = int(options["round_limit"])
	var replay_samples: int = mini(int(options["replay_samples"]), seed_count)
	var manifest_path: String = str(options["manifest_path"])
	var failures: Array = []
	var lengths: Array[int] = []
	var reason_counts: Dictionary = {}
	var winner_counts: Dictionary = {MatchState.RED: 0, MatchState.BLACK: 0, "draw": 0}
	var aggregate_metrics: Dictionary = {
		"bombardments": 0,
		"rook_multi_targets": 0,
		"rescues": 0,
		"wall_breaches": 0,
		"wall_repairs": 0,
		"flag_captures": 0,
		"candidate_evaluations": 0,
	}
	var aggregate_profile_msec: Dictionary = {}
	var compact_results: Array = []
	var replay_verified_count: int = 0
	var determinism_checked_count: int = 0
	var determinism_mismatches: Array = []
	var flag_region_counts: Dictionary = {}
	var flag_cell_counts: Dictionary = {}
	var invalid_flag_distribution_count: int = 0
	for offset: int in seed_count:
		var seed_value: int = start_seed + offset
		var result: Dictionary = MatchSimulator.run_match(seed_value, {
			"full_round_limit_hypothesis": round_limit,
			"verify_replay": offset < replay_samples,
		})
		if not result.get("ok", false):
			failures.append({"seed": seed_value, "failures": result.get("failures", [])})
			continue
		var repeated: Dictionary = MatchSimulator.run_match(seed_value, {
			"full_round_limit_hypothesis": round_limit,
			"verify_replay": false,
		})
		determinism_checked_count += 1
		var determinism_match: bool = repeated.get("ok", false) and _determinism_matches(result, repeated)
		if not determinism_match:
			var mismatch: Dictionary = {
				"seed": seed_value,
				"first_failures": result.get("failures", []),
				"second_failures": repeated.get("failures", []),
			}
			determinism_mismatches.append(mismatch)
			failures.append({"seed": seed_value, "failures": ["determinism_mismatch"]})
		lengths.append(int(result["full_round_count"]))
		if result["replay_verified"]:
			replay_verified_count += 1
		reason_counts[result["win_reason"]] = int(reason_counts.get(result["win_reason"], 0)) + 1
		winner_counts[result["winner"]] = int(winner_counts.get(result["winner"], 0)) + 1
		for metric: String in aggregate_metrics.keys():
			aggregate_metrics[metric] = int(aggregate_metrics[metric]) + int(result["metrics"][metric])
		for phase: String in result["profile_msec"].keys():
			aggregate_profile_msec[phase] = snappedf(
				float(aggregate_profile_msec.get(phase, 0.0)) + float(result["profile_msec"][phase]), 0.001
			)
		var initial_flag_region: Dictionary = _normalized_flag_region(result.get("initial_flag_region", {}))
		var initial_flag_positions: Array = result.get("initial_flag_positions", [])
		var flag_distribution_failure: String = _flag_distribution_failure(
			initial_flag_region, initial_flag_positions
		)
		if not flag_distribution_failure.is_empty():
			invalid_flag_distribution_count += 1
			failures.append({"seed": seed_value, "failures": [flag_distribution_failure]})
		var region_key: String = Canonical.json(initial_flag_region)
		flag_region_counts[region_key] = int(flag_region_counts.get(region_key, 0)) + 1
		for position_value: Variant in initial_flag_positions:
			var position := Canonical.coordinate(position_value)
			var cell_key: String = Canonical.cell_key(position)
			flag_cell_counts[cell_key] = int(flag_cell_counts.get(cell_key, 0)) + 1
		compact_results.append({
			"schema_version": COMPACT_RECORD_SCHEMA_VERSION,
			"seed": seed_value,
			"winner": result["winner"],
			"reason": result["win_reason"],
			"rounds": result["full_round_count"],
			"flag_counts": result["flag_counts"].duplicate(true),
			"initial_flag_positions": initial_flag_positions.duplicate(true),
			"initial_flag_region": initial_flag_region.duplicate(true),
			"state_digest": result["state_digest"],
			"event_digest": result["event_log_digest"],
			"determinism_match": determinism_match,
			"replay_sample": offset < replay_samples,
		})
	lengths.sort()
	var summary: Dictionary = {
		"schema_version": BATCH_SUMMARY_SCHEMA_VERSION,
		"simulation_mode": "rules_stress_full_state_policy",
		"requested_seeds": seed_count,
		"completed_matches": compact_results.size(),
		"failure_count": failures.size(),
		"start_seed": start_seed,
		"full_round_limit_hypothesis": round_limit,
		"round_limit_status": "hypothesis_cli_overridable",
		"replay_sample_count": replay_samples,
		"replay_verified_count": replay_verified_count,
		"determinism_checked_count": determinism_checked_count,
		"determinism_mismatch_count": determinism_mismatches.size(),
		"determinism_mismatches": determinism_mismatches,
		"winner_counts": winner_counts,
		"reason_counts": reason_counts,
		"round_length": {
			"min": lengths[0] if not lengths.is_empty() else 0,
			"p50": _percentile(lengths, 0.50),
			"p90": _percentile(lengths, 0.90),
			"p95": _percentile(lengths, 0.95),
			"max": lengths.back() if not lengths.is_empty() else 0,
		},
		"metrics": aggregate_metrics,
		"initial_flag_distribution": {
			"expected_region": EXPECTED_FLAG_REGION.duplicate(true),
			"expected_cell_count": 72,
			"observed_cell_count": flag_cell_counts.size(),
			"invalid_match_count": invalid_flag_distribution_count,
			"region_counts": flag_region_counts,
			"cell_counts": flag_cell_counts,
		},
		"profile_msec_total": aggregate_profile_msec,
		"records_count": compact_results.size(),
		"records_digest": _records_digest(compact_results),
		"failures": failures,
	}
	for record: Dictionary in compact_results:
		print("SEEDED_MATCH_RECORD %s" % Canonical.json(record))
	if not manifest_path.is_empty():
		var manifest_error: String = _write_manifest(manifest_path, compact_results, summary)
		if not manifest_error.is_empty():
			failures.append({"seed": -1, "failures": [manifest_error]})
			summary["failure_count"] = failures.size()
			summary["failures"] = failures
	print("SEEDED_MATCHES_SUMMARY %s" % Canonical.json(summary))
	if failures.is_empty() and compact_results.size() == seed_count:
		quit(0)
		return
	push_error("SEEDED_MATCHES_FAILED count=%d" % failures.size())
	quit(1)


static func _parse_options(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {
		"ok": true,
		"seeds": 1000,
		"start_seed": 1,
		"round_limit": MatchState.DEFAULT_FULL_ROUND_LIMIT_HYPOTHESIS,
		"replay_samples": 10,
		"manifest_path": "",
	}
	var index: int = 0
	while index < args.size():
		var token: String = args[index]
		if token == "--manifest-path":
			if index + 1 >= args.size() or args[index + 1].is_empty():
				return {"ok": false, "error": "missing_path_for_manifest"}
			result["manifest_path"] = args[index + 1]
			index += 2
			continue
		if token in ["--seeds", "--start-seed", "--round-limit", "--replay-samples"]:
			if index + 1 >= args.size() or not args[index + 1].is_valid_int():
				return {"ok": false, "error": "missing_integer_for_%s" % token}
			var value: int = int(args[index + 1])
			if value < 0 or (value == 0 and token != "--replay-samples"):
				return {"ok": false, "error": "non_positive_%s" % token}
			match token:
				"--seeds": result["seeds"] = value
				"--start-seed": result["start_seed"] = value
				"--round-limit": result["round_limit"] = value
				"--replay-samples": result["replay_samples"] = value
			index += 2
			continue
		return {"ok": false, "error": "unknown_argument:%s" % token}
	return result


static func _determinism_matches(first: Dictionary, second: Dictionary) -> bool:
	return first["winner"] == second["winner"] \
		and first["win_reason"] == second["win_reason"] \
		and first["state_digest"] == second["state_digest"] \
		and first["event_log_digest"] == second["event_log_digest"] \
		and first["action_count"] == second["action_count"]


static func _normalized_flag_region(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var region: Dictionary = value
	return {
		"x_min": int(region.get("x_min", -1)),
		"x_max": int(region.get("x_max", -1)),
		"y_min": int(region.get("y_min", -1)),
		"y_max": int(region.get("y_max", -1)),
	}


static func _flag_distribution_failure(region: Dictionary, positions: Array) -> String:
	if region != EXPECTED_FLAG_REGION:
		return "initial_flag_region_not_full_battlefield"
	if positions.size() != 3:
		return "initial_flag_count_not_three"
	var occupied_cells: Dictionary = {}
	for position_value: Variant in positions:
		var position := Canonical.coordinate(position_value)
		if position.x < int(region["x_min"]) or position.x > int(region["x_max"]) \
		or position.y < int(region["y_min"]) or position.y > int(region["y_max"]):
			return "initial_flag_position_outside_full_battlefield"
		var cell_key: String = Canonical.cell_key(position)
		if occupied_cells.has(cell_key):
			return "initial_flag_positions_not_unique"
		occupied_cells[cell_key] = true
	return ""


static func _write_manifest(path: String, records: Array, summary: Dictionary) -> String:
	var normalized_path: String = path
	if not path.is_absolute_path() and not path.begins_with("res://") \
	and not path.begins_with("user://"):
		normalized_path = "res://%s" % path
	var absolute_path: String = ProjectSettings.globalize_path(normalized_path)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return "manifest_directory_error:%d" % directory_error
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return "manifest_open_error:%d" % FileAccess.get_open_error()
	file.store_line(Canonical.json({
		"schema_version": MANIFEST_HEADER_SCHEMA_VERSION,
		"simulation_mode": "rules_stress_full_state_policy",
		"records_count": records.size(),
		"record_schema_version": COMPACT_RECORD_SCHEMA_VERSION,
	}))
	for record: Dictionary in records:
		file.store_line(Canonical.json(record))
	var manifest_summary: Dictionary = summary.duplicate(true)
	manifest_summary["batch_summary_schema_version"] = str(summary.get("schema_version", ""))
	manifest_summary["record_schema_version"] = COMPACT_RECORD_SCHEMA_VERSION
	manifest_summary["schema_version"] = MANIFEST_SUMMARY_SCHEMA_VERSION
	file.store_line(Canonical.json(manifest_summary))
	file.close()
	return ""


static func _records_digest(records: Array) -> String:
	var lines: Array = []
	for record: Dictionary in records:
		lines.append(Canonical.json(record))
	return Canonical.digest(lines)


static func _percentile(sorted_values: Array[int], fraction: float) -> int:
	if sorted_values.is_empty():
		return 0
	var index: int = clampi(ceili(float(sorted_values.size()) * fraction) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]
