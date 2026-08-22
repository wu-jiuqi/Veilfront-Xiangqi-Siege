class_name FormalLanLobby
extends Control

signal host_requested(port: int)
signal join_requested(address: String, port: int)
signal ready_changed(is_ready: bool)
signal start_requested
signal disconnect_requested
signal return_requested

const FALLBACK_ADDRESS: String = "192.168.1.20"
const DEFAULT_PORT: int = 27771

const STATUS_TEXT: Dictionary[String, String] = {
	"disconnected": "等待创建或加入房间",
	"hosting": "房间已创建，正在等待同袍加入",
	"connecting": "正在连接房主…",
	"connected_transport": "已连接，正在验证房间…",
	"lobby": "双方已入席，请确认准备状态",
	"ready": "双方已准备，等待房主开局",
	"starting": "正在创建正式战局…",
	"match": "正式战局进行中",
	"in_match": "战局进行中",
	"ended": "战局已经结束",
	"connection_error": "创建或连接失败，请检查地址和端口",
	"connection_failed": "无法连接房主，请检查局域网地址",
	"join_rejected": "房间拒绝加入",
	"server_disconnected": "房主已离开，战局已中止",
	"peer_disconnected": "同袍已离开，战局已中止",
	"protocol_error": "联机协议异常，连接已关闭",
}

const HEADER_TEXT: Dictionary[String, String] = {
	"disconnected": "等待联机",
	"hosting": "房间开放",
	"connecting": "连接中",
	"connected_transport": "验证中",
	"lobby": "整备中",
	"ready": "可以开局",
	"starting": "开局中",
	"match": "战局进行中",
	"in_match": "战局进行中",
	"ended": "战局结束",
	"connection_error": "连接异常",
	"connection_failed": "连接失败",
	"join_rejected": "加入失败",
	"server_disconnected": "连接中断",
	"peer_disconnected": "连接中断",
	"protocol_error": "协议异常",
}

const STATE_COLOR_OK := Color(0.30, 0.78, 0.34, 1.0)
const STATE_COLOR_IDLE := Color(0.55, 0.52, 0.43, 1.0)
const STATE_COLOR_BUSY := Color(0.88, 0.66, 0.24, 1.0)
const STATE_COLOR_ERROR := Color(0.86, 0.28, 0.20, 1.0)
const TERMINAL_STATES: Array[String] = [
	"connection_error",
	"connection_failed",
	"join_rejected",
	"server_disconnected",
	"peer_disconnected",
	"protocol_error",
]

@onready var _address_input: LineEdit = %AddressInput
@onready var _port_input: SpinBox = %PortInput
@onready var _copy_address_button: BaseButton = %CopyAddressButton
@onready var _host_button: BaseButton = %HostButton
@onready var _join_button: BaseButton = %JoinButton
@onready var _disconnect_button: BaseButton = %DisconnectButton
@onready var _ready_button: Button = %ReadyButton
@onready var _start_button: Button = %StartButton
@onready var _status_value: Label = %StatusValue
@onready var _seat_value: Label = %SeatValue
@onready var _room_code_value: Label = %RoomCodeValue
@onready var _connection_status: Label = %ConnectionStatus
@onready var _connection_bars: TextureRect = %ConnectionBars
@onready var _red_ready_state: Label = %RedReadyState
@onready var _black_player_name: Label = %BlackPlayerName
@onready var _black_ready_state: Label = %BlackReadyState
@onready var _rules_turn_clock_value: Label = %RulesTurnClockValue
@onready var _return_button: BaseButton = %ReturnToMainMenuButton

var _rendering_snapshot: bool = false
var _latest_snapshot: Dictionary = {}


func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_disconnect_button.pressed.connect(disconnect_requested.emit)
	_copy_address_button.pressed.connect(_on_copy_address_pressed)
	_ready_button.toggled.connect(_on_ready_toggled)
	_start_button.pressed.connect(start_requested.emit)
	_return_button.pressed.connect(return_requested.emit)
	_address_input.text_changed.connect(_on_address_changed)
	_port_input.value_changed.connect(_on_port_changed)
	_port_input.value = DEFAULT_PORT
	_address_input.text = "%s:%d" % [_preferred_lan_address(), DEFAULT_PORT]
	_render_connection_snapshot({"state": "disconnected"})
	_host_button.grab_focus()


func render_connection_snapshot(snapshot: Dictionary) -> void:
	_latest_snapshot = snapshot.duplicate(true)
	_render_connection_snapshot(_latest_snapshot)


func show_visible_error(message: String) -> void:
	if not message.is_empty():
		_status_value.text = message


func get_connection_snapshot() -> Dictionary:
	return _latest_snapshot.duplicate(true)


func focus_connection_recovery(prefer_address: bool) -> void:
	if prefer_address:
		_address_input.grab_focus()
		_address_input.select_all()
	else:
		_host_button.grab_focus()


