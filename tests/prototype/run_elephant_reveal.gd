extends SceneTree

const ElephantRevealTests = preload("res://tests/prototype/test_elephant_reveal.gd")


func _initialize() -> void:
	var ok: bool = ElephantRevealTests.run_suite()
	if ok:
		print("ELEPHANT_REVEAL_PASS")
		quit(0)
		return
	push_error("ELEPHANT_REVEAL_SUITE_FAILED")
	quit(1)
