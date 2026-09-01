extends SceneTree

const UI_ROOT := "res://scenes/game"
const SHARED_BUTTON_SCENE := "res://scenes/game/ui/ui_motion_button.tscn"
const FORMAL_UI_SCENES: Array[String] = [
	"res://scenes/game/frontend/start_menu_overlay.tscn",
	"res://scenes/game/frontend/settings_screen.tscn",
	"res://scenes/game/frontend/level_select.tscn",
	"res://scenes/game/frontend/level_card.tscn",
	"res://scenes/game/frontend/formal_lan_lobby.tscn",
	"res://scenes/game/ui/match_hud_v2.tscn",
	"res://scenes/game/ui/match_hud_v3.tscn",
	"res://scenes/game/ui/piece_info_drawer.tscn",
	"res://scenes/game/ui/marker_menu.tscn",
	"res://scenes/game/ui/loading_transition_overlay.tscn",
	"res://scenes/game/ui/terminal_dialog.tscn",
	"res://scenes/game/ui/terracotta_modal_dialog.tscn",
	"res://scenes/game/ui/level_guide_overlay.tscn",
	"res://scenes/game/ui/level_guide_panel.tscn",
	"res://scenes/game/ui/tutorial_overlay.tscn",
	"res://scenes/game/ui/tutorial_pause_menu.tscn",
	"res://scenes/game/ui/tutorial_codex.tscn",
	"res://scenes/game/ui/tutorial_context_reminder.tscn",
	"res://scenes/game/ui/match_header.tscn",
	"res://scenes/game/ui/match_status_panel.tscn",
]
const ROLES: Array[StringName] = [&"primary", &"secondary", &"danger", &"confirm"]

var _failures: Array[String] = []
var _scene_files := 0
var _semantic_buttons := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_scan_scene_sources(UI_ROOT)
	for scene_path: String in FORMAL_UI_SCENES:
		_check_scene(scene_path)
	if _failures.is_empty():
		print(
			"FULL_UI_WORKFLOW_MIGRATION_PASS scenes=%d formal_scenes=%d semantic_buttons=%d direct_texture_buttons=0"
			% [_scene_files, FORMAL_UI_SCENES.size(), _semantic_buttons]
		)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FULL_UI_WORKFLOW_MIGRATION_FAIL failures=%d" % _failures.size())
	quit(1)


func _scan_scene_sources(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	_expect(directory != null, "无法扫描正式场景目录：%s" % directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var child_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_scan_scene_sources(child_path)
		elif entry.ends_with(".tscn"):
			_scene_files += 1
			var source := FileAccess.get_file_as_string(child_path)
			_expect(not source.contains("type=\"TextureButton\""), "%s 仍直接定义 TextureButton" % child_path)
			if child_path != SHARED_BUTTON_SCENE:
				_expect(not source.contains("type=\"Button\""), "%s 仍直接定义普通 Button" % child_path)
			_expect(not source.contains("motion_profile = null"), "%s 仍清空共享动效配置" % child_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _check_scene(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, "无法加载正式 UI 场景：%s" % scene_path)
	if packed == null:
		return
	var scene := packed.instantiate()
	_expect(scene != null, "无法实例化正式 UI 场景：%s" % scene_path)
	if scene == null:
		return
	_check_button_tree(scene, scene_path)
	scene.free()


func _check_button_tree(node: Node, scene_path: String) -> void:
	if node is Button and not node is OptionButton and not node is CheckButton:
		var button := node as Button
		_expect(button.has_method("sync_visual_state"), "%s/%s 未迁移到共享语义按钮" % [scene_path, button.name])
		if button.has_method("sync_visual_state"):
			_semantic_buttons += 1
			_expect(button.get("semantic_role") in ROLES, "%s/%s 缺少有效语义角色" % [scene_path, button.name])
			_expect(button.focus_mode != Control.FOCUS_NONE, "%s/%s 不可通过键盘或手柄聚焦" % [scene_path, button.name])
			_expect(button.custom_minimum_size.y >= 44.0, "%s/%s 的交互高度低于 44px" % [scene_path, button.name])
			for visual_name: StringName in [&"VisualRoot", &"Surface", &"ArtLayer", &"FocusFrame", &"ButtonLabel"]:
				var visual := button.get_node_or_null("%%%s" % visual_name) as Control
				_expect(visual != null, "%s/%s 缺少视觉层 %s" % [scene_path, button.name, visual_name])
				if visual != null:
					_expect(visual.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s/%s/%s 截获输入" % [scene_path, button.name, visual_name])
	for child: Node in node.get_children():
		_check_button_tree(child, scene_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
