class_name FrontendRoutes
extends RefCounted

const START_SCREEN_SCENE: String = "res://scenes/game/frontend/start_screen.tscn"
const LAN_LOBBY_SCENE: String = "res://scenes/game/app/formal_lan_game_app.tscn"
const SETTINGS_SCENE: String = "res://scenes/game/frontend/settings_screen.tscn"
const LEVEL_SELECT_SCENE: String = "res://scenes/game/frontend/level_select.tscn"

static var _start_in_menu_ready: bool = false


static func lan_lobby_scene() -> String:
	return LAN_LOBBY_SCENE


static func settings_scene() -> String:
	return SETTINGS_SCENE


static func level_select_scene() -> String:
	return LEVEL_SELECT_SCENE


static func request_start_menu_ready() -> String:
	_start_in_menu_ready = true
	return START_SCREEN_SCENE


static func consume_start_menu_ready() -> bool:
	var requested := _start_in_menu_ready
	_start_in_menu_ready = false
	return requested


static func transition_service(tree: SceneTree) -> Node:
	if tree == null:
		return null
	return tree.root.get_node_or_null("SceneTransition")


static func navigate(tree: SceneTree, scene_path: String, status: String) -> Error:
	var transition := transition_service(tree)
	if transition != null and transition.has_method(&"change_scene"):
		return transition.call(&"change_scene", scene_path, status)
	return tree.change_scene_to_file(scene_path)
