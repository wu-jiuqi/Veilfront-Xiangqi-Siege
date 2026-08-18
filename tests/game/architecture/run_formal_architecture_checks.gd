extends SceneTree

const BoundaryScanner = preload("res://tests/game/architecture/check_dependency_boundaries.gd")
const BoundaryTests = preload("res://tests/game/architecture/test_dependency_boundaries.gd")


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var test_result: Dictionary = BoundaryTests.new().run_suite()
	if not bool(test_result.get("ok", false)):
		for failure: String in test_result.get("failures", []):
			push_error("FAIL: %s" % failure)
		print("FORMAL_ARCHITECTURE_SELF_TESTS_FAILED count=%d" % test_result.get("failures", []).size())
		quit(1)
		return

	var scan_result: Dictionary = BoundaryScanner.new().scan_project()
	var violations: Array = scan_result.get("violations", [])
	for violation: Dictionary in violations:
		push_error(
			"FAIL: [%s] %s:%d %s" % [
				violation.get("rule_id", "UNKNOWN"),
				violation.get("path", ""),
				violation.get("line", 0),
				violation.get("detail", ""),
			]
		)
	if not violations.is_empty():
		print(
			"FORMAL_ARCHITECTURE_CHECKS_FAILED violations=%d scanned_files=%d" % [
				violations.size(),
				scan_result.get("scanned_files", 0),
			]
		)
		quit(1)
		return

	print(
		"FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=%d scanned_files=%d" % [
			test_result.get("checks", 0),
			scan_result.get("scanned_files", 0),
		]
	)
	quit(0)
