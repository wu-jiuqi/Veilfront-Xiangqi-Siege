extends SceneTree

const DIALOG_SCENE_PATH := "res://scenes/game/ui/terracotta_modal_dialog.tscn"
const DIALOG_SCRIPT_PATH := "res://scripts/game/presentation/ui/terracotta_modal_dialog.gd"
const THEME_PATH := "res://resources/game/ui/themes/veilfront_ui_theme_v2.tres"
const SCENE_DIALOGS: Dictionary[String, Array] = {
	"res://scenes/game/frontend/start_menu_overlay.tscn": [
		{"path": "NoticeDialog", "cancel": false},
		{"path": "QuitDialog", "cancel": true},
		{"path": "FatalErrorDialog", "cancel": false},
	],
	"res://scenes/game/frontend/settings_screen.tscn": [
		{"path": "DisplayConfirmDialog", "cancel": true},
		{"path": "ResetProgressDialog", "cancel": true},
		{"path": "ErrorDialog", "cancel": false},
	],
	"res://scenes/game/frontend/level_select.tscn": [
		{"path": "ResetDialog", "cancel": true},
	],
	"res://scenes/game/app/formal_lan_game_app.tscn": [
		{"path": "GlobalOverlayHost/LeaveSessionDialog", "cancel": true},
		{"path": "GlobalOverlayHost/ConnectionErrorDialog", "cancel": false},
		{"path": "GlobalOverlayHost/FatalErrorDialog", "cancel": false},
	],
	"res://scenes/game/app/game_app.tscn": [
		{"path": "GlobalOverlayHost/FatalErrorDialog", "cancel": false},
	],
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_no_native_dialogs("res://scenes")
	_check_no_native_dialog_scripts("res://scripts")
	var checked_dialogs := 0
	for scene_path: String in SCENE_DIALOGS:
		var packed_scene := load(scene_path) as PackedScene
		_expect(packed_scene != null, "dialog owner scene must load: %s" % scene_path)
		if packed_scene == null:
			continue
		var scene_root := packed_scene.instantiate()
		for contract: Dictionary in SCENE_DIALOGS[scene_path]:
			var dialog_path := str(contract["path"])
			var dialog := scene_root.get_node_or_null(dialog_path) as Control
			_expect(dialog != null, "custom modal missing: %s:%s" % [scene_path, dialog_path])
			if dialog == null:
				continue
			_expect(dialog.get_script().resource_path == DIALOG_SCRIPT_PATH, "custom modal script mismatch")
			_expect(bool(dialog.get("show_cancel_button")) == bool(contract["cancel"]), "cancel role mismatch: %s" % dialog_path)
			_expect(dialog.theme != null and dialog.theme.resource_path == THEME_PATH, "modal does not use unified theme")
			var panel := dialog.find_child("DialogPanel", true, false) as PanelContainer
			var confirm := dialog.get_node("%ConfirmButton") as Button
			var cancel := dialog.get_node("%CancelButton") as Button
			_expect(panel != null and panel.theme_type_variation == &"OverlaySurface", "modal panel is not the unified overlay surface")
			_expect(confirm.theme_type_variation == &"ConfirmButton", "modal confirm role mismatch")
			_expect(cancel.theme_type_variation == &"SecondaryButton", "modal cancel role mismatch")
			_expect(confirm.get_theme_stylebox("normal") is StyleBoxFlat, "modal confirm style is not scalable")
			_expect(cancel.get_theme_stylebox("normal") is StyleBoxFlat, "modal cancel style is not scalable")
			checked_dialogs += 1
		scene_root.free()

	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	root.add_child(viewport)
	var preview_dialog := (load(DIALOG_SCENE_PATH) as PackedScene).instantiate() as Control
	viewport.add_child(preview_dialog)
	preview_dialog.set("title", "离开联机会话")
	preview_dialog.set("dialog_text", "确定离开当前房间吗？连接和准备状态将被清除。")
	preview_dialog.set("show_cancel_button", true)
	preview_dialog.call("popup_centered")
	await process_frame
	var title_label := preview_dialog.get_node("%TitleLabel") as Label
	var body_label := preview_dialog.get_node("%BodyLabel") as Label
	var button_row := preview_dialog.get_node("%ButtonRow") as HBoxContainer
	_expect(title_label.get_global_rect().end.y <= body_label.get_global_rect().position.y, "modal title overlaps body")
	_expect(body_label.get_global_rect().end.y <= button_row.get_global_rect().position.y, "modal body overlaps actions")
	_expect((preview_dialog.get_node("%CancelButton") as Button).visible, "cancel action is not visible")
	_expect(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(preview_dialog.get_global_rect()), "modal exceeds 960x540")
	viewport.queue_free()
	await process_frame

	if _failures.is_empty():
		print("SYSTEM_DIALOG_THEME_CONTRACT_PASS dialogs=%d scalable=true native=0" % checked_dialogs)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("SYSTEM_DIALOG_THEME_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_no_native_dialogs(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	_expect(directory != null, "scene directory must be readable: %s" % directory_path)
	if directory == null:
		return
	for child_directory: String in directory.get_directories():
		_check_no_native_dialogs(directory_path.path_join(child_directory))
	for file_name: String in directory.get_files():
		if not file_name.ends_with(".tscn"):
			continue
		var scene_text := FileAccess.get_file_as_string(directory_path.path_join(file_name))
		_expect(not scene_text.contains('type="AcceptDialog"'), "%s uses AcceptDialog" % file_name)
		_expect(not scene_text.contains('type="ConfirmationDialog"'), "%s uses ConfirmationDialog" % file_name)


func _check_no_native_dialog_scripts(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	_expect(directory != null, "script directory must be readable: %s" % directory_path)
	if directory == null:
		return
	for child_directory: String in directory.get_directories():
		_check_no_native_dialog_scripts(directory_path.path_join(child_directory))
	for file_name: String in directory.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var script_text := FileAccess.get_file_as_string(directory_path.path_join(file_name))
		_expect(not script_text.contains("extends AcceptDialog"), "%s extends AcceptDialog" % file_name)
		_expect(not script_text.contains("extends ConfirmationDialog"), "%s extends ConfirmationDialog" % file_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
