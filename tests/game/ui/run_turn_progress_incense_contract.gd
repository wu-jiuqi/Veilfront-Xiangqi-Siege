extends SceneTree

const IncenseScript = preload("res://scripts/game/presentation/ui/turn_progress_incense.gd")
const INCENSE_SCENE_PATH := "res://scenes/game/ui/turn_progress_incense.tscn"
const LAB_SCENE_PATH := "res://scenes/dev/ui/turn_progress_incense_lab.tscn"
const MATCH_HEADER_SCENE_PATH := "res://scenes/game/ui/match_header.tscn"
const SMOKE_SHEET_PATH := "res://assets/art/ui/terracotta_hud_v2/turn_progress_incense/turn_progress_smoke_sequence_8f_v1.png"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_chinese_numbers()
	_check_turn_progress_curve()
	var packed := load(INCENSE_SCENE_PATH) as PackedScene
	_expect(packed != null, "燃香回合组件无法加载")
	if packed == null:
		_finish()
		return

	var incense := packed.instantiate() as TurnProgressIncense
	_expect(incense != null, "燃香回合组件根节点类型错误")
	if incense == null:
		_finish()
		return
	root.add_child(incense)
	await process_frame
	await process_frame

	var smoke_frame := incense.get_node("%SmokeFrame") as Sprite2D
	var smoke_player := incense.get_node("%SmokeAnimationPlayer") as AnimationPlayer
	_expect(smoke_frame != null and smoke_frame.texture != null, "烟雾序列帧贴图未接入")
	_expect(smoke_frame.texture.resource_path == SMOKE_SHEET_PATH, "烟雾序列帧路径错误")
	_expect(smoke_frame.hframes * smoke_frame.vframes == 8, "烟雾必须包含 8 个序列帧")
	_expect(smoke_player != null and smoke_player.is_playing(), "烟雾循环动画未自动播放")
	_expect(smoke_player.current_animation == &"smoke_loop", "烟雾循环动画名称错误")

	incense.set_reduced_motion(true)
	_expect(not smoke_player.is_playing(), "减少动态模式没有暂停烟雾序列帧")
	var number_player := incense.get_node("%NumberFloatAnimationPlayer") as AnimationPlayer
	_expect(number_player != null and not number_player.is_playing(), "减少动态模式没有暂停烟字漂浮")
	incense.set_turn(1, 50, false)
	var first := incense.get_state_snapshot()
	_expect(is_equal_approx(float(first["remaining_ratio"]), 0.98), "第一回合香体剩余比例应为 49/50")
	_expect(first["chinese_turn"] == "一", "第一回合未显示中文数字")

	incense.set_turn(25, 50, false)
	var middle := incense.get_state_snapshot()
	_expect(is_equal_approx(float(middle["remaining_ratio"]), 0.5), "第二十五回合香体应剩余一半")
	_expect(middle["chinese_turn"] == "二十五", "第二十五回合中文数字错误")
	_expect(float(middle["body_width"]) < float(first["body_width"]), "回合推进后香体没有缩短")
	_expect(float(middle["smoke_length"]) > float(first["smoke_length"]), "香体缩短后烟带没有变长")

	incense.set_turn(49, 50, false)
	var penultimate := incense.get_state_snapshot()
	_expect(is_equal_approx(float(penultimate["remaining_ratio"]), 0.02), "第四十九回合应只剩 1/50 香体")
	_expect(penultimate["chinese_turn"] == "四十九", "第四十九回合中文数字错误")

	incense.set_turn(50, 50, false)
	var final := incense.get_state_snapshot()
	_expect(is_zero_approx(float(final["remaining_ratio"])), "第五十回合香体未烧完")
	_expect(is_zero_approx(float(final["body_width"])), "第五十回合香体宽度未归零")
	_expect(final["chinese_turn"] == "五十", "第五十回合中文数字错误")
	_expect(float(final["smoke_length"]) > float(penultimate["smoke_length"]), "第五十回合烟带未继续延长")
	_expect(is_zero_approx(float(final["ember_alpha"])), "香烧完后燃点未熄灭")

	var number_label := incense.get_node("%SmokeNumber") as Label
	var smoke_material := number_label.material as ShaderMaterial
	_expect(smoke_material != null, "中文烟字缺少散聚 Shader")
	_expect(smoke_material.shader != null, "中文烟字 Shader 资源为空")
	_expect(float(smoke_material.get_shader_parameter(&"scatter")) == 0.0, "静止状态烟字不应处于散开状态")
	await _check_digit_transition(incense)

	_check_preset_consumers()
	incense.queue_free()
	await process_frame
	_finish()


