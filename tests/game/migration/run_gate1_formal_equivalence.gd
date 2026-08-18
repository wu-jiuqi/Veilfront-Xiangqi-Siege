extends SceneTree

const Canonical = preload("res://scripts/game/domain/canonical.gd")
const AuthoritativeReplay = preload("res://scripts/game/domain/authoritative_replay.gd")
const ChannelCapture = preload("res://tests/game/migration/gate1_channel_capture.gd")

const GOLDEN_PATH: String = "res://tests/game/migration/golden/gate1-successor-20-seeds-v2.json"
const GOLDEN_SHA256: String = "67ed6d953a756eac88e8fa8063612409b7b7de1e009c8b80e92b0c0fccf97411"
const DEFAULT_START_SEED: int = 471001
const DEFAULT_SEED_COUNT: int = 20
const DEFAULT_ROUND_LIMIT: int = 50
const EXPECTED_CHANNELS: Array[String] = [
	"state", "event", "red_player_view", "black_player_view", "red_visible_event",
	"black_visible_event", "visible_error", "action_preview", "replay",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = _parse_options(OS.get_cmdline_user_args())
	var start_seed: int = int(options.get("start_seed", DEFAULT_START_SEED))
	var seed_count: int = int(options.get("seeds", DEFAULT_SEED_COUNT))
	var round_limit: int = int(options.get("round_limit", DEFAULT_ROUND_LIMIT))
	var replay_samples: int = int(options.get("replay_samples", mini(seed_count, 20)))
	var channels: Array = options.get("channels", EXPECTED_CHANNELS)
	if seed_count <= 0 or round_limit <= 0 or channels != EXPECTED_CHANNELS:
		push_error("FORMAL_EQUIVALENCE_FAIL invalid command contract")
		quit(2)
		return
	var golden_records: Dictionary = _load_golden_records(start_seed, seed_count, round_limit)
	if start_seed == DEFAULT_START_SEED and seed_count <= DEFAULT_SEED_COUNT \
	and golden_records.is_empty():
		quit(2)
		return
	var failures: Array[String] = []
	var replay_verified: int = 0
	var visible_error_checked: int = 0
	var authoritative_replay_checked: int = 0
	var observer_replay_frames_checked: int = 0
	var live_start_seed: int = -1
	var live_seed_count: int = 0
	for offset: int in seed_count:
		var seed_value: int = start_seed + offset
		var source: Dictionary = golden_records.get(seed_value, {})
		if source.is_empty():
			if live_start_seed < 0:
				live_start_seed = seed_value
			live_seed_count += 1
			continue
		var formal: Dictionary = ChannelCapture.capture_formal(
			seed_value, source.get("intents", []), round_limit
		)
		var mismatches: Array[String] = ChannelCapture.compare_records(source, formal)
		if not mismatches.is_empty():
			failures.append("seed=%d %s" % [seed_value, mismatches[0]])
			break
		if offset < replay_samples:
			var replay: Dictionary = AuthoritativeReplay.capture(
				seed_value,
				source.get("intents", []),
				{"full_round_limit_hypothesis": round_limit}
			)
			var verification: Dictionary = AuthoritativeReplay.verify(replay)
			if not bool(verification.get("ok", false)):
				failures.append("seed=%d replay=%s" % [seed_value, verification.get("error_code", "")])
				break
			replay_verified += 1
		visible_error_checked += int(source.get("action_count", 0)) + source.get("visible_error_corpus", []).size()
		authoritative_replay_checked += 1
		observer_replay_frames_checked += int(source.get("action_count", 0)) * 2
	if failures.is_empty() and live_seed_count > 0:
		var live_comparison: Dictionary = _run_live_ranges(
			live_start_seed, live_seed_count, round_limit
		)
		if not bool(live_comparison.get("ok", false)):
			failures.append(str(live_comparison.get("failure", "live_comparison_failed")))
		else:
			visible_error_checked += int(live_comparison.get("visible_error_checked", 0))
			authoritative_replay_checked += int(live_comparison.get("authoritative_replay_checked", 0))
			observer_replay_frames_checked += int(live_comparison.get("observer_replay_frames_checked", 0))
	if not failures.is_empty():
		for failure: String in failures:
			push_error("FORMAL_EQUIVALENCE_FAIL %s" % failure)
		quit(1)
		return
	print("FORMAL_EQUIVALENCE_PASS completed=%d replay_verified=%d channels=%d visible_error_checked=%d authoritative_replay_checked=%d observer_replay_frames_checked=%d" % [
		seed_count, replay_verified, EXPECTED_CHANNELS.size(), visible_error_checked,
		authoritative_replay_checked, observer_replay_frames_checked,
	])
	quit(0)


func _run_live_ranges(start_seed: int, seed_count: int, round_limit: int) -> Dictionary:
	var worker_count: int = mini(4, seed_count)
	if worker_count <= 1:
		return ChannelCapture.compare_live_range(start_seed, seed_count, round_limit)
	var threads: Array[Thread] = []
	var base_count: int = seed_count / worker_count
	var remainder: int = seed_count % worker_count
	var range_start: int = start_seed
	for worker_index: int in worker_count:
		var range_count: int = base_count + (1 if worker_index < remainder else 0)
		var thread: Thread = Thread.new()
		var start_error: Error = thread.start(Callable(
			ChannelCapture, "compare_live_range"
		).bind(range_start, range_count, round_limit))
		if start_error != OK:
			for started_thread: Thread in threads:
				started_thread.wait_to_finish()
			return {"ok": false, "failure": "worker_start_failed:%d" % start_error}
		threads.append(thread)
		range_start += range_count
	var completed: int = 0
	var visible_error_checked: int = 0
	var authoritative_replay_checked: int = 0
	var observer_replay_frames_checked: int = 0
	var first_failure: Dictionary = {}
	for thread: Thread in threads:
		var result: Dictionary = thread.wait_to_finish()
		if not bool(result.get("ok", false)) and first_failure.is_empty():
			first_failure = result
		if bool(result.get("ok", false)):
			completed += int(result.get("completed", 0))
			visible_error_checked += int(result.get("visible_error_checked", 0))
			authoritative_replay_checked += int(result.get("authoritative_replay_checked", 0))
			observer_replay_frames_checked += int(result.get("observer_replay_frames_checked", 0))
	if not first_failure.is_empty():
		return first_failure
	print("FORMAL_EQUIVALENCE_PROGRESS completed_live=%d/%d workers=%d" % [
		completed, seed_count, worker_count,
	])
	return {
		"ok": true,
		"completed": completed,
		"visible_error_checked": visible_error_checked,
		"authoritative_replay_checked": authoritative_replay_checked,
		"observer_replay_frames_checked": observer_replay_frames_checked,
		"failure": "",
	}


func _load_golden_records(start_seed: int, seed_count: int, round_limit: int) -> Dictionary:
	if start_seed != DEFAULT_START_SEED or round_limit != DEFAULT_ROUND_LIMIT:
		return {}
	if FileAccess.get_sha256(GOLDEN_PATH) != GOLDEN_SHA256:
		push_error("FORMAL_EQUIVALENCE_FAIL golden_digest_mismatch")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH))
	if not parsed is Dictionary:
		push_error("FORMAL_EQUIVALENCE_FAIL golden_parse")
		return {}
	var document: Dictionary = parsed
	if str(document.get("schema_version", "")) != "veilfront-gate1-migration-golden-v2":
		push_error("FORMAL_EQUIVALENCE_FAIL golden_schema")
		return {}
	var result: Dictionary = {}
	for record_value: Variant in document.get("records", []):
		var record: Dictionary = record_value
		result[int(record.get("seed", 0))] = record
	return result


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var options: Dictionary = {
		"start_seed": DEFAULT_START_SEED,
		"seeds": DEFAULT_SEED_COUNT,
		"round_limit": DEFAULT_ROUND_LIMIT,
		"replay_samples": DEFAULT_SEED_COUNT,
		"channels": EXPECTED_CHANNELS.duplicate(),
	}
	var index: int = 0
	while index < arguments.size():
		var argument: String = arguments[index]
		if argument in ["--start-seed", "--seeds", "--round-limit", "--replay-samples", "--channels"] \
		and index + 1 < arguments.size():
			var key: String = argument.trim_prefix("--").replace("-", "_")
			var raw_value: String = arguments[index + 1]
			options[key] = raw_value.split(",") as Array if argument == "--channels" else int(raw_value)
			index += 2
			continue
		index += 1
	return options
