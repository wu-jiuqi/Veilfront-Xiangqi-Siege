extends SceneTree

const DIALOG_THEME_PATH := "res://resources/game/ui/themes/terracotta_ui_theme.tres"
const DIALOG_SCRIPT_PATH := "res://scripts/game/presentation/ui/terracotta_system_dialog.gd"
const SCENE_DIALOGS: Dictionary[String, Array] = {
	"res://scenes/game/frontend/start_menu_overlay.tscn": [
		"NoticeDialog",
		"QuitDialog",
		"FatalErrorDialog",
	],
	"res://scenes/game/frontend/settings_screen.tscn": [
		"DisplayConfirmDialog",
		"ResetProgressDialog",
		"ErrorDialog",
	],
	"res://scenes/game/frontend/level_select.tscn": ["ResetDialog"],
	"res://scenes/game/app/formal_lan_game_app.tscn": [
		"GlobalOverlayHost/LeaveSessionDialog",
		"GlobalOverlayHost/ConnectionErrorDialog",
		"GlobalOverlayHost/FatalErrorDialog",
	],
	"res://scenes/game/app/game_app.tscn": ["GlobalOverlayHost/FatalErrorDialog"],
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var checked_dialogs := 0
	for scene_path: String in SCENE_DIALOGS:
		var packed_scene := load(scene_path) as PackedScene
		assert(packed_scene != null, "dialog owner scene must load: %s" % scene_path)
		var scene_root := packed_scene.instantiate()
		for dialog_path: String in SCENE_DIALOGS[scene_path]:
			var dialog := scene_root.get_node(dialog_path) as AcceptDialog
			assert(dialog != null, "system dialog must exist: %s:%s" % [scene_path, dialog_path])
			assert(dialog.theme != null, "system dialog must declare the project dialog theme")
			assert(dialog.theme.resource_path == DIALOG_THEME_PATH)
			assert(dialog.get_script().resource_path == DIALOG_SCRIPT_PATH)
			assert(dialog.min_size.x >= 560 and dialog.min_size.y >= 220)
			checked_dialogs += 1
		scene_root.free()
	var dialog_theme := load(DIALOG_THEME_PATH) as Theme
	assert(dialog_theme != null)
	assert(dialog_theme.has_stylebox(&"embedded_border", &"Window"))
	assert(dialog_theme.has_stylebox(&"embedded_unfocused_border", &"Window"))
	assert(dialog_theme.has_constant(&"buttons_min_width", &"AcceptDialog"))
	var preview_root := (
		load("res://scenes/game/frontend/start_menu_overlay.tscn") as PackedScene
	).instantiate()
	root.add_child(preview_root)
	await process_frame
	var preview_dialog := preview_root.get_node("QuitDialog") as ConfirmationDialog
	var content_panel: Panel
	for child: Node in preview_dialog.get_children(true):
		if child is Panel:
			content_panel = child as Panel
			break
	assert(content_panel != null)
	assert(content_panel.get_theme_stylebox(&"panel") is StyleBoxTexture)
	preview_root.queue_free()
	await process_frame
	print("SYSTEM_DIALOG_THEME_CONTRACT_PASS dialogs=%d" % checked_dialogs)
	quit(0)
