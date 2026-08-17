extends RefCounted

const Canonical = preload("res://scripts/prototype/core/canonical.gd")
const MatchState = preload("res://scripts/prototype/core/match_state.gd")
const RuleEngine = preload("res://scripts/prototype/core/rule_engine.gd")
const MoveRules = preload("res://scripts/prototype/core/move_rules.gd")
const ReplayRunner = preload("res://scripts/prototype/replay/replay_runner.gd")
const SeededRandom = preload("res://scripts/prototype/core/seeded_random.gd")
const PlayerViewProjector = preload("res://scripts/prototype/view/player_view_projector.gd")


static func run_match(seed_value: int, options: Dictionary = {}) -> Dictionary:
	var round_limit: int = int(options.get(
		"full_round_limit_hypothesis",
		MatchState.DEFAULT_FULL_ROUND_LIMIT_HYPOTHESIS
	))
	if round_limit <= 0:
		return _failed(seed_value, "round_limit_must_be_positive")
	var configuration: Dictionary = {"full_round_limit_hypothesis": round_limit}
	var state: Dictionary = RuleEngine.create_match(seed_value, configuration)
	var initial_flag_positions: Array = []
	for flag: Dictionary in state["flags"]:
		initial_flag_positions.append(flag["position"].duplicate())
	var policy_rng: Dictionary = SeededRandom.create_state(_policy_seed(seed_value))
	var intents: Array = []
	var metrics: Dictionary = {
		"bombardments": 0,
		"rook_multi_targets": 0,
		"rescues": 0,
		"wall_breaches": 0,
		"wall_repairs": 0,
		"flag_captures": 0,
		"candidate_evaluations": 0,
	}
	var failures: Array[String] = []
	var profile_usec: Dictionary = {
		"begin_action": 0,
		"legal_generation": 0,
		"policy": 0,
		"submit": 0,
		"post_checks": 0,
		"replay": 0,
	}
	while not state["terminal"]:
		var phase_started: int = Time.get_ticks_usec()
		var prepared_result: Dictionary = RuleEngine.prepare_action(state)
		if not prepared_result.get("ok", false):
			failures.append("action_preparation_failed")
			break
		var preparation: Dictionary = prepared_result["preparation"]
		profile_usec["begin_action"] = int(profile_usec["begin_action"]) + Time.get_ticks_usec() - phase_started
		phase_started = Time.get_ticks_usec()
		var selection: Dictionary = MoveRules.choose_legal_action_fast(
			state,
			state["active_side"],
			PlayerViewProjector.visibility_context(state, state["active_side"]),
			policy_rng
		)
		var intent: Dictionary = selection["intent"]
		metrics["candidate_evaluations"] = int(metrics["candidate_evaluations"]) \
			+ int(selection["candidate_evaluations"])
		profile_usec["legal_generation"] = int(profile_usec["legal_generation"]) + Time.get_ticks_usec() - phase_started
		var before_walls: Dictionary = state["walls"].duplicate(true)
		var before_flags: Array = state["flags"].duplicate(true)
		phase_started = Time.get_ticks_usec()
		var result: Dictionary = RuleEngine.submit_action(state, intent, {
			"trusted_generated_action": true,
			"include_state_summary": false,
			"preparation_token": preparation["token"],
		})
		profile_usec["submit"] = int(profile_usec["submit"]) + Time.get_ticks_usec() - phase_started
		if not result.get("ok", false) or not result.get("consumed", false):
			failures.append("generated_action_rejected:%s" % Canonical.json(intent))
			break
		intents.append(intent.duplicate(true))
		phase_started = Time.get_ticks_usec()
		_collect_action_metrics(result["event"], before_walls, before_flags, state, metrics)
		var invariant_failure: String = _state_invariant_failure(state)
		if not invariant_failure.is_empty():
			failures.append(invariant_failure)
			break
		if int(state["action_index"]) > round_limit * 2:
			failures.append("action_count_exceeded_round_limit")
			break
		profile_usec["post_checks"] = int(profile_usec["post_checks"]) + Time.get_ticks_usec() - phase_started
	if not state["terminal"] and failures.is_empty():
		failures.append("match_not_terminal")
	if state["terminal"]:
		var terminal_failure: String = _terminal_invariant_failure(state, round_limit)
		if not terminal_failure.is_empty():
			failures.append(terminal_failure)
		var terminal_summary_before: Dictionary = MatchState.summary(state)
		var terminal_rejection: Dictionary = RuleEngine.submit_action(state, {
			"piece_id": "", "action_type": "pass", "target_cell": [], "skill_type": "",
		})
		if terminal_rejection.get("ok", true) or terminal_rejection.get("consumed", true) \
		or terminal_rejection.get("error", {}).get("category", "") != "terminal" \
		or MatchState.summary(state) != terminal_summary_before:
			failures.append("terminal_action_not_rejected_without_mutation")
	var summary: Dictionary = MatchState.summary(state)
	var verify_replay: bool = bool(options.get("verify_replay", true))
	var replay_ok: bool = false
	if failures.is_empty() and verify_replay:
		var replay_started: int = Time.get_ticks_usec()
		var recording: Dictionary = ReplayRunner.capture(seed_value, intents, configuration)
		replay_ok = recording["final_state_summary"] == summary \
			and Canonical.digest(recording["action_events"]) == Canonical.digest(state["events"])
		if not replay_ok:
			failures.append("replay_divergence")
		profile_usec["replay"] = Time.get_ticks_usec() - replay_started
	var flag_counts: Dictionary = {MatchState.RED: 0, MatchState.BLACK: 0, MatchState.NEUTRAL: 0}
	for flag: Dictionary in state["flags"]:
		flag_counts[flag["owner"]] = int(flag_counts.get(flag["owner"], 0)) + 1
	var result: Dictionary = {
		"ok": failures.is_empty(),
		"schema_version": "seeded-match-result-v1",
		"simulation_mode": "rules_stress_full_state_policy",
		"seed": seed_value,
		"round_limit_status": "hypothesis_cli_overridable",
		"full_round_limit_hypothesis": round_limit,
		"terminal": state["terminal"],
		"winner": state["winner"],
		"win_reason": state["win_reason"],
		"action_count": state["action_index"],
		"full_round_count": state["full_round_index"],
		"flag_counts": flag_counts,
		"initial_flag_positions": initial_flag_positions,
		"initial_flag_region": {"x_min": 1, "x_max": 9, "y_min": 9, "y_max": 16},
		"metrics": metrics,
		"replay_verified": replay_ok,
		"replay_verification_requested": verify_replay,
		"state_digest": summary["state_digest"],
		"event_log_digest": summary["event_log_digest"],
		"failures": failures,
		"profile_msec": {},
	}
	for phase: String in profile_usec.keys():
		result["profile_msec"][phase] = snappedf(float(profile_usec[phase]) / 1000.0, 0.001)
	if bool(options.get("include_replay", false)):
		result["intents"] = intents
		result["action_events"] = state["events"].duplicate(true)
	return result


