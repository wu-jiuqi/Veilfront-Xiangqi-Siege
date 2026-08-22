class_name FrontendRoutes
extends RefCounted

const START_SCREEN_SCENE: String = "res://scenes/game/frontend/start_screen.tscn"
const LAN_LOBBY_SCENE: String = "res://scenes/game/app/formal_lan_game_app.tscn"
const SETTINGS_SCENE: String = "res://scenes/game/frontend/settings_screen.tscn"

static var _start_in_menu_ready: bool = false


static func lan_lobby_scene() -> String:
	return LAN_LOBBY_SCENE


static func settings_scene() -> String:
	return SETTINGS_SCENE


static func request_start_menu_ready() -> String:
	_start_in_menu_ready = true
	return START_SCREEN_SCENE


static func consume_start_menu_ready() -> bool:
	var requested := _start_in_menu_ready
	_start_in_menu_ready = false
	return requested
