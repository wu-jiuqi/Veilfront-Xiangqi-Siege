class_name TutorialDirector
extends Node

signal public_step_changed(step: Dictionary)
signal restart_requested()
signal skip_requested()

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


func _ready() -> void:
	_policy.configure(presentation_track)
	call_deferred("_emit_initial_step")


func _emit_initial_step() -> void:
	if presentation_track != null:
		public_step_changed.emit({
			"step_id": presentation_track.initial_step_id,
			"instruction_key": "tutorial.entered",
		})


func consume_visible_events(events: Array) -> void:
	if presentation_track == null or not presentation_track.is_valid_track():
		return
	for event: Variant in events:
		if not event is Dictionary:
			continue
		var step: Dictionary = presentation_track.step_for_message(str(event.get("message_key", "")))
		if step.is_empty():
			continue
		_state = FlowState.PROMPTING
		public_step_changed.emit(step.duplicate(true))


func consume_prepared_action(_preview_id: String) -> void:
	pass


func consume_cancel_request() -> void:
	_state = FlowState.CANCELLED
	public_step_changed.emit({"step_id": "cancelled", "instruction_key": "tutorial.action_cancelled"})


func request_retry() -> void:
	if not _policy.can_retry():
		return
	_state = FlowState.RETRYING
	public_step_changed.emit({"step_id": "retrying", "instruction_key": "tutorial.retrying"})
	restart_requested.emit()


func request_skip() -> void:
	if not _policy.can_skip():
		return
	_state = FlowState.SKIPPED
	public_step_changed.emit({"step_id": "skipped", "instruction_key": "tutorial.skipped"})
	skip_requested.emit()


func request_exit() -> void:
	_state = FlowState.EXITED
	public_step_changed.emit({"step_id": "exited", "instruction_key": "tutorial.exited"})


func get_public_state() -> String:
	return FlowState.keys()[_state]
