class_name TutorialCodex
extends Control

signal closed()

const PAGES: Array[Dictionary] = [
	{"image": "page_00_board_turns.png", "title": "棋盘、区域与完整轮", "body": "棋子落在九路二十四线的交点。赤方先手；双方各完成一次行动才构成一个完整轮。主动跳过也会推进战局。"},
	{"image": "page_01_pawn.png", "title": "兵卒普通行动", "body": "兵卒始终按传统过河后处理：向前、向左或向右一步，不可后退；终点敌棋可以被吃。"},
	{"image": "page_02_horse_elephant.png", "title": "马与相的普通行动", "body": "马走日并在大本营内检查蹩腿；相走田并检查象眼。本作没有传统河界对马、相的半场限制。"},
	{"image": "page_03_rook_cannon.png", "title": "车与炮的普通行动", "body": "车沿横竖直线行动且不能穿友。炮普通移动不需炮架，精确吃子必须恰隔一枚棋子。"},
	{"image": "page_04_palace_general.png", "title": "九宫与实际阵亡", "body": "士在九宫内斜走，将帅在九宫内直走。本作没有将军、应将、照面或飞将，实际阵亡才触发终局。"},
	{"image": "page_05_fog_flag_memory.png", "title": "动态迷雾与旗帜记忆", "body": "普通棋子提供当前位置周围 3×3 视野；离开后旧区域会重新入雾。旗帜一旦被本方发现就永久保留图标。"},
	{"image": "page_06_special_eligibility.png", "title": "特殊行动共同资格", "body": "除炮外的兵种特殊行动要求敌墙完整，且起点、路径和终点全部位于正式战区范围。"},
	{"image": "page_07_hidden_horse_elephant_field.png", "title": "隐身马与相田", "body": "合资格的马可越腿并隐身；普通视野不等于反隐。相田提供扩展视野，并阻挡敌车、敌兵首次进入。"},
	{"image": "page_08_special_rook_pawn.png", "title": "车与兵的穿阵行动", "body": "特殊车按路径顺序处理敌棋并留下临时路径视野；特殊兵可横纵穿越敌军 2–5 点，但不能穿友军。"},
	{"image": "page_09_bombardment.png", "title": "炮击", "body": "大本营内的炮在敌墙完整且有弹药时，可在 3×3 区域随机轰击三个不同点。允许友伤，每炮两发且无共享冷却。"},
	{"image": "page_10_advisor_sacrifice.png", "title": "士献祭复活", "body": "献祭预览可以取消；提交后士先阵亡，再从非士、非将帅的合资格公开阵亡棋中随机复活一枚。"},
	{"image": "page_11_wall_breach_entry.png", "title": "破墙与进营", "body": "完整墙阻挡入侵。缓冲区同时存在三枚敌棋会立即破墙；破墙后仍要先从缓冲区起步，下一行动才能进入敌营。"},
	{"image": "page_12_wall_repair.png", "title": "修墙、中断与撤回", "body": "敌军总数少于三时开始修复；双方各行动一次且条件仍满足才完成。期间恢复三名入侵者会再次破坏。"},
	{"image": "page_13_flag_capture.png", "title": "旗帜占领", "body": "占领由同一枚棋子从 1/3 推进至 3/3。占领者离开、阵亡、献祭或被撤回都会清零。"},
	{"image": "page_14_flag_contest.png", "title": "反占与争夺", "body": "敌方开始反占时原所有权暂时保留并标记争夺；中断则保持原主，完成 3/3 才翻转所有权。"},
	{"image": "page_15_victory.png", "title": "三旗、斩将与双将", "body": "同一方拥有三旗且均不在争夺中，或敌方将帅实际阵亡，即刻结算。同步窗口双方将帅均死则平局。"},
	{"image": "page_16_casualty_reserve.png", "title": "公开阵亡与后备", "body": "阵亡记录对双方公开。营内无空点时，撤回或复活棋按 FIFO 进入后备，并在本方行动开始有空点时自动部署。"},
	{"image": "page_17_action_preview.png", "title": "预览不是免费侦察", "body": "合法点、高亮、错误与提示只能使用玩家可见信息。隐藏等价局面必须给出相同反馈，预览不会泄露隐身棋或未知旗位。"},
]
const IMAGE_ROOT: String = "res://assets/art/tutorial/comic_v1/"

@onready var _image: TextureRect = %PageImage
@onready var _page_label: Label = %PageLabel
@onready var _title_label: Label = %PageTitle
@onready var _body_label: Label = %PageBody
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
		"title": _title_label.text if is_node_ready() else "",
		"body": _body_label.text if is_node_ready() else "",
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
	_title_label.text = str(page.get("title", "规则图鉴"))
	_body_label.text = str(page.get("body", ""))