static func _collect_action_metrics(
	event: Dictionary,
	before_walls: Dictionary,
	before_flags: Array,
	state: Dictionary,
	metrics: Dictionary
) -> void:
	var outcome: Dictionary = event["outcome"]
	if outcome["result_code"] == "bombardment_resolved":
		metrics["bombardments"] = int(metrics["bombardments"]) + 1
		metrics["rescues"] = int(metrics["rescues"]) \
			+ outcome["bombardment_result"]["rescue_records"].size()
	if outcome.get("move_kind", "") == "rook_special" and outcome.get("casualties", []).size() > 1:
		metrics["rook_multi_targets"] = int(metrics["rook_multi_targets"]) + 1
	for casualty: Dictionary in outcome.get("casualties", []):
		if casualty.get("rescued", false):
			metrics["rescues"] = int(metrics["rescues"]) + 1
	for side: String in [MatchState.RED, MatchState.BLACK]:
		var before_status: String = str(before_walls[side]["status"])
		var after_status: String = str(state["walls"][side]["status"])
		if before_status == "INTACT" and after_status == "BREACHED":
			metrics["wall_breaches"] = int(metrics["wall_breaches"]) + 1
		if before_status != "INTACT" and after_status == "INTACT":
			metrics["wall_repairs"] = int(metrics["wall_repairs"]) + 1
	for index: int in state["flags"].size():
		if before_flags[index]["owner"] != state["flags"][index]["owner"]:
			metrics["flag_captures"] = int(metrics["flag_captures"]) + 1


