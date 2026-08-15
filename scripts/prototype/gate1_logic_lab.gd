extends Control

const BOARD_WIDTH: int = 9
const BOARD_HEIGHT: int = 24
const BOARD_CELL_COUNT: int = BOARD_WIDTH * BOARD_HEIGHT

@export var initial_seed: int = 471001

var board_state: Array[int] = []
var player_view: Dictionary = {}

@onready var match_controller: Node = $MatchController
@onready var seed_value: Label = $SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/SeedGroup/SeedValue
@onready var board_state_value: Label = $SafeMargin/Page/Workspace/StatusShell/StatusMargin/StatusColumn/BoardStateValue


func _ready() -> void:
	board_state.resize(BOARD_CELL_COUNT)
	board_state.fill(0)
	match_controller.initialize(initial_seed)
	seed_value.text = str(initial_seed)
	board_state_value.text = "棋盘状态：%d 格 · prototype_core_revision3" % board_state.size()
	print("GATE1_PROTOTYPE_READY seed=%d cells=%d core=prototype_core_revision3 full_gate1=false" % [initial_seed, board_state.size()])


func get_board_cell_count() -> int:
	return board_state.size()


func get_initial_seed() -> int:
	return initial_seed


func get_player_view_snapshot() -> Dictionary:
	return player_view.duplicate(true)


func _on_match_controller_human_view_updated(updated_view: Dictionary) -> void:
	player_view = updated_view.duplicate(true)
