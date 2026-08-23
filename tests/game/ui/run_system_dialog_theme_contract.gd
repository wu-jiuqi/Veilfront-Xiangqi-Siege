extends SceneTree

const DIALOG_SCENE_PATH := "res://scenes/game/ui/terracotta_modal_dialog.tscn"
const DIALOG_SCRIPT_PATH := "res://scripts/game/presentation/ui/terracotta_modal_dialog.gd"
const PANEL_TEXTURE_PATH := "res://assets/art/ui/system_dialog/system_dialog_panel_v1.png"
const PRIMARY_TEXTURE_PATH := "res://assets/art/ui/system_dialog/system_dialog_button_primary_v1.png"
const SECONDARY_TEXTURE_PATH := "res://assets/art/ui/system_dialog/system_dialog_button_secondary_v1.png"
const OLD_DIALOG_SCRIPT_PATH := "res://scripts/game/presentation/ui/terracotta_system_dialog.gd"
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


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var dialog_scene := load(DIALOG_SCENE_PATH) as PackedScene
	assert(dialog_scene != null, "custom modal dialog scene must load")
	_assert_no_native_dialogs("res://scenes")
	_assert_no_native_dialog_scripts("res://scripts")
	var checked_dialogs := 0
	for scene_path: String in SCENE_DIALOGS:
		var scene_text := FileAccess.get_file_as_string(scene_path)
		assert(not scene_text.contains("type=\"AcceptDialog\""), "%s must not use AcceptDialog" % scene_path)
		assert(not scene_text.contains("type=\"ConfirmationDialog\""), "%s must not use ConfirmationDialog" % scene_path)
		assert(not scene_text.contains(OLD_DIALOG_SCRIPT_PATH), "%s must not use the native-dialog theme adapter" % scene_path)
		var packed_scene := load(scene_path) as PackedScene
		assert(packed_scene != null, "dialog owner scene must load: %s" % scene_path)
		var scene_root := packed_scene.instantiate()
		for contract: Dictionary in SCENE_DIALOGS[scene_path]:
			var dialog_path := str(contract["path"])
			var dialog := scene_root.get_node(dialog_path)
			assert(dialog is Control, "custom modal must be a Control: %s:%s" % [scene_path, dialog_path])
			assert(not dialog is Window, "custom modal must not rely on native Window layout")
			assert(dialog.get_script().resource_path == DIALOG_SCRIPT_PATH)
			assert(bool(dialog.get("show_cancel_button")) == bool(contract["cancel"]))
			assert(dialog.get_node("%PanelArt").texture.resource_path == PANEL_TEXTURE_PATH)
			assert(dialog.get_node("%ConfirmFrame").texture.resource_path == PRIMARY_TEXTURE_PATH)
			assert(dialog.get_node("%CancelFrame").texture.resource_path == SECONDARY_TEXTURE_PATH)
			checked_dialogs += 1
		scene_root.free()

	for texture_path: String in [PANEL_TEXTURE_PATH, PRIMARY_TEXTURE_PATH, SECONDARY_TEXTURE_PATH]:
		_assert_true_alpha(texture_path)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var preview_dialog := dialog_scene.instantiate() as Control
	viewport.add_child(preview_dialog)
	preview_dialog.set("title", "离开联机会话")
	preview_dialog.set("dialog_text", "确定离开当前房间吗？连接和准备状态将被清除。")
	preview_dialog.set("show_cancel_button", true)
	preview_dialog.call("popup_centered")
	await process_frame
	var title_label := preview_dialog.get_node("%TitleLabel") as Label
	var body_label := preview_dialog.get_node("%BodyLabel") as Label
	var button_row := preview_dialog.get_node("%ButtonRow") as HBoxContainer
	assert(title_label.get_global_rect().end.y <= body_label.get_global_rect().position.y)
	assert(body_label.get_global_rect().end.y <= button_row.get_global_rect().position.y)
	assert((preview_dialog.get_node("%ConfirmButton") as Button).alignment == HORIZONTAL_ALIGNMENT_CENTER)
	assert((preview_dialog.get_node("%CancelButton") as Button).alignment == HORIZONTAL_ALIGNMENT_CENTER)
	assert((preview_dialog.get_node("%CancelButton") as Button).visible)
	viewport.queue_free()
	await process_frame
	print("SYSTEM_DIALOG_ART_CONTRACT_PASS dialogs=%d assets=3 native=0" % checked_dialogs)
	quit(0)


func _assert_true_alpha(texture_path: String) -> void:
	var texture := load(texture_path) as Texture2D
	assert(texture != null, "%s must import as Texture2D" % texture_path)
	var image := texture.get_image()
	assert(image != null and not image.is_empty(), "%s must expose imported pixels" % texture_path)
	assert(image.detect_alpha() != Image.ALPHA_NONE, "%s must retain chroma-key alpha" % texture_path)
	assert(image.get_pixel(0, 0).a <= 0.05, "%s top-left corner must be transparent" % texture_path)


func _assert_no_native_dialogs(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	assert(directory != null, "scene directory must be readable: %s" % directory_path)
	for child_directory: String in directory.get_directories():
		_assert_no_native_dialogs(directory_path.path_join(child_directory))
	for file_name: String in directory.get_files():
		if not file_name.ends_with(".tscn"):
			continue
		var file_path := directory_path.path_join(file_name)
		var scene_text := FileAccess.get_file_as_string(file_path)
		assert(not scene_text.contains("type=\"AcceptDialog\""), "%s must not use AcceptDialog" % file_path)
		assert(not scene_text.contains("type=\"ConfirmationDialog\""), "%s must not use ConfirmationDialog" % file_path)


func _assert_no_native_dialog_scripts(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	assert(directory != null, "script directory must be readable: %s" % directory_path)
	for child_directory: String in directory.get_directories():
		_assert_no_native_dialog_scripts(directory_path.path_join(child_directory))
	for file_name: String in directory.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var file_path := directory_path.path_join(file_name)
		var script_text := FileAccess.get_file_as_string(file_path)
		assert(not script_text.contains("extends AcceptDialog"), "%s must not extend AcceptDialog" % file_path)
		assert(not script_text.contains("extends ConfirmationDialog"), "%s must not extend ConfirmationDialog" % file_path)
