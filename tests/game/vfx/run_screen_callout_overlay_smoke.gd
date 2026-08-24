extends SceneTree

const OVERLAY_SCENE: PackedScene = preload(
	"res://scenes/game/vfx/screen_callout_overlay.tscn"
)
const CueContract = preload("res://scripts/game/vfx/vfx_cue.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var overlay := OVERLAY_SCENE.instantiate() as ScreenCalloutOverlay
	viewport.add_child(overlay)
	await process_frame

	overlay.set_review_hold(true)
	var capture_batch := _callout_batch("capture", "standard", 1)
	_expect(overlay.play_batch(capture_batch) == 1, "吃字全屏提示必须播放一次", failures)
	var capture := overlay.effect_snapshot()
	_expect(bool(capture.get("active", false)), "吃字提示必须处于活动状态", failures)
	_expect(capture.get("callout_text", "") == "吃", "吃字提示文本错误", failures)
	_expect(capture.get("caption_text", "") == "斩获敌军", "吃字副标题错误", failures)
	_expect(capture.get("spatial_mode", "") == "global", "吃字必须使用global空间", failures)
	_expect(capture.get("screen_center", Vector2.ZERO) == Vector2(640.0, 360.0), "吃字必须位于屏幕正中央", failures)
	_expect(int(capture.get("label_font_size", 0)) >= 220, "吃字字号必须足够醒目", failures)
	_expect(int(capture.get("outline_size", 0)) >= 20, "吃字必须使用强描边", failures)
	_expect(float(capture.get("backdrop_opacity", 0.0)) >= 0.4, "吃字必须配有明显全屏压暗", failures)
	_expect(float(capture.get("band_height", 0.0)) >= 240.0, "吃字中央军令带高度不足", failures)
	for resolution: Vector2i in [
		Vector2i(960, 540), Vector2i(1024, 768),
		Vector2i(1920, 1080), Vector2i(2560, 1080),
	]:
		viewport.size = resolution
		await process_frame
		var responsive := overlay.effect_snapshot()
		_expect(
			responsive.get("screen_center", Vector2.ZERO) == Vector2(resolution) * 0.5,
			"吃字在%s下没有保持屏幕正中央" % resolution,
			failures
		)
		_expect(
			is_equal_approx(float(responsive.get("band_width", 0.0)), float(resolution.x)),
			"吃字军令带在%s下没有覆盖完整屏宽" % resolution,
			failures
		)
	viewport.size = Vector2i(1280, 720)
	await process_frame
	_expect(overlay.play_batch(capture_batch) == 0, "相同吃字cue必须去重", failures)

	var general_batch := _callout_batch("general", "standard", 2)
	_expect(overlay.play_batch(general_batch) == 1, "将字全屏提示必须播放一次", failures)
	var general := overlay.effect_snapshot()
	_expect(general.get("callout_text", "") == "将", "将字提示文本错误", failures)
	_expect(general.get("caption_text", "") == "主将告破", "将字副标题错误", failures)
	_expect(general.get("screen_center", Vector2.ZERO) == Vector2(640.0, 360.0), "将字必须位于屏幕正中央", failures)

	overlay.clear_all()
	overlay.set_review_hold(false)
	var reduced_batch := _callout_batch("capture", "reduced", 3)
	_expect(overlay.play_batch(reduced_batch) == 1, "reduced-motion吃字必须保留", failures)
	var reduced := overlay.effect_snapshot()
	_expect(reduced.get("motion_profile", "") == "reduced", "reduced-motion配置未传递", failures)
	_expect(not bool(reduced.get("particles_emitting", true)), "reduced-motion必须关闭爆发粒子", failures)

	if failures.is_empty():
		print(
			"SCREEN_CALLOUT_OVERLAY_PASS center=640,360 font=232 outline=22 "
			+ "backdrop=true band=true responsive=5 dedup=true reduced_motion=true"
		)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _callout_batch(kind: String, motion_profile: String, cursor: int) -> Dictionary:
	var cue := CueContract.build(
		"screen-callout-smoke",
		cursor,
		"vfx.callout.%s" % kind,
		"view_diff",
		cursor,
		0,
		"global",
		[],
		"critical" if kind == "general" else "high",
		"callout",
		"replace_group",
		"red",
		motion_profile,
		"screen-callout-%s-%d" % [kind, cursor]
	)
	return CueContract.build_batch(
		"screen-callout-smoke", cursor, cursor, motion_profile, [cue]
	)


func _expect(condition: bool, message: String, failures: PackedStringArray) -> void:
	if not condition:
		failures.append(message)
