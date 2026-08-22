extends SceneTree

const SCENE_THEME_PATHS := {
	"res://scenes/dev/ui/turn_progress_incense_lab.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
	"res://scenes/dev/ui/ui_button_motion_lab.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
	"res://scenes/game/app/game_app.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
	"res://scenes/game/frontend/formal_lan_lobby.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
	"res://scenes/game/frontend/level_select.tscn": "res://resources/game/ui/themes/level_select_master_v2_theme.tres",
	"res://scenes/game/frontend/main_menu.tscn": "res://resources/game/ui/themes/terracotta_ui_theme.tres",
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
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(not ProjectSettings.has_setting("autoload/UiStyleService"), "UiStyleService autoload must be removed")
	assert(root.get_node_or_null("UiStyleService") == null, "UiStyleService runtime node must not exist")

	for removed_path: String in REMOVED_PATHS:
		assert(not FileAccess.file_exists(removed_path), "dynamic skin resource must be removed: %s" % removed_path)

	for scene_path: String in SCENE_THEME_PATHS:
		var packed_scene := load(scene_path) as PackedScene
		assert(packed_scene != null, "scene must load: %s" % scene_path)
		var scene_root := packed_scene.instantiate() as Control
		assert(scene_root != null, "scene root must be Control: %s" % scene_path)
		assert(scene_root.get_node_or_null("UiThemeBinder") == null, "scene must not contain UiThemeBinder: %s" % scene_path)
		assert(scene_root.theme != null, "scene must bind a static Theme: %s" % scene_path)
		assert(
			scene_root.theme.resource_path == SCENE_THEME_PATHS[scene_path],
			"scene Theme mismatch: %s" % scene_path
		)
		scene_root.free()

	print("UI_STATIC_THEME_CONTRACT_PASS roots=%d removed=%d dynamic_skin=false" % [SCENE_THEME_PATHS.size(), REMOVED_PATHS.size()])
	quit(0)
