extends SceneTree

const SCENE_THEME_PATHS := {
	"res://scenes/dev/ui/turn_progress_incense_lab.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
	"res://scenes/dev/ui/ui_button_motion_lab.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
	"res://scenes/game/app/game_app.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
	"res://scenes/game/frontend/formal_lan_lobby.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
	"res://scenes/game/frontend/level_select.tscn": "res://resources/game/ui/themes/level_select_master_v2_theme.tres",
	"res://scenes/game/frontend/start_screen.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
	"res://scenes/game/match/match_screen.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
	"res://scenes/game/tutorial/tutorial_level.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
	"res://scenes/prototype/network/lan_lobby.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
}
const REMOVED_PATHS: Array[String] = [
	"res://resources/game/ui/styles/graybox_ui_style.tres",
	"res://resources/game/ui/styles/terracotta_ui_style.tres",
	"res://scenes/game/ui/ui_theme_binder.tscn",
	"res://scripts/game/presentation/ui/ui_style_definition.gd",
	"res://scripts/game/presentation/ui/ui_style_service.gd",
	"res://scripts/game/presentation/ui/ui_theme_binder.gd",
	"res://scenes/game/frontend/main_menu.tscn",
	"res://scripts/game/frontend/main_menu.gd",
	"res://scripts/game/frontend/main_menu.gd.uid",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(not ProjectSettings.has_setting("autoload/UiStyleService"), "UiStyleService autoload must be removed")
	assert(root.get_node_or_null("UiStyleService") == null, "UiStyleService runtime node must not exist")

	for removed_path: String in REMOVED_PATHS:
		assert(not FileAccess.file_exists(removed_path), "dynamic skin resource must be removed: %s" % removed_path)

	for scene_path: String in SCENE_THEME_PATHS:
		var source := FileAccess.get_file_as_string(scene_path)
		assert(FileAccess.get_open_error() == OK, "scene must be readable: %s" % scene_path)
		assert(
			not source.contains('name="UiThemeBinder"'),
			"scene must not contain UiThemeBinder: %s" % scene_path
		)
		var theme_path: String = SCENE_THEME_PATHS[scene_path]
		var theme_resource_id := _find_ext_resource_id(source, theme_path)
		assert(not theme_resource_id.is_empty(), "scene Theme resource missing: %s" % scene_path)
		var root_block := _root_node_block(source)
		assert(
			root_block.contains('theme = ExtResource("%s")' % theme_resource_id),
			"scene Theme mismatch: %s" % scene_path
		)

	print("UI_STATIC_THEME_CONTRACT_PASS roots=%d removed=%d dynamic_skin=false" % [SCENE_THEME_PATHS.size(), REMOVED_PATHS.size()])
	quit(0)


func _find_ext_resource_id(source: String, resource_path: String) -> String:
	for line: String in source.split("\n"):
		if not line.begins_with("[ext_resource ") \
		or not line.contains('path="%s"' % resource_path):
			continue
		var id_field_marker := ' id="'
		var id_start := line.find(id_field_marker)
		if id_start < 0:
			return ""
		id_start += id_field_marker.length()
		var id_end := line.find('"', id_start)
		return line.substr(id_start, id_end - id_start) if id_end > id_start else ""
	return ""


func _root_node_block(source: String) -> String:
	var root_start := source.find("[node ")
	if root_start < 0:
		return ""
	var next_node := source.find("\n[node ", root_start + 1)
	return source.substr(root_start) if next_node < 0 \
		else source.substr(root_start, next_node - root_start)
