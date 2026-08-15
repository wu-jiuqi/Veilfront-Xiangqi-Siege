extends SceneTree

const MoveRulesTests = preload("res://tests/prototype/test_move_rules.gd")


func _init() -> void:
	var started_msec: int = Time.get_ticks_msec()
	var ok: bool = MoveRulesTests.run_suite()
	var elapsed_msec: int = Time.get_ticks_msec() - started_msec
	if ok:
		print("MOVE_RULES_SUITE_PASSED elapsed_msec=%d" % elapsed_msec)
		quit(0)
		return
	push_error("MOVE_RULES_SUITE_FAILED elapsed_msec=%d" % elapsed_msec)
	quit(1)
