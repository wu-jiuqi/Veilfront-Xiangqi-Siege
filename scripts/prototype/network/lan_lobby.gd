extends Control

@onready var network_session: Node = $LanNetworkSession
@onready var address_input: LineEdit = $CenterPanel/PanelMargin/Content/JoinRow/AddressInput
@onready var port_input: SpinBox = $CenterPanel/PanelMargin/Content/PortRow/PortInput
@onready var host_button: Button = $CenterPanel/PanelMargin/Content/ActionRow/HostButton
@onready var join_button: Button = $CenterPanel/PanelMargin/Content/ActionRow/JoinButton
@onready var disconnect_button: Button = $CenterPanel/PanelMargin/Content/ActionRow/DisconnectButton
@onready var status_value: Label = $CenterPanel/PanelMargin/Content/StatusGrid/StatusValue
@onready var seat_value: Label = $CenterPanel/PanelMargin/Content/StatusGrid/SeatValue
@onready var background: ColorRect = $Background
@onready var center_panel: PanelContainer = $CenterPanel
@onready var network_board: Control = $NetworkBoard
@onready var back_to_lobby_button: Button = $BackToLobbyButton
@onready var return_to_main_menu_button: Button = $ReturnToMainMenuButton


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	back_to_lobby_button.pressed.connect(_on_disconnect_pressed)
	return_to_main_menu_button.pressed.connect(_on_return_to_main_menu_pressed)
	network_session.connection_state_changed.connect(_on_connection_state_changed)
	network_session.seat_assigned.connect(_on_seat_assigned)
	network_session.player_view_received.connect(_on_player_view_received)
	port_input.value = float(network_session.default_port)
	host_button.grab_focus()


func get_network_session() -> Node:
	return network_session


func _on_host_pressed() -> void:
	var private_rng := RandomNumberGenerator.new()
	private_rng.randomize()
	var private_match_seed: int = int(private_rng.randi())
	var result: Dictionary = network_session.host_game(private_match_seed, int(port_input.value))
	if not bool(result.get("ok", false)):
		status_value.text = "创建失败：%s" % str(result.get("error", "unknown"))


func _on_join_pressed() -> void:
	var result: Dictionary = network_session.join_game(address_input.text, int(port_input.value))
	if not bool(result.get("ok", false)):
		status_value.text = "加入失败：%s" % str(result.get("error", "unknown"))


func _on_disconnect_pressed() -> void:
	network_session.disconnect_from_game()
	_show_lobby()


func _on_return_to_main_menu_pressed() -> void:
	network_session.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/game/frontend/main_menu.tscn")


func _on_connection_state_changed(snapshot: Dictionary) -> void:
	status_value.text = str(snapshot.get("state", "unknown"))
	var connected: bool = str(snapshot.get("state", "")) not in [
		"disconnected", "connection_error", "connection_failed", "join_rejected", "server_disconnected",
	]
	disconnect_button.disabled = not connected
	host_button.disabled = connected
	join_button.disabled = connected
	if not connected:
		_show_lobby()


func _on_seat_assigned(seat: String) -> void:
	seat_value.text = "红方（房主）" if seat == "red" else "黑方（加入者）"


func _on_player_view_received(_player_view: Dictionary) -> void:
	background.visible = false
	center_panel.visible = false
	network_board.visible = true
	back_to_lobby_button.visible = true


func _show_lobby() -> void:
	background.visible = true
	center_panel.visible = true
	network_board.visible = false
	back_to_lobby_button.visible = false
