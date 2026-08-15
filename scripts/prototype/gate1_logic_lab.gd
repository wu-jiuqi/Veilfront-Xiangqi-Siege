extends Control

const MatchState = preload("res://scripts/prototype/core/match_state.gd")

const BOARD_WIDTH: int = 9
const BOARD_HEIGHT: int = 24
const BOARD_CELL_COUNT: int = BOARD_WIDTH * BOARD_HEIGHT

@export var initial_seed: int = 471001

var board_state: Array[int] = []
var prototype_state: Dictionary = {}

@onready var seed_value: Label = $SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/SeedGroup/SeedValue
@onready var board_state_value: Label = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/BoardStateValue


func _ready() -> void:
	board_state.resize(BOARD_CELL_COUNT)
	board_state.fill(0)
	prototype_state = MatchState.create(initial_seed)
	seed_value.text = str(initial_seed)
	board_state_value.text = "棋盘状态：%d 格 · prototype_core_revision2" % board_state.size()
	print("GATE1_PROTOTYPE_READY seed=%d cells=%d core=prototype_core_revision2 full_gate1=false" % [initial_seed, board_state.size()])


func get_board_cell_count() -> int:
	return board_state.size()


func get_initial_seed() -> int:
	return initial_seed
