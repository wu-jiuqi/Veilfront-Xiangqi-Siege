class_name TutorialDirector
extends Node

signal public_step_changed(step: Dictionary)
signal restart_requested()
signal skip_requested()
signal level_completed(level_id: String)
signal public_feedback_changed(kind: String, title: String, message: String)
signal action_mode_requested(mode: String)

enum FlowState {
	ENTERED,
	PROMPTING,
	CANCELLED,
	RETRYING,
	SKIPPED,
	EXITED,
}

@export var presentation_track: TutorialPresentationTrack

var _state: FlowState = FlowState.ENTERED
var _policy := TutorialSessionPolicy.new()
var _level_id: String = ""
var _step_index: int = 0
var _completed: bool = false
var _last_visible_sequence: int = 0
var _mistakes: int = 0


func _ready() -> void:
	call_deferred("_emit_initial_step")


func configure(level_id: String, track: TutorialPresentationTrack) -> bool:
	if track == null or not track.is_valid_track() or track.level_id != level_id:
		return false
	_level_id = level_id
	presentation_track = track
	_step_index = 0
	_completed = false
	_last_visible_sequence = 0
	_mistakes = 0
	return true


func _emit_initial_step() -> void:
	if presentation_track != null:
		if not presentation_track.steps.is_empty():
			_emit_current_step()
		else:
			public_step_changed.emit({
				"step_id": presentation_track.initial_step_id,
				"instruction_key": "tutorial.entered",
			})


func consume_visible_events(events: Array) -> void:
	if presentation_track == null or not presentation_track.is_valid_track():
		return
	if not presentation_track.steps.is_empty():
		for event: Variant in events:
			if not event is Dictionary:
				continue
			var visible_sequence := int(event.get("visible_sequence", 0))
			if visible_sequence <= _last_visible_sequence:
				continue
			_last_visible_sequence = visible_sequence
			if str(event.get("actor_side_public", "")) != "red":
				continue
			if str(_current_step().get("type", "")) in ["move", "bombard", "sacrifice_confirm"]:
				_advance_current_step()
				return
		return
	for event: Variant in events:
		if not event is Dictionary:
			continue
		var step: Dictionary = presentation_track.step_for_message(str(event.get("message_key", "")))
		if step.is_empty():
			continue
		_state = FlowState.PROMPTING
		public_step_changed.emit(step.duplicate(true))


func consume_prepared_action(preview_id: String) -> void:
	if preview_id.is_empty() or presentation_track == null or presentation_track.steps.is_empty():
		return
	var step: Dictionary = _current_step()
	var expected_actor := str(step.get("actor", ""))
	var expected_type := str(step.get("type", ""))
	var expected_action := "resurrect" if expected_type.begins_with("sacrifice") else expected_type
	if not expected_actor.is_empty() and not preview_id.contains(":%s:" % expected_actor):
		_register_mistake("当前步骤需要使用另一枚棋子。")
	elif expected_action in ["move", "bombard", "resurrect"] \
	and not preview_id.begins_with("%s:" % expected_action):
		_register_mistake("当前步骤需要切换行动模式。")


func consume_cancel_request() -> void:
	if presentation_track != null and not presentation_track.steps.is_empty():
		if str(_current_step().get("type", "")) in ["cancel_selection", "sacrifice_cancel"]:
			_advance_current_step()
		else:
			public_feedback_changed.emit("info", "已取消", "没有消耗行动，可以重新选择。")
		return
	_state = FlowState.CANCELLED
	public_step_changed.emit({"step_id": "cancelled", "instruction_key": "tutorial.action_cancelled"})


func request_retry() -> void:
	if not _policy.begin_request(TutorialSessionPolicy.REQUEST_RESTART):
		return
	restart_requested.emit()


func request_skip() -> void:
	if not _policy.begin_request(TutorialSessionPolicy.REQUEST_SKIP):
		return
	skip_requested.emit()


