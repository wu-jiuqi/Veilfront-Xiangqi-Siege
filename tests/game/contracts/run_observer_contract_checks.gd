extends SceneTree

const ObserverContractTests = preload("res://tests/game/contracts/test_observer_codec_allow_lists.gd")


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var result: Dictionary = ObserverContractTests.new().run_suite()
	if not bool(result.get("ok", false)):
		for failure: String in result.get("failures", []):
			push_error("FAIL: %s" % failure)
		print("OBSERVER_CONTRACT_CHECKS_FAILED checks=%d failures=%d" % [
			result.get("checks", 0),
			result.get("failures", []).size(),
		])
		quit(1)
		return
	print("OBSERVER_CONTRACT_CHECKS_PASSED checks=%d" % result.get("checks", 0))
	quit(0)
