extends SceneTree

const CLOCK_SCENE: PackedScene = preload("res://scenes/game/ui/incense_turn_clock.tscn")
const DRAWER_SCENE: PackedScene = preload("res://scenes/game/ui/piece_info_drawer.tscn")
const ClockScript = preload("res://scripts/game/presentation/ui/incense_turn_clock.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_chinese_numbers()
	var clock := CLOCK_SCENE.instantiate() as IncenseTurnClock
	_expect(clock != null, "燃香组合预置场景无法实例化")
	if clock == null:
		_finish()
		return
	root.add_child(clock)
	await process_frame
	clock.refresh_layout()
	var stand_texture := clock.get_node("%IncenseStandBaseArt").texture as AtlasTexture
	_expect(
		stand_texture != null
		and stand_texture.atlas.resource_path == "res://assets/art/ui/terracotta_hud_v2/incense_assembly/dual_incense_bronze_stand_v1.png",
		"香盘没有使用龙虎青铜摆件正式资源"
	)
	_expect(
		clock.get_node("%TimerBody").texture.resource_path == "res://assets/art/ui/terracotta_hud_v2/incense_assembly/timer_incense_vertical_v1.png",
		"计时香没有使用竖版正式资源"
	)
	_expect(
		clock.get_node("%RoundBody").texture.resource_path == "res://assets/art/ui/terracotta_hud_v2/incense_assembly/round_incense_vertical_v1.png",
		"回合香没有使用竖版正式资源"
	)
	var initial_state := clock.get_state_snapshot()
	_expect(
		bool(initial_state.get("timer_behind_stand", false)),
		"左侧计时香没有被香盘前景遮挡"
	)
	var timer_smoke_player: AnimationPlayer = clock.get_node("%TimerSmokeAnimationPlayer") as AnimationPlayer
	var timer_smoke_loop: Animation = timer_smoke_player.get_animation(&"smoke_loop")
	_expect(timer_smoke_loop != null and timer_smoke_loop.get_track_count() == 2, "左侧计时香烟雾缺少独立序列动画")
	if timer_smoke_loop != null and timer_smoke_loop.get_track_count() >= 2:
		_expect(
			str(timer_smoke_loop.track_get_path(1)) == "TimerSmokeVisual/TimerSmokeFrame:position",
			"左侧计时香烟雾补偿轨道没有绑定到 TimerSmokeFrame 位置"
		)
	var timer_smoke_visual := clock.get_node("%TimerSmokeVisual") as Node2D
	_expect(timer_smoke_visual.scale.y < 0.0, "左侧计时香烟雾没有与右侧烟雾形成镜像")
	var smoke_player: AnimationPlayer = clock.get_node("%SmokeAnimationPlayer") as AnimationPlayer
	var smoke_loop: Animation = smoke_player.get_animation(&"smoke_loop")
	_expect(smoke_loop != null and smoke_loop.get_track_count() == 2, "右侧烟雾缺少序列帧原点补偿轨道")
	if smoke_loop != null and smoke_loop.get_track_count() >= 2:
		_expect(
			str(smoke_loop.track_get_path(1)) == "SmokeVisual/SmokeFrame:position",
			"右侧烟雾补偿轨道没有绑定到 SmokeFrame 位置"
		)
		var top_row_offset: Vector2 = smoke_loop.track_get_key_value(1, 3)
		var bottom_row_offset: Vector2 = smoke_loop.track_get_key_value(1, 4)
		_expect(
			absf(bottom_row_offset.y - top_row_offset.y) > 200.0,
			"烟雾图集跨行时没有抵消帧内基线跳变"
		)
	clock.set_reduced_motion(true)
	var timer_smoke_initial := clock.get_state_snapshot()
	_expect(int(timer_smoke_initial.get("timer_smoke_frame_count", 0)) == 8, "左侧计时香烟雾没有使用 8 帧序列")
	_expect(bool(timer_smoke_initial.get("timer_smoke_mirrored", false)), "左侧计时香烟雾镜像状态没有写入快照")
	clock.set_timer_remaining_for_test(30.0, false)
	var timer_smoke_middle := clock.get_state_snapshot()
	_expect(
		float(timer_smoke_middle.get("timer_smoke_length", 0.0)) > float(timer_smoke_initial.get("timer_smoke_length", 0.0)),
		"计时香变短后左侧烟雾没有随燃烧端延长"
	)
	clock.set_timer_remaining_for_test(60.0, false)

	clock.set_round(1, 50, false)
	var first := clock.get_state_snapshot()
	_expect(is_equal_approx(float(first.get("round_remaining_ratio", -1.0)), 0.98), "第一回合的回合香应剩余 49/50")
	_expect(first.get("chinese_round", "") == "一", "第一回合没有显示中文烟字")
	clock.set_round(25, 50, false)
	var middle := clock.get_state_snapshot()
	_expect(is_equal_approx(float(middle.get("round_remaining_ratio", -1.0)), 0.5), "第二十五回合的回合香应剩余一半")
	_expect(float(middle.get("smoke_length", 0.0)) > float(first.get("smoke_length", 0.0)), "回合香变短后烟没有变长")
	clock.set_round(50, 50, false)
	var final := clock.get_state_snapshot()
	_expect(is_zero_approx(float(final.get("round_remaining_ratio", -1.0))), "第五十回合的回合香没有烧完")
	_expect(final.get("chinese_round", "") == "五十", "第五十回合中文烟字错误")
	_expect(int(final.get("smoke_frame_count", 0)) == 8, "上飘烟雾没有使用 8 帧序列")

	var timeout_actions: Array[int] = []
	clock.timed_out.connect(func(action_index: int) -> void: timeout_actions.append(action_index))
	clock.sync_player_view({
		"action_index": 7,
		"full_round_index": 3,
		"round_limit_public": 50,
		"viewer_side": "red",
		"active_side": "red",
		"terminal": false,
	}, true)
	clock.set_timer_remaining_for_test(0.03, true)
	await create_timer(0.08).timeout
	_expect(timeout_actions == [7], "计时香烧完后没有且仅没有发送当前行动序号")
	clock.sync_player_view({
		"action_index": 8,
		"full_round_index": 3,
		"round_limit_public": 50,
		"viewer_side": "red",
		"active_side": "red",
		"terminal": false,
	}, true)
	var reset := clock.get_state_snapshot()
	_expect(is_equal_approx(float(reset.get("remaining_seconds", 0.0)), 60.0), "新行动没有把计时香重置为 60 秒")
	_expect(bool(reset.get("timer_running", false)), "轮到本地玩家时计时香没有开始燃烧")

	var drawer := DRAWER_SCENE.instantiate() as PieceInfoDrawer
	root.add_child(drawer)
	await process_frame
	_expect(
		drawer.get_node("Background").texture.resource_path == "res://assets/art/ui/terracotta_hud_v2/incense_assembly/piece_info_drawer_frame_v2.png",
		"棋子信息展开栏没有使用正式边框资源"
	)
	_expect(not drawer.visible, "棋子信息展开栏默认没有隐藏")
	drawer.show_piece({"id": "red-cannon", "piece_type": "cannon"}, true, false)
	var cannon_state := drawer.get_state_snapshot()
	_expect(bool(cannon_state.get("visible", false)), "选中棋子后展开栏没有显示")
	_expect(bool(cannon_state.get("bombard_visible", false)), "选中炮后没有显示轰炸技能")
	_expect(not bool(cannon_state.get("resurrect_visible", true)), "选中炮后错误显示了复活技能")
	_expect(
		str(cannon_state.get("layout_structure", "")) == "text_left_actions_right",
		"棋子展开栏没有采用左文字、右操作区布局"
	)
	_expect(int(cannon_state.get("visible_action_button_count", 0)) == 2, "炮展开栏没有显示两个操作按钮")
	_expect(bool(cannon_state.get("buttons_horizontal", false)), "炮展开栏的两个按钮没有横向排列")
	drawer.show_piece({"id": "red-advisor", "piece_type": "advisor"}, true, false)
	var advisor_state := drawer.get_state_snapshot()
	_expect(bool(advisor_state.get("resurrect_visible", false)), "选中士后没有显示复活技能")
	_expect(int(advisor_state.get("visible_action_button_count", 0)) == 2, "士展开栏没有显示两个操作按钮")
	_expect(bool(advisor_state.get("buttons_horizontal", false)), "士展开栏的两个按钮没有横向排列")
	drawer.hide_drawer(false)
	_expect(not drawer.visible, "取消选择后展开栏没有隐藏")

	drawer.queue_free()
	clock.queue_free()
	await process_frame
	_finish()


func _check_chinese_numbers() -> void:
	var expected := {1: "一", 10: "十", 11: "十一", 20: "二十", 25: "二十五", 50: "五十"}
	for round_number: int in expected:
		_expect(ClockScript.chinese_number(round_number) == expected[round_number], "中文回合数字错误：%d" % round_number)


func _finish() -> void:
	if _failures.is_empty():
		print("INCENSE_TURN_CLOCK_CONTRACT_PASS rounds=50 timer_seconds=60 smoke_frames=8")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("INCENSE_TURN_CLOCK_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
