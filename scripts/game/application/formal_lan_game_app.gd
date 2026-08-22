class_name FormalLanGameApp
extends Control

const FrontendRoutes = preload("res://scripts/integration/frontend_routes.gd")
const TERMINAL_LOBBY_DESTINATION: String = "lobby"

const TRANSPORT_FAILURE_STATES: Array[String] = [
	"connection_error",
	"connection_failed",
	"join_rejected",
	"server_disconnected",
	"peer_disconnected",
	"protocol_error",
]
const ERROR_TEXT: Dictionary[String, String] = {
	"address_empty": "请输入房主的局域网地址。",
	"create_server_failed": "无法创建房间，请检查端口是否被占用。",
	"create_client_failed": "无法开始连接，请检查地址与端口。",
	"connection_failed": "无法连接房主，请确认双方位于同一局域网。",
	"join_rejected": "房间拒绝加入，可能已经满员或版本不一致。",
	"room_full": "房间已经有两名玩家。",
	"protocol_version_mismatch": "双方联机协议版本不一致。",
	"reconnect_not_supported": "本版本不支持自动重连，请重新创建房间。",
	"server_disconnected": "房主已离开，当前战局不能继续。",
	"peer_disconnected": "加入者已离开，当前战局不能继续。",
	"observer_codec_rejected": "观察者安全数据校验失败，连接已关闭。",
	"observer_batch_invalid": "收到无效的观察者数据，连接已关闭。",
	"observer_seat_mismatch": "收到其他席位的数据，连接已关闭。",
	"observer_transport_invalid": "观察者数据传输校验失败，连接已关闭。",
	"observer_transport_oversized": "观察者数据超过安全上限，连接已关闭。",
	"observer_transport_compression_failed": "观察者数据压缩失败，连接已关闭。",
	"protocol_error": "联机协议异常，连接已关闭。",
	"players_not_ready": "双方都确认准备后才能开始战局。",
	"host_only": "只有房主可以开始战局。",
}

@onready var _session: Node = $FormalLanSession
@onready var _application_host: Node = $ApplicationHost
@onready var _lobby: Control = $ScreenHost/FormalLanLobby
@onready var _match_screen: Control = $ScreenHost/MatchScreen
@onready var _leave_session_dialog: ConfirmationDialog = $GlobalOverlayHost/LeaveSessionDialog
@onready var _connection_error_dialog: AcceptDialog = $GlobalOverlayHost/ConnectionErrorDialog
@onready var _fatal_error_dialog: AcceptDialog = $GlobalOverlayHost/FatalErrorDialog

var _match_active: bool = false
var _pending_navigation: String = ""
var _handled_failure_state: String = ""
var _failure_role: String = ""


func _ready() -> void:
	_match_screen.visible = false
	_lobby.visible = true
	_match_screen.call(&"set_session_navigation_enabled", true)
	_lobby.call(&"render_connection_snapshot", _session.call(&"get_public_state_snapshot"))


func _on_host_requested(port: int) -> void:
	_failure_role = "host"
	_handle_operation_result(_session.call(&"host_new_game", port, {}), "创建房间失败")


func _on_join_requested(address: String, port: int) -> void:
	_failure_role = "client"
	_handle_operation_result(_session.call(&"join_game", address, port), "加入房间失败")


func _on_ready_changed(is_ready: bool) -> void:
	_handle_operation_result(_session.call(&"set_ready", is_ready), "更新准备状态失败")


func _on_start_requested() -> void:
	_handle_operation_result(_session.call(&"start_match"), "开始战局失败")


func _on_disconnect_requested() -> void:
	_pending_navigation = "lobby"
	_leave_session_dialog.dialog_text = "确定离开当前房间吗？连接和准备状态将被清除。"
	_popup_leave_session_dialog()


func _on_return_to_menu_requested() -> void:
	var state: Dictionary = _session.call(&"get_public_state_snapshot")
	if str(state.get("state", "disconnected")) == "disconnected":
		_return_to_start_menu()
		return
	_pending_navigation = "menu"
	_leave_session_dialog.dialog_text = "确定离开联机会话并返回主菜单吗？"
	_popup_leave_session_dialog()


