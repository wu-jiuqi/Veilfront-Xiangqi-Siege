extends SceneTree

const AiPieceDiversityTests = preload("res://tests/prototype/test_ai_piece_diversity.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok: bool = AiPieceDiversityTests.run_suite()
	print("AI_PIECE_DIVERSITY_PASSED" if ok else "AI_PIECE_DIVERSITY_FAILED")
	quit(0 if ok else 1)