static func _state_invariant_failure(state: Dictionary) -> String:
	var occupied: Dictionary = {}
	for piece_value: Variant in state["pieces"].values():
		var piece: Dictionary = piece_value
		var position := Canonical.coordinate(piece.get("position", []))
		if piece["alive"] and not piece["in_reserve"]:
			if not MatchState.is_inside_board(position):
				return "live_board_piece_has_no_position:%s" % piece["id"]
			var key: String = Canonical.cell_key(position)
			if occupied.has(key):
				return "duplicate_board_occupancy:%s" % key
			occupied[key] = piece["id"]
			if state["board"].get(key, "") != piece["id"]:
				return "board_index_mismatch:%s" % piece["id"]
		elif MatchState.is_inside_board(position):
			return "offboard_lifecycle_piece_indexed:%s" % piece["id"]
	if occupied.size() != state["board"].size():
		return "board_index_size_mismatch"
	return ""


static func _terminal_invariant_failure(state: Dictionary, round_limit: int) -> String:
	var reason: String = str(state["win_reason"])
	var winner: String = str(state["winner"])
	var red_general_alive: bool = bool(state["pieces"]["red-general-1"]["alive"])
	var black_general_alive: bool = bool(state["pieces"]["black-general-1"]["alive"])
	var uncontested_owned: Dictionary = {MatchState.RED: 0, MatchState.BLACK: 0}
	var owned_including_contested: Dictionary = {MatchState.RED: 0, MatchState.BLACK: 0}
	for flag: Dictionary in state["flags"]:
		if owned_including_contested.has(flag["owner"]):
			owned_including_contested[flag["owner"]] = int(owned_including_contested[flag["owner"]]) + 1
			if not flag["contested"]:
				uncontested_owned[flag["owner"]] = int(uncontested_owned[flag["owner"]]) + 1
	match reason:
		"general_destroyed":
			if winner == MatchState.RED and not black_general_alive and red_general_alive:
				return ""
			if winner == MatchState.BLACK and not red_general_alive and black_general_alive:
				return ""
			return "terminal_general_destroyed_semantics"
		"simultaneous_generals_destroyed":
			return "" if winner == "draw" and not red_general_alive and not black_general_alive \
				else "terminal_simultaneous_generals_semantics"
		"three_flags":
			return "" if winner in [MatchState.RED, MatchState.BLACK] and int(uncontested_owned[winner]) == 3 \
				else "terminal_three_flags_semantics"
		"round_limit_flags":
			if int(state["full_round_index"]) != round_limit or winner not in [MatchState.RED, MatchState.BLACK]:
				return "terminal_round_limit_boundary"
			return "" if int(owned_including_contested[winner]) \
				> int(owned_including_contested[MatchState.opponent(winner)]) \
				else "terminal_round_limit_flag_winner"
		"round_limit_draw":
			return "" if winner == "draw" and int(state["full_round_index"]) == round_limit \
				and int(owned_including_contested[MatchState.RED]) \
				== int(owned_including_contested[MatchState.BLACK]) \
				else "terminal_round_limit_draw_semantics"
	return "terminal_unknown_reason:%s" % reason


static func _policy_seed(seed_value: int) -> int:
	return int((seed_value * 1103515245 + 12345) & 0x7fffffff)


static func _failed(seed_value: int, code: String) -> Dictionary:
	return {
		"ok": false,
		"schema_version": "seeded-match-result-v1",
		"seed": seed_value,
		"failures": [code],
	}