func _check_chinese_numbers() -> void:
	var expected := {
		1: "一", 9: "九", 10: "十", 11: "十一", 20: "二十",
		21: "二十一", 25: "二十五", 49: "四十九", 50: "五十",
	}
	for turn_number: int in expected:
		_expect(
			IncenseScript.chinese_number(turn_number) == expected[turn_number],
			"中文数字转换错误：%d" % turn_number
		)
	_expect(is_equal_approx(IncenseScript.remaining_ratio_for_turn(0, 50), 1.0), "第零回合前香体应为完整长度")
	_expect(is_zero_approx(IncenseScript.remaining_ratio_for_turn(50, 50)), "第五十回合香体应归零")


func _check_turn_progress_curve() -> void:
	var previous_ratio := 1.0
	for turn_number: int in range(1, 51):
		var ratio: float = IncenseScript.remaining_ratio_for_turn(turn_number, 50)
		var expected_ratio := 1.0 - float(turn_number) / 50.0
		_expect(is_equal_approx(ratio, expected_ratio), "第%d回合香体比例错误" % turn_number)
		_expect(ratio < previous_ratio, "第%d回合香体没有比上一回合更短" % turn_number)
		previous_ratio = ratio


func _check_digit_transition(incense: TurnProgressIncense) -> void:
	incense.set_reduced_motion(false)
	incense.set_turn(11, 50, false)
	incense.set_turn(12, 50, true)
	await create_timer(0.2).timeout
	var scatter_out := float(incense.get_state_snapshot().get("scatter", 0.0))
	_expect(scatter_out > 0.05, "回合数字改变时没有先散开：%.3f" % scatter_out)
	await create_timer(0.1).timeout
	var gathering := incense.get_state_snapshot()
	_expect(int(gathering.get("displayed_turn", 0)) == 12, "烟字散开后没有切换为新回合")
	_expect(float(gathering.get("scatter", 0.0)) > 0.05, "新回合烟字没有执行聚拢阶段")
	await create_timer(0.4).timeout
	_expect(float(incense.get_state_snapshot().get("scatter", 1.0)) < 0.02, "新回合烟字聚拢后未恢复完整")


func _check_preset_consumers() -> void:
	var header_scene := load(MATCH_HEADER_SCENE_PATH) as PackedScene
	_expect(header_scene != null, "正式 MatchHeader 无法加载")
	if header_scene != null:
		var header := header_scene.instantiate()
		_expect(
			header.get_node_or_null("%TurnProgressIncense") is TurnProgressIncense,
			"正式 MatchHeader 未预置燃香组件"
		)
		var legacy_label := header.get_node_or_null("Content/RoundLabel") as Label
		_expect(legacy_label != null and not legacy_label.visible, "阿拉伯数字旧回合 Label 仍在显示")
		header.free()

	var lab_scene := load(LAB_SCENE_PATH) as PackedScene
	_expect(lab_scene != null, "燃香动画测试场景无法加载")
	if lab_scene != null:
		var lab := lab_scene.instantiate()
		_expect(
			lab.get_node_or_null("%TurnProgressIncense") is TurnProgressIncense,
			"测试场景未预置燃香组件"
		)
		_expect(lab.get_node_or_null("%TurnSlider") is HSlider, "测试场景缺少 1—50 回合滑杆")
		_expect(lab.get_node_or_null("%AutoButton") is Button, "测试场景缺少自动播放按钮")
		lab.free()


func _finish() -> void:
	if _failures.is_empty():
		print("TURN_PROGRESS_INCENSE_CONTRACT_PASS turns=50 smoke_frames=8 chinese_numbers=9")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TURN_PROGRESS_INCENSE_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
