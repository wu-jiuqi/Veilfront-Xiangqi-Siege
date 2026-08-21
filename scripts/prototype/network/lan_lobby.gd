extends Control

const MAIN_MENU_SCENE: String = "res://scenes/game/frontend/main_menu.tscn"
const FALLBACK_ADDRESS: String = "192.168.1.20"

const STATUS_TEXT: Dictionary[String, String] = {
	"disconnected": "等待创建或加入房间",
	"hosting": "房间已创建，正在等待同袍加入",
	"hosting_peer_connected": "已发现加入者，正在分配玄方席位",
	"hosting_connected": "双方已就绪，即将进入战局",
	"connecting": "正在连接房主…",
	"connected_transport": "已连接，正在验证房间…",
	"connected": "已加入房间，双方已就绪",
	"connection_error": "创建或连接失败，请检查端口",
	"connection_failed": "无法连接房主，请检查地址",
	"join_rejected": "房间拒绝加入",
	"server_disconnected": "房主已离开",
	"protocol_error": "联机协议异常",
}

const HEADER_TEXT: Dictionary[String, String] = {
	"disconnected": "等待联机",
	"hosting": "房间开放",
	"hosting_peer_connected": "正在编队",
	"hosting_connected": "连接稳定",
	"connecting": "连接中",
	"connected_transport": "验证中",
	"connected": "连接稳定",
	"connection_error": "连接异常",
	"connection_failed": "连接失败",
	"join_rejected": "加入失败",
	"server_disconnected": "连接中断",
	"protocol_error": "协议异常",
}

const STATE_COLOR_OK: Color = Color(0.30, 0.78, 0.34, 1.0)
const STATE_COLOR_IDLE: Color = Color(0.55, 0.52, 0.43, 1.0)
const STATE_COLOR_BUSY: Color = Color(0.88, 0.66, 0.24, 1.0)
const STATE_COLOR_ERROR: Color = Color(0.86, 0.28, 0.2, 1.0)

@onready var network_session: Node = $LanNetworkSession
@onready var address_input: LineEdit = %AddressInput
@onready var port_input: SpinBox = %PortInput
@onready var address_preview: Label = %AddressPreview
@onready var copy_address_button: BaseButton = %CopyAddressButton
@onready var host_button: BaseButton = %HostButton
@onready var join_button: BaseButton = %JoinButton
@onready var disconnect_button: BaseButton = %DisconnectButton
@onready var status_value: Label = %StatusValue
@onready var seat_value: Label = %SeatValue
@onready var room_code_value: Label = %RoomCodeValue
@onready var connection_status: Label = %ConnectionStatus
@onready var connection_bars: TextureRect = %ConnectionBars
@onready var red_ready_state: Label = %RedReadyState
@onready var black_player_name: Label = %BlackPlayerName
@onready var black_ready_state: Label = %BlackReadyState
@onready var lobby_chrome: Control = %LobbyChrome
@onready var network_board: Control = $NetworkBoard
@onready var back_to_lobby_button: Button = %BackToLobbyButton
@onready var return_to_main_menu_button: BaseButton = %ReturnToMainMenuButton


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	copy_address_button.pressed.connect(_on_copy_address_pressed)
	back_to_lobby_button.pressed.connect(_on_disconnect_pressed)
	return_to_main_menu_button.pressed.connect(_on_return_to_main_menu_pressed)
	address_input.text_changed.connect(_on_address_changed)
	port_input.value_changed.connect(_on_port_changed)
	network_session.connection_state_changed.connect(_on_connection_state_changed)
	network_session.seat_assigned.connect(_on_seat_assigned)
	network_session.player_view_received.connect(_on_player_view_received)
	port_input.value = float(network_session.default_port)
	address_input.text = "%s:%d" % [_preferred_lan_address(), int(port_input.value)]
	_refresh_endpoint_display()
	_apply_connection_visuals("disconnected")
	host_button.grab_focus()


func get_network_session() -> Node:
	return network_session


func _on_host_pressed() -> void:
	_sync_port_from_address()
	var private_rng := RandomNumberGenerator.new()
	private_rng.randomize()
	var private_match_seed: int = int(private_rng.randi())
	var result: Dictionary = network_session.host_game(private_match_seed, int(port_input.value))
	if not bool(result.get("ok", false)):
		status_value.text = "创建失败：%s" % str(result.get("error", "unknown"))


func _on_join_pressed() -> void:
	var endpoint := _read_endpoint()
	var result: Dictionary = network_session.join_game(
		str(endpoint["address"]),
		int(endpoint["port"]),
	)
	if not bool(result.get("ok", false)):
		status_value.text = "加入失败：%s" % str(result.get("error", "unknown"))


func _on_disconnect_pressed() -> void:
	network_session.disconnect_from_game()
	_show_lobby()


