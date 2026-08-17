extends SceneTree

const Tests = preload("res://tests/prototype/test_owner_rule_revision_v4.gd")


func _init() -> void:
	if Tests.run_suite():
		print("OWNER_RULE_REVISION_V4_PASSED")
		quit(0)
		return
	quit(1)
