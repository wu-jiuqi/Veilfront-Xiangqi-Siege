extends SceneTree

const Tests = preload("res://tests/prototype/test_owner_rule_revision_v5.gd")


func _init() -> void:
	if Tests.run_suite():
		print("OWNER_RULE_REVISION_V5_PASSED")
		quit(0)
		return
	quit(1)
