extends SceneTree

const SCENE_PATHS: Array[String] = [
	"res://scenes/game/frontend/main_menu.tscn",
	"res://scenes/game/frontend/level_select.tscn",
	"res://scenes/game/app/game_app.tscn",
	"res://scenes/game/match/match_screen.tscn",
	"res://scenes/game/tutorial/tutorial_level.tscn",
]
const GRAYBOX_STYLE := preload("res://resources/game/ui/styles/graybox_ui_style.tres")
const TERRACOTTA_STYLE := preload("res://resources/game/ui/styles/terracotta_ui_style.tres")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var style_service: Node = root.get_node_or_null("UiStyleService")
	assert(style_service != null, "UiStyleService autoload must exist")
	var available_style_ids: Array[StringName] = style_service.get_available_style_ids()
	assert(
		available_style_ids.size() == 2
		and available_style_ids.has(&"graybox")
		and available_style_ids.has(&"terracotta"),
		"UI styles must come from the registered allowlist"
	)
	assert(GRAYBOX_STYLE.ui_theme != TERRACOTTA_STYLE.ui_theme, "styles must use distinct Theme resources")

	assert(style_service.select_style(&"graybox"), "graybox style must be selectable")
	var main_menu: Control = await _instantiate_scene(SCENE_PATHS[0])
	assert(main_menu.theme == GRAYBOX_STYLE.ui_theme, "new roots must bind the active graybox Theme")
	assert(main_menu.get_meta(&"veilfront_ui_style_id") == &"graybox")
	assert(main_menu.get_node("Background").theme_type_variation == &"ScreenBackground")
	assert(
		main_menu.get_node("SafeMargin/Center/MenuPanel/MenuMargin/MenuColumn/GameTitle").theme_type_variation
		== &"ScreenTitle"
	)
	assert(main_menu.get_node("SafeMargin/Center/MenuPanel/MenuMargin/MenuColumn/QuitButton").theme_type_variation == &"DangerButton")

	assert(style_service.select_style(&"terracotta"), "terracotta style must be selectable")
	await process_frame
	assert(main_menu.theme == TERRACOTTA_STYLE.ui_theme, "existing roots must react to style changes")
	assert(main_menu.get_meta(&"veilfront_ui_style_id") == &"terracotta")
	main_menu.queue_free()
	await process_frame

	for scene_path: String in SCENE_PATHS.slice(1):
		var scene_root: Control = await _instantiate_scene(scene_path)
		assert(scene_root.get_node_or_null("UiThemeBinder") != null, "%s must contain the preset binder" % scene_path)
		assert(scene_root.theme == TERRACOTTA_STYLE.ui_theme, "%s must inherit the active Theme" % scene_path)
		assert(scene_root.get_meta(&"veilfront_ui_style_id") == &"terracotta")
		scene_root.queue_free()
		await process_frame

	print("UI_STYLE_SWITCH_CONTRACT_PASS styles=2 roots=%d default=terracotta" % SCENE_PATHS.size())
	quit(0)


func _instantiate_scene(scene_path: String) -> Control:
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	assert(packed_scene != null, "scene must load: %s" % scene_path)
	var scene_root: Control = packed_scene.instantiate() as Control
	assert(scene_root != null, "scene root must be Control: %s" % scene_path)
	root.add_child(scene_root)
	await process_frame
	assert(scene_root.get_node_or_null("UiThemeBinder") != null, "%s must contain the preset binder" % scene_path)
	return scene_root
