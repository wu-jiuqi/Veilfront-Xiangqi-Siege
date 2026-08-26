class_name TutorialContextReminder
extends PanelContainer

const SECTION: String = "tutorial_context_reminders_v1"
const PROGRESS_PATH: String = "user://level_progress.cfg"
const TutorialChapterCatalog = preload("res://scripts/game/tutorial/tutorial_chapter_catalog.gd")

@onready var _title_label: Label = %ReminderTitle
@onready var _body_label: Label = %ReminderBody
@onready var _dismiss_button: Button = %DismissButton

var _policy := TutorialContextReminderPolicy.new()
var _progress_store: TutorialProgressStore
var _seen_ids: Array[String] = []
var _current_id: String = ""
var _enabled: bool = true


func _ready() -> void:
	visible = false
	_dismiss_button.pressed.connect(_dismiss_current)
	_progress_store = TutorialProgressStore.new(PROGRESS_PATH, TutorialChapterCatalog.CATALOG)
	_progress_store.load_progress()
	_load_seen_ids()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		visible = false


func consume_visible_events(events: Array) -> void:
	if not _enabled:
		return
	_present(_policy.reminder_for_events(events, _progress_store.capability_states()))


func consume_visible_error(error: Dictionary) -> void:
	if not _enabled:
		return
	_present(_policy.reminder_for_error(error, _progress_store.capability_states()))


func get_public_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"reminder_id": _current_id,
		"title": _title_label.text if is_node_ready() else "",
		"body": _body_label.text if is_node_ready() else "",
	}


func _present(reminder: Dictionary) -> void:
	if reminder.is_empty():
		return
	var reminder_id := str(reminder.get("id", ""))
	if reminder_id.is_empty() or reminder_id in _seen_ids:
		return
	_current_id = reminder_id
	_title_label.text = str(reminder.get("title", "战场提示"))
	_body_label.text = str(reminder.get("body", ""))
	visible = true
	_dismiss_button.grab_focus()


func _dismiss_current() -> void:
	if not _current_id.is_empty() and _current_id not in _seen_ids:
		_seen_ids.append(_current_id)
		_seen_ids.sort()
		_save_seen_ids()
	visible = false
	_current_id = ""


func _load_seen_ids() -> void:
	var config := ConfigFile.new()
	if config.load(PROGRESS_PATH) != OK:
		return
	var value: Variant = config.get_value(SECTION, "seen_ids", [])
	if value is Array:
		for item: Variant in value:
			var reminder_id := str(item)
			if not reminder_id.is_empty() and reminder_id not in _seen_ids:
				_seen_ids.append(reminder_id)


func _save_seen_ids() -> void:
	var config := ConfigFile.new()
	var load_error := config.load(PROGRESS_PATH)
	if load_error not in [OK, ERR_FILE_NOT_FOUND]:
		return
	config.set_value(SECTION, "seen_ids", _seen_ids.duplicate())
	config.save(PROGRESS_PATH)
