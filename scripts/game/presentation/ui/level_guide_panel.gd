extends Control

signal hint_requested
signal reset_requested
signal collapsed_changed(collapsed: bool)

const EXPANDED_WIDTH := 284.0
const COLLAPSED_WIDTH := 44.0
const STATUS_GLYPHS := {
	"complete": "✓",
	"active": "◆",
	"pending": "·",
}
const STATUS_COLORS := {
	"complete": Color(0.56, 0.74, 0.43, 1.0),
	"active": Color(0.95, 0.67, 0.27, 1.0),
	"pending": Color(0.48, 0.49, 0.45, 1.0),
}

@onready var _expanded_content: Control = %ExpandedContent
@onready var _collapsed_button: Button = %CollapsedButton
@onready var _collapse_button: Button = %CollapseButton
@onready var _title_label: Label = %GuideTitle
@onready var _objective_label: Label = %ObjectiveText
@onready var _current_operation_label: Label = %CurrentOperationText
@onready var _hint_label: Label = %HintText
@onready var _hint_button: Button = %HintButton
@onready var _reset_button: Button = %ResetButton

var _step_status_labels: Array[Label] = []
var _step_text_labels: Array[Label] = []
var _step_statuses: Array[String] = ["complete", "active", "pending"]
var _hint_text := ""
var _hint_revealed := false
var _hint_available := true
var _reset_available := true
var _collapsed := false
var _pending_view: Dictionary = {}


func _ready() -> void:
	_step_status_labels = [%Step1Status, %Step2Status, %Step3Status]
	_step_text_labels = [%Step1Text, %Step2Text, %Step3Text]
	_collapse_button.pressed.connect(func() -> void: set_collapsed(true))
	_collapsed_button.pressed.connect(func() -> void: set_collapsed(false))
	_hint_button.pressed.connect(_on_hint_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_wire_focus_neighbors()
	if _pending_view.is_empty():
		configure(_default_view())
	else:
		var pending := _pending_view.duplicate(true)
		_pending_view.clear()
		configure(pending)
	set_collapsed(false)


func configure(view: Dictionary) -> void:
	if not is_node_ready():
		_pending_view = view.duplicate(true)
		return
	_title_label.text = str(view.get("title", "关卡指引"))
	_objective_label.text = str(view.get("objective", "完成当前关卡目标"))
	_current_operation_label.text = str(view.get("current_operation", "等待玩家操作"))
	_hint_text = str(view.get("hint", "观察高亮交点，规划下一步行动。"))
	_hint_revealed = bool(view.get("hint_revealed", false))
	_hint_available = bool(view.get("hint_available", true))
	_reset_available = bool(view.get("reset_available", true))

	var steps_value: Variant = view.get("steps", [])
	var steps: Array = steps_value if steps_value is Array else []
	_step_statuses.clear()
	for index: int in 3:
		var step: Dictionary = {}
		if index < steps.size() and steps[index] is Dictionary:
			step = steps[index]
		var status := _normalize_status(str(step.get("status", "pending")))
		_step_statuses.append(status)
		_step_text_labels[index].text = str(step.get("text", "待登记步骤"))
		_sync_step_status(index)
	_sync_hint()


func set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	custom_minimum_size.x = COLLAPSED_WIDTH if _collapsed else EXPANDED_WIDTH
	_expanded_content.visible = not _collapsed
	_collapsed_button.visible = _collapsed
	if _collapsed:
		_collapsed_button.grab_focus()
	else:
		_collapse_button.grab_focus()
	collapsed_changed.emit(_collapsed)


func reveal_hint() -> void:
	_hint_revealed = true
	_sync_hint()


func reset_progress() -> void:
	_step_statuses = ["active", "pending", "pending"]
	for index: int in _step_statuses.size():
		_sync_step_status(index)
	_hint_revealed = false
	_sync_hint()


func get_state_snapshot() -> Dictionary:
	return {
		"title": _title_label.text,
		"objective": _objective_label.text,
		"step_texts": _step_text_labels.map(func(label: Label) -> String: return label.text),
		"step_statuses": _step_statuses.duplicate(),
		"current_operation": _current_operation_label.text,
		"hint_text": _hint_label.text,
		"hint_revealed": _hint_revealed,
		"hint_available": _hint_available,
		"reset_available": _reset_available,
		"collapsed": _collapsed,
		"action_button_count": 2,
		"background_texture_path": str((%Background as TextureRect).texture.resource_path),
	}


func _default_view() -> Dictionary:
	return {
		"title": "关卡指引",
		"objective": "完成当前关卡目标",
		"steps": [
			{"text": "第一步", "status": "active"},
			{"text": "第二步", "status": "pending"},
			{"text": "第三步", "status": "pending"},
		],
		"current_operation": "等待玩家操作",
		"hint": "观察高亮交点，规划下一步行动。",
		"hint_revealed": false,
	}


func _on_hint_pressed() -> void:
	if not _hint_available:
		return
	reveal_hint()
	hint_requested.emit()


func _on_reset_pressed() -> void:
	if not _reset_available:
		return
	reset_progress()
	reset_requested.emit()


func _sync_hint() -> void:
	_hint_label.text = _hint_text if _hint_revealed else "点击「显示提示」查看本步提示"
	_hint_button.disabled = not _hint_available or _hint_revealed
	_hint_button.text = "提示已显示" if _hint_revealed else (
		"显示提示" if _hint_available else "提示未解锁"
	)
	_reset_button.disabled = not _reset_available


func _sync_step_status(index: int) -> void:
	var status := _normalize_status(_step_statuses[index])
	_step_statuses[index] = status
	_step_status_labels[index].text = str(STATUS_GLYPHS[status])
	_step_status_labels[index].add_theme_color_override(
		"font_color", STATUS_COLORS[status] as Color
	)
	_step_text_labels[index].add_theme_color_override(
		"font_color",
		Color(0.96, 0.78, 0.42, 1.0) if status == "active" else Color(0.82, 0.8, 0.71, 1.0)
	)


func _normalize_status(status: String) -> String:
	return status if STATUS_GLYPHS.has(status) else "pending"


func _wire_focus_neighbors() -> void:
	_collapse_button.focus_neighbor_bottom = _hint_button.get_path()
	_hint_button.focus_neighbor_top = _collapse_button.get_path()
	_hint_button.focus_neighbor_right = _reset_button.get_path()
	_reset_button.focus_neighbor_left = _hint_button.get_path()
	_reset_button.focus_neighbor_top = _collapse_button.get_path()
	_collapsed_button.focus_neighbor_left = _collapsed_button.get_path()
