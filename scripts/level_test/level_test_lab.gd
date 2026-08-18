extends "res://scripts/prototype/gate1_logic_lab.gd"

const LevelScenario = preload("res://scripts/level_test/level_scenario.gd")

const PLAYABLE_CELL_COUNT: int = BOARD_WIDTH * LevelScenario.PLAYABLE_MAX_Y


func _ready() -> void:
	ai_difficulty_id = "easy"
	super._ready()
	board_surface.set_visible_board_height(LevelScenario.PLAYABLE_MAX_Y)
	header_title.text = "《雾疆：九路烽棋》关卡试玩版"
	difficulty_caption.text = "选择关卡"
	difficulty_select.select(0)
	footer.text = "目标：50完整回合内消灭全部敌棋 · 左键选择 / Esc取消 / 右键标注"
	message_value.text = "第一关开始：敌方棋子位于战区最远边界，受迷雾遮蔽。"
	_refresh_all()
	call_deferred("_scroll_to_player_base")


func get_board_cell_count() -> int:
	return PLAYABLE_CELL_COUNT


func _scroll_to_player_base() -> void:
	await get_tree().process_frame
	var board_scroll := get_node(
		"SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/BoardScroll"
	) as ScrollContainer
	board_scroll.scroll_vertical = int(board_scroll.get_v_scroll_bar().max_value)


func _refresh_board() -> void:
	super._refresh_board()
	var visible_count: int = player_view.get("visible_cells", []).size()
	overview_strip.text = "红方大本营1–3 / 城墙与缓冲区4–8 / 战区9–16 | 可见 %d/%d · 敌军需自行侦察" % [
		visible_count,
		PLAYABLE_CELL_COUNT,
	]


func _refresh_status() -> void:
	super._refresh_status()
	var status: Dictionary = match_controller.get_level_status()
	var enemy_total: int = int(status.get("enemy_total", 0))
	var enemy_alive: int = int(status.get("enemy_alive", 0))
	flag_status.text = "关卡目标：50完整回合内消灭全部敌棋\n敌军：%d / %d 存活 · 迷雾仍然生效" % [
		enemy_alive,
		enemy_total,
	]
	var red_wall: String = ""
	for wall: Dictionary in player_view.get("walls", []):
		if str(wall.get("side", "")) == "red":
			red_wall = str(wall.get("status", ""))
	wall_status.text = "我方城墙：%s" % red_wall


func _refresh_terminal() -> void:
	terminal_overlay.visible = bool(player_view["terminal"])
	if not terminal_overlay.visible:
		return
	var won: bool = str(player_view.get("winner", "")) == "red"
	var headline: String = "关卡完成" if won else "关卡失败"
	var reason: String = {
		"all_enemies_destroyed": "已消灭全部敌棋",
		"objective_timeout": "50完整回合内未能消灭全部敌棋",
		"general_destroyed": "我方主帅被消灭",
	}.get(str(player_view.get("win_reason", "")), str(player_view.get("win_reason", "")))
	terminal_value.text = "%s\n%s\n完整回合：%d / %d" % [
		headline,
		reason,
		int(player_view["full_round_index"]),
		int(player_view["full_round_limit_hypothesis"]),
	]


func _difficulty_name(selector_id: String) -> String:
	var level_id: int = LevelScenario.level_from_selector(selector_id)
	return LevelScenario.title(level_id)
