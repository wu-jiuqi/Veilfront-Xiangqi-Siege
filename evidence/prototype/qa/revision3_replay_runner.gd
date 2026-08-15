extends SceneTree

const ReplayTests = preload("res://tests/prototype/test_replay.gd")


func _init() -> void:
	var passed: bool = ReplayTests.run_suite()
	if passed:
		print("REVISION3_REPLAY_TAMPER_SUITE_PASSED")
		quit(0)
		return
	push_error("REVISION3_REPLAY_TAMPER_SUITE_FAILED")
	quit(1)
