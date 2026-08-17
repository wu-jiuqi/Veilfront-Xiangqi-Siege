extends SceneTree

const Canonical = preload("res://scripts/prototype/core/canonical.gd")


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() not in [2, 3] or args[0] != "--path" \
	or (args.size() == 3 and args[2] != "--force-record-tamper"):
		_fail("usage: --path <manifest-path> [--force-record-tamper]")
		return
	var path: String = args[1]
	if not path.is_absolute_path() and not path.begins_with("res://") \
	and not path.begins_with("user://"):
		path = "res://%s" % path
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("manifest_open_error:%d" % FileAccess.get_open_error())
		return
	var documents: Array = []
	var document_lines: PackedStringArray = []
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if not parsed is Dictionary:
			_fail("manifest_invalid_jsonl")
			return
		documents.append(parsed)
		document_lines.append(line)
	file.close()
	if documents.size() < 2:
		_fail("manifest_missing_header_or_summary")
		return
	var header: Dictionary = documents.front()
	var summary: Dictionary = documents.back()
	var records: Array = documents.slice(1, documents.size() - 1)
	var record_lines: Array = Array(document_lines.slice(1, document_lines.size() - 1))
	if args.size() == 3 and not record_lines.is_empty():
		record_lines[0] = "%s " % record_lines[0]
	var records_digest: String = Canonical.digest(record_lines)
	var ok: bool = _schema_is_traceable(header, records, summary) \
		and int(header.get("records_count", -1)) == records.size() \
		and int(summary.get("records_count", -1)) == records.size() \
		and str(summary.get("records_digest", "")) == records_digest
	if not ok:
		_fail("manifest_count_or_digest_mismatch")
		return
	print("SEEDED_MANIFEST_VERIFIED records=%d digest=%s" % [
		records.size(), records_digest,
	])
	quit(0)


static func _schema_is_traceable(header: Dictionary, records: Array, summary: Dictionary) -> bool:
	var header_schema: String = str(header.get("schema_version", ""))
	var summary_schema: String = str(summary.get("schema_version", ""))
	if header_schema == "seeded-match-manifest-header-v1" \
	and summary_schema == "seeded-match-manifest-summary-v1":
		return true
	if header_schema != "seeded-match-manifest-header-v2" \
	or summary_schema != "seeded-match-manifest-summary-v2":
		return false
	var record_schema: String = str(header.get("record_schema_version", ""))
	if record_schema != "seeded-match-compact-record-v2" \
	or str(summary.get("record_schema_version", "")) != record_schema \
	or str(summary.get("batch_summary_schema_version", "")) != "seeded-match-batch-summary-v2":
		return false
	for record: Dictionary in records:
		if str(record.get("schema_version", "")) != record_schema:
			return false
	return true


func _fail(code: String) -> void:
	push_error("SEEDED_MANIFEST_VERIFY_FAILED: %s" % code)
	quit(1)
