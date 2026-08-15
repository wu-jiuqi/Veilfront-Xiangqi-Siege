extends Control

const BOARD_WIDTH: int = 9
const BOARD_HEIGHT: int = 24
const BOARD_CELL_COUNT: int = BOARD_WIDTH * BOARD_HEIGHT

@export var initial_seed: int = 471001

var board_state: Array[int] = []

@onready var seed_value: Label = $SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/SeedGroup/SeedValue
@onready var board_state_value: Label = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/BoardStateValue


func _ready() -> void:
	board_state.resize(BOARD_CELL_COUNT)
	board_state.fill(0)
	seed_value.text = str(initial_seed)
	board_state_value.text = "棋盘状态：%d 格空白运行时数据" % board_state.size()
	print("GATE1_PHASE1_READY seed=%d cells=%d rules=not_implemented" % [initial_seed, board_state.size()])


func get_board_cell_count() -> int:
	return board_state.size()


func get_initial_seed() -> int:
	return initial_seed
