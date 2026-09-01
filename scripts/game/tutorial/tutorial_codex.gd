class_name TutorialCodex
extends Control

signal closed()

const PAGES: Array[Dictionary] = [
	{
		"image": "page_00_board_turns.png",
		"category": "基础 · 战场",
		"title": "棋盘与一个完整轮",
		"key_rule": "棋子落在线的交点；赤方先手，双方各行动一次才算一个完整轮。",
		"steps": "① 选择棋子与目标\n② 查看预览，再确认提交\n③ 玄方行动后，完整轮结束",
		"pitfall": "主动跳过、超时或无合法行动也会推进战局；镜像视角只改变显示，不改变规则坐标。",
		"visual_caption": "看图重点：棋子站在两条线的交叉处，不站在格子中央。",
	},
	{
		"image": "page_01_pawn.png",
		"category": "普通行动 · 兵卒",
		"title": "只进不退，一次一格",
		"key_rule": "兵卒每次只能向前、向左或向右走一格，也可以吃掉终点的敌棋。",
		"steps": "① 先看本方朝向\n② 从前、左、右三点选一处\n③ 终点有敌棋就完成吃子",
		"pitfall": "兵卒永远不能后退。本作从开局起就按传统象棋“过河后”的走法处理，没有过河前后的切换。",
		"visual_caption": "看图重点：兵卒身后没有可选方向。",
	},
	{
		"image": "page_02_horse_elephant.png",
		"category": "普通行动 · 马与相",
		"title": "马走日，相走田",
		"key_rule": "马走二加一的日字；相沿对角线走两格，落在田字对角。",
		"steps": "① 马先看紧邻的“马腿”\n② 相先看田字中心的“象眼”\n③ 阻挡点为空，才能到达终点",
		"pitfall": "马腿和象眼只在任意一方的大本营内生效；马、相都能走遍全盘，不受传统河界或半场限制。",
		"visual_caption": "看图重点：阻挡发生在路径上的关键点，不是终点。",
	},
	{
		"image": "page_03_rook_cannon.png",
		"category": "普通行动 · 车与炮",
		"title": "车走直线，炮隔一子",
		"key_rule": "车沿横竖直线行动；炮平时也走直线，但吃子时必须恰好隔着一枚棋子。",
		"steps": "① 车检查整条直线路径\n② 炮移动到空点时不需要炮架\n③ 炮吃子时只允许一个炮架",
		"pitfall": "车和炮都不能穿过友军。炮架只负责“隔一子吃子”，不能多一枚，也不能少一枚。",
		"visual_caption": "看图重点：炮、炮架、目标必须在同一条直线上。",
	},
	{
		"image": "page_04_palace_general.png",
		"category": "普通行动 · 士与将帅",
		"title": "守在九宫，实际阵亡才败",
		"key_rule": "士在九宫内斜走一格；将帅在九宫内横竖走一格。",
		"steps": "① 找到本方九宫边界\n② 士只选斜线相邻点\n③ 将帅只选横竖相邻点",
		"pitfall": "本作没有将军、应将、照面或飞将限制。将帅可以进入受威胁点，只有实际被吃才触发终局。",
		"visual_caption": "看图重点：九宫边界限制落点，但不会替将帅挡住攻击。",
	},
	{
		"image": "page_05_fog_flag_memory.png",
		"category": "信息 · 迷雾",
		"title": "走到哪里，看见哪里",
		"key_rule": "普通棋子照亮当前位置周围的 3×3；棋子离开后，旧区域会重新进入迷雾。",
		"steps": "① 移动棋子扩展当前视野\n② 离开后旧区域重新入雾\n③ 发现过的旗帜永久保留图标",
		"pitfall": "看见一个交点不等于能看见隐身马。普通视野、破墙视野都不是自动反隐。",
		"visual_caption": "看图重点：亮区跟着棋子移动，旗帜记忆不会随迷雾消失。",
	},
	{
		"image": "page_06_special_eligibility.png",
		"category": "特殊行动 · 共同资格",
		"title": "先看墙，再看整条路线",
		"key_rule": "马、相、车、兵的特殊移动要求目标方城墙完整，而且起点、路径、终点都在正式战区。",
		"steps": "① 确认目标方城墙仍完整\n② 检查起点是否在战区\n③ 检查整条路径与终点都不越界",
		"pitfall": "城墙一旦倒塌，针对该方的马、相、车、兵特殊能力立即失效。炮击使用自己的独立资格。",
		"visual_caption": "看图重点：特殊行动资格是“墙完整”和“全程在战区”两个条件同时成立。",
	},
	{
		"image": "page_07_hidden_horse_elephant_field.png",
		"category": "特殊行动 · 马与相",
		"title": "马隐身，相布田",
		"key_rule": "合资格的马能越过马腿并隐身；相移动后会留下扩展视野和田字阻挡区。",
		"steps": "① 特殊马越腿落入隐身\n② 相以起点、田字和终点建立视野\n③ 敌车、敌兵首次进入相田会停下",
		"pitfall": "相田只拦敌车与敌兵从外部首次进入；格内棋子可以离开，己方棋子不受阻挡。相再次移动会清除自己的旧相田。",
		"visual_caption": "看图重点：隐身马与相田是两种不同的信息和路径机制。",
	},
	{
		"image": "page_08_special_rook_pawn.png",
		"category": "特殊行动 · 车与兵",
		"title": "车斩路径，兵穿敌阵",
		"key_rule": "特殊车沿路径依次处理敌棋；特殊兵可横向或纵向穿越敌军 2–5 个点。",
		"steps": "① 先检查整条路径没有友军\n② 车按从近到远依次斩敌\n③ 兵穿敌不伤，落在空终点",
		"pitfall": "兵不能穿友军，也不会获得路径视野；车会留下临时路径视野，直到这辆车下次移动开始。",
		"visual_caption": "看图重点：车处理沿途目标；兵只穿过敌军，不伤害沿途棋子。",
	},
	{
		"image": "page_09_bombardment.png",
		"category": "特殊行动 · 炮",
		"title": "锁定九点，同时命中三点",
		"key_rule": "炮在己方大本营、敌墙完整且有弹药时，可从目标 3×3 中随机命中三个不同点。",
		"steps": "① 预览并确认一个 3×3 目标区\n② 规则随机锁定三个不同命中点\n③ 三点在同一结算窗口同时受击",
		"pitfall": "炮击允许友伤，炮本身不移动；每炮两发且没有共享冷却。动画先后不能改变同步结算。",
		"visual_caption": "看图重点：九点是候选区，最终只锁定其中三个不同点。",
	},
	{
		"image": "page_10_advisor_sacrifice.png",
		"category": "特殊行动 · 士",
		"title": "先献祭，再随机复活援军",
		"key_rule": "确认献祭后，士先实际阵亡，再从本方公开阵亡记录中随机复活一枚合资格棋子。",
		"steps": "① 选择士并查看献祭预览\n② 确认后，发动的士先阵亡\n③ 从非士、非将帅候选中随机复活",
		"pitfall": "预览可以取消且不耗行动。士献祭不是被动替死；士和将帅会留在公开阵亡记录，但不能成为复活候选。",
		"visual_caption": "看图重点：这是一次主动交换，不是将帅受击时自动触发。",
	},
	{
		"image": "page_11_wall_breach_entry.png",
		"category": "城墙 · 破墙",
		"title": "三子破墙，两步进营",
		"key_rule": "缓冲区同时出现三枚入侵棋，城墙立即倒塌；之后仍要分两次行动进入敌方大本营。",
		"steps": "① 从战区进入敌方缓冲区\n② 凑齐三枚入侵棋，墙倒塌\n③ 下一次行动再从缓冲区进大本营",
		"pitfall": "完整城墙会阻止踏入或跨越墙线。破墙只开放道路，不会把棋子直接送进大本营。",
		"visual_caption": "看图重点：缓冲区是破墙前的集结带，也是进营前必须停留的一站。",
	},
	{
		"image": "page_12_wall_repair.png",
		"category": "城墙 · 修复",
		"title": "不足三子，开始修墙",
		"key_rule": "缓冲区与大本营内的入侵棋少于三枚时开始修复；之后双方各行动一次且条件仍成立，城墙才恢复。",
		"steps": "① 入侵棋总数降到三枚以下\n② 修复启动后的赤、玄各行动一次\n③ 条件持续成立，城墙恢复",
		"pitfall": "启动修复的那次行动不计时；期间重新达到三名入侵者会中断。修复完成会撤回守方大本营内的入侵棋。",
		"visual_caption": "看图重点：修墙有等待窗口，给进攻方一次重新凑齐三子的机会。",
	},
	{
		"image": "page_13_flag_capture.png",
		"category": "旗帜 · 占领",
		"title": "同一枚棋子守满三段",
		"key_rule": "一枚棋子停在中立旗或敌旗上，会建立占领进度；必须由同一枚棋子坚持到 3/3。",
		"steps": "① 棋子停上旗点，建立 1/3\n② 守住旗点，让进度继续\n③ 到达 3/3，完成占领或反占",
		"pitfall": "占领者离开、阵亡、主动献祭或被城墙修复撤回，未完成进度都会清零，也不能换另一枚棋子接力。",
		"visual_caption": "看图重点：进度绑定的是正在旗点上的那一枚棋子。",
	},
	{
		"image": "page_14_flag_contest.png",
		"category": "旗帜 · 争夺",
		"title": "争夺冻结胜利，完成才翻旗",
		"key_rule": "敌方开始反占时，旗帜仍归原所有者，但进入争夺状态；完成 3/3 才翻转所有权。",
		"steps": "① 敌棋站上已有主人的旗\n② 原所有权保留，三旗胜利暂时冻结\n③ 反占完成后，旗帜正式翻转",
		"pitfall": "反占中断时，旗仍属于原主人；轮上限计旗也仍计原主人，只有即时三旗胜利会排除争夺旗。",
		"visual_caption": "看图重点：争夺不是立刻变色，而是给原所有权加上“暂不可结胜”的状态。",
	},
	{
		"image": "page_15_victory.png",
		"category": "终局 · 胜负",
		"title": "三旗或斩将；同窗双亡为和",
		"key_rule": "拥有三面非争夺旗，或让敌方将帅实际阵亡，都能立即结束对局。",
		"steps": "① 先登记同一结算窗口的实际死亡\n② 优先检查将帅是否阵亡\n③ 非终局时再检查三面非争夺旗",
		"pitfall": "同一次炮击中双方将帅都阵亡则平局。动画播放顺序不代表规则顺序；将帅阵亡优先于同窗形成的三旗。",
		"visual_caption": "看图重点：胜负看同一逻辑窗口，不看谁的动画先播完。",
	},
	{
		"image": "page_16_casualty_reserve.png",
		"category": "棋子 · 阵亡与后备",
		"title": "阵亡公开，满营进入后备",
		"key_rule": "所有实际阵亡都会进入双方可见的公开记录；复活或撤回时若本方大本营没有空点，就进入后备队列。",
		"steps": "① 实际阵亡写入公开记录\n② 无空点的回营棋按顺序进入后备\n③ 本方行动开始有空点时自动部署",
		"pitfall": "公开阵亡记录不等于士献祭候选池。士和将帅也会公开记录，但会被献祭复活候选过滤掉。",
		"visual_caption": "看图重点：后备是等待空位的队列，不是新的阵亡状态。",
	},
	{
		"image": "page_17_action_preview.png",
		"category": "信息 · 行动预览",
		"title": "预览帮助决策，不替你侦察",
		"key_rule": "合法点、高亮、错误和提示只能使用你已经获准看到的信息，不能暴露隐身棋或未知旗位。",
		"steps": "① 金色表示可直接提交\n② 琥珀表示公开可知的风险\n③ 红色表示根据可见信息已知不可行",
		"pitfall": "两个公开信息完全相同的局面，必须给出相同的预览和拒绝提示；不能靠反复悬停或试点推断隐藏差异。",
		"visual_caption": "看图重点：颜色解释当前可见决策，不承诺揭示真实隐藏路径。",
	},
]
const IMAGE_ROOT: String = "res://assets/art/tutorial/diagram_v3/"