func consume_authority_resolution(request_name: String, accepted: bool) -> void:
	if not _policy.resolve_request(request_name) or not accepted:
		return
	if request_name == TutorialSessionPolicy.REQUEST_RESTART:
		if presentation_track != null and not presentation_track.steps.is_empty():
			_step_index = 0
			_completed = false
			_last_visible_sequence = 0
			_mistakes = 0
			_state = FlowState.PROMPTING
			public_feedback_changed.emit("info", "本章已重置", "固定局面和当前步骤已恢复。")
			_emit_current_step()
			return
		_state = FlowState.RETRYING
		public_step_changed.emit({"step_id": "retrying", "instruction_key": "tutorial.retrying"})
	elif request_name == TutorialSessionPolicy.REQUEST_SKIP:
		_state = FlowState.SKIPPED
		public_step_changed.emit({"step_id": "skipped", "instruction_key": "tutorial.skipped"})


func request_exit() -> void:
	_state = FlowState.EXITED
	public_step_changed.emit({"step_id": "exited", "instruction_key": "tutorial.exited"})


func get_public_state() -> String:
	return FlowState.keys()[_state]


func consume_visible_error(_error: Dictionary) -> void:
	if str(_current_step().get("type", "")) == "reject":
		_advance_current_step()
	else:
		_register_mistake("该行动没有通过公开规则检查，请按当前目标重试。")


func consume_marker(cell: Vector2i, marker_type: String) -> void:
	var step: Dictionary = _current_step()
	var target: Array = step.get("target", [])
	if str(step.get("type", "")) == "annotate" \
	and target == [cell.x, cell.y] \
	and str(step.get("marker", "")) == marker_type:
		_advance_current_step()
	else:
		_register_mistake("标记位置或类型与当前目标不一致。")


func consume_board_point(cell: Vector2i) -> void:
	var step: Dictionary = _current_step()
	if str(step.get("type", "")) != "predict":
		return
	if step.get("target", []) == [cell.x, cell.y]:
		_advance_current_step()
	else:
		_register_mistake("这个交点不是首次停止点。")


func request_continue() -> void:
	var step_type := str(_current_step().get("type", ""))
	if step_type == "observe":
		_advance_current_step()
	elif step_type in ["sacrifice_cancel", "sacrifice_confirm"]:
		action_mode_requested.emit("resurrect")


func submit_quiz_answer(option_index: int) -> void:
	var step: Dictionary = _current_step()
	if str(step.get("type", "")) != "quiz":
		return
	if option_index == int(step.get("correct", -1)):
		_advance_current_step()
	else:
		_register_mistake("答案不正确，请重新判断本章刚刚展示的公开结果。")


func request_hint() -> void:
	var step: Dictionary = _current_step()
	var target: Array = step.get("target", [])
	var target_text := ""
	if target.size() == 2:
		target_text = " 目标交点是（%d,%d）。" % [int(target[0]), int(target[1])]
	public_feedback_changed.emit(
		"info",
		"操作提示",
		"选择当前目标指定的棋子和行动模式，再选择目标交点并确认。" + target_text
	)


func get_public_checkpoint_id() -> String:
	return "completed" if _completed else str(_current_step().get("id", ""))


func _current_step() -> Dictionary:
	if presentation_track == null or _step_index < 0 or _step_index >= presentation_track.steps.size():
		return {}
	return presentation_track.steps[_step_index]


func _emit_current_step() -> void:
	var step: Dictionary = _current_step().duplicate(true)
	if step.is_empty():
		return
	step["step_index"] = _step_index
	step["step_count"] = presentation_track.steps.size()
	_state = FlowState.PROMPTING
	public_step_changed.emit(step)


func _advance_current_step() -> void:
	if _completed:
		return
	var step: Dictionary = _current_step()
	public_feedback_changed.emit(
		"success",
		"目标完成",
		str(step.get("success", "已完成当前步骤。"))
	)
	_step_index += 1
	_mistakes = 0
	if _step_index >= presentation_track.steps.size():
		_completed = true
		level_completed.emit(_level_id)
		public_step_changed.emit({
			"id": "completed",
			"title": "%s 完成" % presentation_track.title,
			"prompt": "本章检查点已记录。可以返回目录选择下一章。",
			"step_index": presentation_track.steps.size() - 1,
			"step_count": presentation_track.steps.size(),
		})
		return
	_emit_current_step()


func _register_mistake(message: String) -> void:
	_mistakes += 1
	var supplement := ""
	if _mistakes == 2:
		supplement = " 当前目标已进入强化提示。"
	elif _mistakes >= 3:
		supplement = " 可以使用“显示操作提示”。"
	public_feedback_changed.emit("info", "尚未完成", message + supplement)
