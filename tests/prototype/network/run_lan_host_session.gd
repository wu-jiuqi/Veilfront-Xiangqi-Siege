extends SceneTree

const LanHostSessionTests = preload("res://tests/prototype/network/test_lan_host_session.gd")


func _init() -> void:
	if LanHostSessionTests.run_suite():
		print("LAN_HOST_SESSION_TESTS_PASSED")
		quit(0)
		return
	print("LAN_HOST_SESSION_TESTS_FAILED")
	quit(1)