@onready var _image: TextureRect = %PageImage
@onready var _page_label: Label = %PageLabel
@onready var _category_label: Label = %PageCategory
@onready var _title_label: Label = %PageTitle
@onready var _key_rule_label: Label = %KeyRule
@onready var _steps_label: Label = %StepsText
@onready var _pitfall_label: Label = %PitfallText
@onready var _visual_caption_label: Label = %VisualCaption
@onready var _previous_button: Button = %PreviousButton
@onready var _next_button: Button = %NextButton
@onready var _close_button: Button = %CloseButton

var _page_index: int = 0
var _requested_image_path: String = ""


func _ready() -> void:
	visible = false
	set_process(false)
	_previous_button.pressed.connect(_show_page.bind(-1))
	_next_button.pressed.connect(_show_page.bind(1))
	_close_button.pressed.connect(close_codex)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close_codex()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _requested_image_path.is_empty():
		set_process(false)
		return
	var status := ResourceLoader.load_threaded_get_status(_requested_image_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_image.texture = ResourceLoader.load_threaded_get(_requested_image_path) as Texture2D
		_requested_image_path = ""
		set_process(false)
	elif status == ResourceLoader.THREAD_LOAD_FAILED \
	or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("TutorialCodex could not load page image")
		_requested_image_path = ""
		set_process(false)


func open_codex(page_index: int = 0) -> void:
	_page_index = clampi(page_index, 0, PAGES.size() - 1)
	visible = true
	move_to_front()
	_render_page()
	_close_button.grab_focus()


func close_codex() -> void:
	visible = false
	closed.emit()


func get_public_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"page_index": _page_index,
		"page_count": PAGES.size(),
		"category": _category_label.text if is_node_ready() else "",
		"title": _title_label.text if is_node_ready() else "",
		"body": _key_rule_label.text if is_node_ready() else "",
		"key_rule": _key_rule_label.text if is_node_ready() else "",
		"steps": _steps_label.text if is_node_ready() else "",
		"pitfall": _pitfall_label.text if is_node_ready() else "",
		"visual_caption": _visual_caption_label.text if is_node_ready() else "",
		"image_path": _image.texture.resource_path if is_node_ready() and _image.texture != null else "",
	}


func _show_page(offset: int) -> void:
	_page_index = posmod(_page_index + offset, PAGES.size())
	_render_page()


func _render_page() -> void:
	if not is_node_ready():
		return
	var page: Dictionary = PAGES[_page_index]
	_requested_image_path = IMAGE_ROOT + str(page.get("image", ""))
	_image.texture = null
	var request_error := ResourceLoader.load_threaded_request(_requested_image_path)
	if request_error == OK:
		set_process(true)
	else:
		push_error("TutorialCodex could not request page image: %s" % error_string(request_error))
		_requested_image_path = ""
	_page_label.text = "战阵图鉴 · %02d / %02d" % [_page_index + 1, PAGES.size()]
	_category_label.text = str(page.get("category", "规则复习"))
	_title_label.text = str(page.get("title", "规则图鉴"))
	_key_rule_label.text = str(page.get("key_rule", ""))
	_steps_label.text = str(page.get("steps", ""))
	_pitfall_label.text = str(page.get("pitfall", ""))
	_visual_caption_label.text = str(page.get("visual_caption", ""))