func _on_match_return_requested() -> void:
	_pending_navigation = "lobby"
	_leave_session_dialog.dialog_text = "确定退出当前战局吗？退出后本局不能继续或直接重赛。"
	_popup_leave_session_dialog()


func _on_leave_session_confirmed() -> void:
	var destination := _pending_navigation
	_pending_navigation = ""
	_cleanup_session()
	if destination == "menu":
		_return_to_start_menu()
	else:
		_show_lobby()


func _on_public_state_changed(public_state: Dictionary) -> void:
	_lobby.call(&"render_connection_snapshot", public_state)
	var state := str(public_state.get("state", "disconnected"))
	var public_role := str(public_state.get("role", ""))
	if not public_role.is_empty():
		_failure_role = public_role
	if state in TRANSPORT_FAILURE_STATES:
		_handle_transport_failure(state, str(public_state.get("error_code", state)))
		return
	_handled_failure_state = ""
	if bool(public_state.get("match_started", false)):
		_enter_match()
	elif state == "disconnected" and _match_active:
		_cleanup_match_presentation()
		_show_lobby()


func _on_player_view_updated(player_view: Dictionary) -> void:
	if not bool(player_view.get("terminal", false)):
		return
	_match_screen.call(&"show_session_terminal", player_view)


func _on_terminal_exit_requested(destination: String) -> void:
	if destination != TERMINAL_LOBBY_DESTINATION:
		return
	_cleanup_session()
	_show_lobby()


func _on_connection_error_acknowledged() -> void:
	var prefer_address := _failure_role == "client"
	_cleanup_session()
	_show_lobby()
	_lobby.call(&"focus_connection_recovery", prefer_address)
	_failure_role = ""


func _enter_match() -> void:
	if _match_active:
		return
	var client_port: RefCounted = _session.call(&"create_client_port")
	if client_port == null or not bool(_application_host.call(&"bind_client_port", client_port)):
		_fatal_error_dialog.dialog_text = "正式联机端口绑定失败，无法进入战局。"
		_fatal_error_dialog.popup_centered()
		return
	_match_active = true
	_lobby.visible = false
	_match_screen.visible = true
	_match_screen.call(&"reset_for_session_end")
	_match_screen.call(&"set_session_navigation_enabled", true)
	client_port.call(&"publish_current")


func _handle_transport_failure(state: String, error_code: String) -> void:
	if _handled_failure_state == state and _connection_error_dialog.visible:
		return
	_handled_failure_state = state
	_cleanup_match_presentation()
	_connection_error_dialog.dialog_text = ERROR_TEXT.get(
		error_code,
		ERROR_TEXT.get(state, "联机连接已经中断。")
	)
	_connection_error_dialog.popup_centered()


func _handle_operation_result(result: Dictionary, fallback: String) -> void:
	if bool(result.get("ok", false)):
		return
	var error_code := str(result.get("error_code", ""))
	_lobby.call(&"show_visible_error", ERROR_TEXT.get(error_code, "%s：%s" % [fallback, error_code]))


func _popup_leave_session_dialog() -> void:
	_leave_session_dialog.popup_centered()
	_leave_session_dialog.get_cancel_button().call_deferred(&"grab_focus")


func _cleanup_session() -> void:
	_cleanup_match_presentation()
	_session.call(&"disconnect_from_game")
	_handled_failure_state = ""


func _cleanup_match_presentation() -> void:
	if _application_host.call(&"is_client_port_bound"):
		_application_host.call(&"unbind_client_port")
	_match_screen.call(&"reset_for_session_end")
	_match_active = false


func _show_lobby() -> void:
	_match_screen.visible = false
	_lobby.visible = true
	_lobby.call(&"render_connection_snapshot", _session.call(&"get_public_state_snapshot"))


func _return_to_start_menu() -> void:
	var scene_path := FrontendRoutes.request_start_menu_ready()
	var change_error := FrontendRoutes.navigate(
		get_tree(),
		scene_path,
		"正在返回烽火关城…"
	)
	if change_error != OK:
		_fatal_error_dialog.dialog_text = "无法返回正式主菜单：%s" % scene_path
		_fatal_error_dialog.popup_centered()
