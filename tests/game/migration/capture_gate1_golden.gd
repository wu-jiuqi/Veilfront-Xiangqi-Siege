extends SceneTree

const Canonical = preload("res://scripts/game/domain/canonical.gd")
const ChannelCapture = preload("res://tests/game/migration/gate1_channel_capture.gd")

const OUTPUT_PATH: String = "res://tests/game/migration/golden/gate1-successor-20-seeds-v3.json"
const SEED_START: int = 471001
const SEED_COUNT: int = 20


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var records: Array = []
	for seed_value: int in range(SEED_START, SEED_START + SEED_COUNT):
		var record: Dictionary = ChannelCapture.capture_source(seed_value)
		if not str(record.get("failure", "")).is_empty():
			push_error("GOLDEN_CAPTURE_FAILED seed=%d failure=%s" % [seed_value, record["failure"]])
			quit(1)
			return
		records.append(record)
	var document: Dictionary = {
		"schema_version": "veilfront-gate1-migration-golden-v3",
		"source_commit": "6253678157157091584b253470e709bad17c534f",
		"successor_digest": "f6b07d8cbdc7db4492c33e8b4b028aca2906cccc8baf5921273aaa012d48e19b",
		"seed_start": SEED_START,
		"seed_count": SEED_COUNT,
		"records": records,
	}
	var absolute_path: String = ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GOLDEN_CAPTURE_FAILED open=%s" % FileAccess.get_open_error())
		quit(1)
		return
	file.store_string(Canonical.json(document) + "\n")
	file.close()
	print("GOLDEN_CAPTURE_PASS seeds=%d digest=%s path=%s" % [
		SEED_COUNT, Canonical.digest(document), OUTPUT_PATH,
	])
	quit(0)
