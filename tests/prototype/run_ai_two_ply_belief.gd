extends SceneTree

const AiTwoPlyBeliefTests = preload("res://tests/prototype/test_ai_two_ply_belief.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok: bool = AiTwoPlyBeliefTests.run_suite()
	print("AI_TWO_PLY_BELIEF_PASSED" if ok else "AI_TWO_PLY_BELIEF_FAILED")
	quit(0 if ok else 1)
