extends Control

const MAIN_MENU_SCENE: String = "res://scenes/game/frontend/main_menu.tscn"

const STATUS_TEXT: Dictionary[String, String] = {
	"disconnected": "●  等待创建或加入房间",
	"hosting": "●  房间已创建，等待同袍加入",
	"hosting_peer_connected": "●  已发现加入者，正在分配席位",
	"hosting_connected": "●  双方已连接",
	"connecting": "●  正在连接房主",
	"connected_transport": "●  已连接，正在验证房间",
	"connected": "●  已加入房间",
	"connection_error": "●  创建或连接失败",
	"connection_failed": "●  无法连接房主",
	"join_rejected": "●  房间拒绝加入",
	"server_disconnected": "●  房主已离开",
	"protocol_error": "●  联机协议异常",
}

@onready var network_session: Node = $LanNetworkSession
@onready var address_input: LineEdit = %AddressInput
@onready var port_input: SpinBox = %PortInput
@onready var address_preview: Label = %AddressPreview
@onready var copy_address_button: Button = %CopyAddressButton
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var disconnect_button: Button = %DisconnectButton
@onready var status_value: Label = %StatusValue
@onready var seat_value: Label = %SeatValue
@onready var red_ready_state: Label = %RedReadyState
@onready var black_player_name: Label = %BlackPlayerName
@onready var black_ready_state: Label = %BlackReadyState
@onready var lobby_chrome: Control = %LobbyChrome
@onready var network_board: Control = $NetworkBoard
@onready var back_to_lobby_button: Button = %BackToLobbyButton
@onready var return_to_main_menu_button: Button = %ReturnToMainMenuButton


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
	_refresh_address_preview()
	host_button.grab_focus()


func get_network_session() -> Node:
	return network_session


func _on_host_pressed() -> void:
	var private_rng := RandomNumberGenerator.new()
	private_rng.randomize()
	var private_match_seed: int = int(private_rng.randi())
	var result: Dictionary = network_session.host_game(private_match_seed, int(port_input.value))
	if not bool(result.get("ok", false)):
		status_value.text = "●  创建失败：%s" % str(result.get("error", "unknown"))


func _on_join_pressed() -> void:
	var result: Dictionary = network_session.join_game(address_input.text, int(port_input.value))
	if not bool(result.get("ok", false)):
		status_value.text = "●  加入失败：%s" % str(result.get("error", "unknown"))


func _on_disconnect_pressed() -> void:
	network_session.disconnect_from_game()
	_show_lobby()


func _on_copy_address_pressed() -> void:
	DisplayServer.clipboard_set(address_preview.text)
	copy_address_button.text = "已复制房间地址"
	copy_address_button.grab_focus()


func _on_return_to_main_menu_pressed() -> void:
	network_session.disconnect_from_game()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_address_changed(_next_text: String) -> void:
	copy_address_button.text = "复制房间地址"
	_refresh_address_preview()


func _on_port_changed(_next_value: float) -> void:
	copy_address_button.text = "复制房间地址"
	_refresh_address_preview()


func _refresh_address_preview() -> void:
	address_preview.text = "%s:%d" % [address_input.text.strip_edges(), int(port_input.value)]


func _on_connection_state_changed(snapshot: Dictionary) -> void:
	var state := str(snapshot.get("state", "unknown"))
	status_value.text = STATUS_TEXT.get(state, "●  联机状态：%s" % state)
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
	if state.begins_with("hosting"):
		red_ready_state.text = "房主 · 已开房"
	elif state == "connecting" or state == "connected_transport":
		black_player_name.text = "正在加入房间…"
		black_ready_state.text = "玄方席位 · 连接中"
	if not connected:
		_reset_seat_display()
		_show_lobby()


func _on_seat_assigned(seat: String) -> void:
	if seat == "red":
		seat_value.text = "赤方（房主）"
		red_ready_state.text = "房主 · 已就绪"
		return
	seat_value.text = "玄方（加入者）"
	black_player_name.text = "玄方来客"
	black_ready_state.text = "加入者 · 已就绪"


func _on_player_view_received(_player_view: Dictionary) -> void:
	lobby_chrome.visible = false
	network_board.visible = true
	back_to_lobby_button.visible = true


func _show_lobby() -> void:
	lobby_chrome.visible = true
	network_board.visible = false
	back_to_lobby_button.visible = false


func _reset_seat_display() -> void:
	seat_value.text = "未分配"
	red_ready_state.text = "房主 · 等待开房"
	black_player_name.text = "等待同袍加入…"
	black_ready_state.text = "玄方席位 · 空缺"
