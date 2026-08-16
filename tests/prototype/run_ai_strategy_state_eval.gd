extends SceneTree

const AiDifficultyProfileTests = preload("res://tests/prototype/test_ai_difficulty_profiles.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok: bool = AiDifficultyProfileTests.run_suite()
	print("AI_STRATEGY_STATE_EVAL_PASSED" if ok else "AI_STRATEGY_STATE_EVAL_FAILED")
	quit(0 if ok else 1)