func _on_copy_address_pressed() -> void:
	DisplayServer.clipboard_set(address_input.text.strip_edges())
	status_value.text = "房间地址已复制，可发送给同一局域网内的玩家"
	copy_address_button.grab_focus()


func _on_return_to_main_menu_pressed() -> void:
	network_session.disconnect_from_game()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_address_changed(_next_text: String) -> void:
	_sync_port_from_address()
	_refresh_endpoint_display()


func _on_port_changed(_next_value: float) -> void:
	_refresh_endpoint_display()


func _refresh_endpoint_display() -> void:
	address_preview.text = address_input.text.strip_edges()
	room_code_value.text = _room_code_for_port(int(port_input.value))


func _sync_port_from_address() -> void:
	var endpoint := _read_endpoint()
	port_input.value = float(endpoint["port"])


func _read_endpoint() -> Dictionary:
	var raw_address := address_input.text.strip_edges()
	var result := {
		"address": raw_address,
		"port": int(port_input.value),
	}
	var separator_index := raw_address.rfind(":")
	if separator_index <= 0:
		return result
	var port_text := raw_address.substr(separator_index + 1)
	if not port_text.is_valid_int():
		return result
	result["address"] = raw_address.substr(0, separator_index)
	result["port"] = clampi(int(port_text), 1024, 65535)
	return result


func _preferred_lan_address() -> String:
	for candidate: String in IP.get_local_addresses():
		if candidate.contains(":") \
			or candidate.begins_with("127.") \
			or candidate.begins_with("169.254.") \
			or candidate == "0.0.0.0":
			continue
		return candidate
	return FALLBACK_ADDRESS


func _room_code_for_port(port: int) -> String:
	return "雾疆-%04d" % (port % 1000)


func _on_connection_state_changed(snapshot: Dictionary) -> void:
	var state := str(snapshot.get("state", "unknown"))
	status_value.text = STATUS_TEXT.get(state, "联机状态：%s" % state)
	_apply_connection_visuals(state)
	var connected: bool = state not in [
		"disconnected",
		"connection_error",
		"connection_failed",
		"join_rejected",
		"server_disconnected",
		"protocol_error",
	]
	disconnect_button.disabled = not connected
	host_button.disabled = connected
	join_button.disabled = connected
	address_input.editable = not connected
	port_input.editable = not connected
	match state:
		"hosting":
			red_ready_state.text = "房主 · 已就绪"
			black_player_name.text = "等待同袍加入…"
		"hosting_peer_connected":
			black_player_name.text = "同袍加入中…"
		"hosting_connected":
			black_player_name.text = "玄方 · 已就绪"
			if not network_session.get_player_view_snapshot().is_empty():
				_show_board()
		"connecting", "connected_transport":
			red_ready_state.text = "赤方房主 · 验证中"
			black_player_name.text = "玄方 · 连接中"
		"connected":
			black_player_name.text = "玄方 · 已就绪"
	if not connected:
		_reset_seat_display()
		_show_lobby()


func _apply_connection_visuals(state: String) -> void:
	connection_status.text = HEADER_TEXT.get(state, "状态未知")
	var state_color := STATE_COLOR_IDLE
	if state in ["hosting", "hosting_peer_connected", "connecting", "connected_transport"]:
		state_color = STATE_COLOR_BUSY
	elif state in ["hosting_connected", "connected"]:
		state_color = STATE_COLOR_OK
	elif state in ["connection_error", "connection_failed", "join_rejected", "server_disconnected", "protocol_error"]:
		state_color = STATE_COLOR_ERROR
	connection_status.add_theme_color_override("font_color", state_color)
	connection_bars.modulate = state_color


func _on_seat_assigned(seat: String) -> void:
	if seat == "red":
		seat_value.text = "赤方（房主）"
		red_ready_state.text = "房主 · 已就绪"
		return
	seat_value.text = "玄方（加入者）"
	red_ready_state.text = "赤方房主 · 已就绪"
	black_player_name.text = "玄方 · 已就绪"
	black_ready_state.text = "加入者 · 已就绪"


func _on_player_view_received(_player_view: Dictionary) -> void:
	if network_session.get_session_role() == "host" \
		and str(network_session.get_connection_snapshot().get("state", "")) != "hosting_connected":
		return
	_show_board()


func _show_board() -> void:
	lobby_chrome.visible = false
	network_board.visible = true
	back_to_lobby_button.visible = true


func _show_lobby() -> void:
	lobby_chrome.visible = true
	network_board.visible = false
	back_to_lobby_button.visible = false


func _reset_seat_display() -> void:
	seat_value.text = "未分配"
	red_ready_state.text = "房主 · 等待创建"
	black_player_name.text = "等待同袍加入…"
	black_ready_state.text = "玄方席位 · 空缺"
