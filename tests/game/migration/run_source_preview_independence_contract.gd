extends SceneTree

const ChannelCapture = preload("res://tests/game/migration/gate1_channel_capture.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var result: Dictionary = ChannelCapture.compare_live(471021, 50, "drop_first")
	if bool(result.get("ok", true)):
		push_error("SOURCE_PREVIEW_INDEPENDENCE_FAIL injected_difference_was_accepted")
		quit(1)
		return
	var failure: String = str(result.get("failure", ""))
	if not failure.contains("channel=observer_replay_frame"):
		push_error("SOURCE_PREVIEW_INDEPENDENCE_FAIL wrong_failure=%s" % failure)
		quit(1)
		return
	print("SOURCE_PREVIEW_INDEPENDENCE_PASS seed=471021 mutation=drop_first")
	quit(0)