func _on_host_pressed() -> void:
	var endpoint := _read_endpoint()
	_port_input.value = float(endpoint["port"])
	host_requested.emit(int(endpoint["port"]))


func _on_join_pressed() -> void:
	var endpoint := _read_endpoint()
	join_requested.emit(str(endpoint["address"]), int(endpoint["port"]))


func _on_ready_toggled(pressed: bool) -> void:
	if _rendering_snapshot:
		return
	_ready_button.disabled = true
	ready_changed.emit(pressed)


func _on_copy_address_pressed() -> void:
	DisplayServer.clipboard_set(_address_input.text.strip_edges())
	_status_value.text = "房间地址已复制，可发送给同一局域网内的玩家"
	_copy_address_button.grab_focus()


func _on_address_changed(_next_text: String) -> void:
	var endpoint := _read_endpoint()
	_port_input.value = float(endpoint["port"])
	_refresh_endpoint_display()


func _on_port_changed(_next_value: float) -> void:
	_refresh_endpoint_display()


func _render_connection_snapshot(snapshot: Dictionary) -> void:
	_rendering_snapshot = true
	var ready_was_visible := _ready_button.visible
	var start_was_enabled := _start_button.visible and not _start_button.disabled
	var state := str(snapshot.get("state", "disconnected"))
	var role := str(snapshot.get("role", ""))
	var seat := str(snapshot.get("local_seat", ""))
	var peer_connected := bool(snapshot.get("peer_connected", false))
	var red_ready := bool(snapshot.get("red_ready", false))
	var black_ready := bool(snapshot.get("black_ready", false))
	var connected := state not in TERMINAL_STATES and state != "disconnected"

	_status_value.text = STATUS_TEXT.get(state, "联机状态：%s" % state)
	_connection_status.text = HEADER_TEXT.get(state, "状态未知")
	if state == "lobby":
		if red_ready and black_ready:
			_connection_status.text = "可以开局" if role == "host" else "等待开局"
			_status_value.text = "双方已准备，可以开始战局" if role == "host" \
				else "双方已准备，等待房主开始战局"
		elif red_ready or black_ready:
			_connection_status.text = "等待准备"
			_status_value.text = "一方已准备，等待另一方确认"
	_apply_state_color(state)
	_host_button.visible = not connected
	_join_button.visible = not connected
	_host_button.disabled = connected
	_join_button.disabled = connected
	_disconnect_button.disabled = not connected
	_address_input.editable = not connected
	_port_input.editable = not connected
	_copy_address_button.disabled = role == "client"

	_ready_button.visible = peer_connected and state not in ["starting", "match", "in_match", "ended"]
	_ready_button.disabled = not _ready_button.visible
	_ready_button.button_pressed = red_ready if seat == "red" else black_ready
	_start_button.visible = role == "host" and peer_connected and state not in ["match", "in_match", "ended"]
	_start_button.disabled = not bool(snapshot.get("can_start", red_ready and black_ready))

	_red_ready_state.text = _seat_state_text("赤方", red_ready, role == "host" or peer_connected)
	_black_player_name.text = _seat_state_text("玄方", black_ready, peer_connected)
	_black_ready_state.text = "已准备" if black_ready else "未准备"
	var turn_seconds := int(snapshot.get("turn_timeout_seconds", 0))
	_rules_turn_clock_value.text = "每回合 %d 秒" % turn_seconds \
		if turn_seconds > 0 else "回合计时：以战局配置为准"
	if seat == "red":
		_seat_value.text = "赤方（房主）"
	elif seat == "black":
		_seat_value.text = "玄方（加入者）"
	else:
		_seat_value.text = "未分配"
	_rendering_snapshot = false
	if _start_button.visible and not _start_button.disabled and not start_was_enabled:
		_start_button.grab_focus()
	elif _ready_button.visible and not ready_was_visible:
		_ready_button.grab_focus()
	elif state == "disconnected":
		_host_button.grab_focus()


func _seat_state_text(side_label: String, is_ready: bool, is_present: bool) -> String:
	if not is_present:
		return "%s · 等待入席" % side_label
	return "%s · %s" % [side_label, "已准备" if is_ready else "未准备"]


func _apply_state_color(state: String) -> void:
	var state_color := STATE_COLOR_IDLE
	if state in ["hosting", "connecting", "connected_transport", "starting"]:
		state_color = STATE_COLOR_BUSY
	elif state in ["lobby", "ready", "match", "in_match"]:
		state_color = STATE_COLOR_OK
	elif state in TERMINAL_STATES:
		state_color = STATE_COLOR_ERROR
	_connection_status.add_theme_color_override("font_color", state_color)
	_connection_bars.modulate = state_color


func _refresh_endpoint_display() -> void:
	_room_code_value.text = "雾疆-%04d" % (int(_port_input.value) % 10000)


func _read_endpoint() -> Dictionary:
	var raw_address := _address_input.text.strip_edges()
	var result := {"address": raw_address, "port": int(_port_input.value)}
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
