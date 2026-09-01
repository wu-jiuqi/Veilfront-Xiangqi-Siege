extends SceneTree

const THEME_PATH := "res://resources/game/ui/themes/veilfront_ui_theme_v2.tres"
const SCENE_THEME_PATHS: Array[String] = [
	"res://scenes/dev/ui/gate3_ui_foundation_lab.tscn",
	"res://scenes/dev/ui/turn_progress_incense_lab.tscn",
	"res://scenes/dev/ui/ui_button_motion_lab.tscn",
	"res://scenes/game/app/game_app.tscn",
	"res://scenes/game/challenge/challenge_level.tscn",
	"res://scenes/game/frontend/formal_lan_lobby.tscn",
	"res://scenes/game/frontend/level_select.tscn",
	"res://scenes/game/frontend/settings_screen.tscn",
	"res://scenes/game/frontend/start_screen.tscn",
	"res://scenes/game/match/match_screen.tscn",
	"res://scenes/game/match/online_match_screen.tscn",
	"res://scenes/game/tutorial/tutorial_level.tscn",
	"res://scenes/game/ui/level_guide_overlay.tscn",
	"res://scenes/game/ui/marker_menu.tscn",
	"res://scenes/game/ui/match_hud_v3.tscn",
	"res://scenes/game/ui/terminal_dialog.tscn",
	"res://scenes/game/ui/tutorial_codex.tscn",
	"res://scenes/game/ui/tutorial_pause_menu.tscn",
	"res://scenes/prototype/network/lan_lobby.tscn",
]
const PRODUCTION_UI_SCENES: Array[String] = [
	"res://scenes/game/frontend/formal_lan_lobby.tscn",
	"res://scenes/game/frontend/level_card.tscn",
	"res://scenes/game/frontend/level_select.tscn",
	"res://scenes/game/frontend/settings_screen.tscn",
	"res://scenes/game/frontend/start_menu_overlay.tscn",
	"res://scenes/game/ui/level_guide_overlay.tscn",
	"res://scenes/game/ui/level_guide_panel.tscn",
	"res://scenes/game/ui/marker_menu.tscn",
	"res://scenes/game/ui/match_hud_v3.tscn",
	"res://scenes/game/ui/piece_info_drawer.tscn",
	"res://scenes/game/ui/terminal_dialog.tscn",
	"res://scenes/game/ui/terracotta_modal_dialog.tscn",
	"res://scenes/game/ui/tutorial_codex.tscn",
	"res://scenes/game/ui/tutorial_pause_menu.tscn",
]
const FORBIDDEN_REFERENCES: Array[String] = [
	"terracotta_ui_theme.tres",
	"match_hud_v3_theme.tres",
	"level_select_master_v2_theme.tres",
	"system_dialog_panel_v1.png",
	"system_dialog_button_primary_v1.png",
	"system_dialog_button_secondary_v1.png",
	"level_guide_panel_v1.png",
	"marker_menu_frame_v1.png",
	"TextureButton",
	"NinePatchRect",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path: String in SCENE_THEME_PATHS:
		var source := FileAccess.get_file_as_string(scene_path)
		_expect(FileAccess.get_open_error() == OK, "scene must be readable: %s" % scene_path)
		if source.is_empty():
			continue
		var theme_resource_id := _find_ext_resource_id(source, THEME_PATH)
		_expect(not theme_resource_id.is_empty(), "unified Theme resource missing: %s" % scene_path)
		var root_block := _root_node_block(source)
		_expect(
			root_block.contains('theme = ExtResource("%s")' % theme_resource_id),
			"scene root does not own the unified Theme: %s" % scene_path
		)

	for scene_path: String in PRODUCTION_UI_SCENES:
		var source := FileAccess.get_file_as_string(scene_path)
		for forbidden: String in FORBIDDEN_REFERENCES:
			_expect(not source.contains(forbidden), "%s still contains %s" % [scene_path, forbidden])

	if _failures.is_empty():
		print("UI_STATIC_THEME_CONTRACT_PASS roots=%d production_scenes=%d theme=v2" % [
			SCENE_THEME_PATHS.size(), PRODUCTION_UI_SCENES.size()
		])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("UI_STATIC_THEME_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _find_ext_resource_id(source: String, resource_path: String) -> String:
	for line: String in source.split("\n"):
		if not line.begins_with("[ext_resource ") or not line.contains('path="%s"' % resource_path):
			continue
		var id_start := line.find(' id="')
		if id_start < 0:
			return ""
		id_start += 5
		var id_end := line.find('"', id_start)
		return line.substr(id_start, id_end - id_start) if id_end > id_start else ""
	return ""


func _root_node_block(source: String) -> String:
	var root_start := source.find("[node ")
	if root_start < 0:
		return ""
	var next_node := source.find("\n[node ", root_start + 1)
	return source.substr(root_start) if next_node < 0 else source.substr(root_start, next_node - root_start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
