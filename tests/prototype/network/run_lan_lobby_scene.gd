extends SceneTree

const LOBBY_SCENE_PATH: String = "res://scenes/prototype/network/lan_lobby.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load(LOBBY_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "局域网大厅可作为 PackedScene 加载")
	if packed_scene == null:
		_finish()
		return
	var lobby: Control = packed_scene.instantiate() as Control
	root.add_child(lobby)
	await process_frame
	_check(lobby.has_node("LanNetworkSession"), "预置 LanNetworkSession 节点存在")
	_check(lobby.has_node("LobbyChrome/FullPlate"), "预置高保真 PNG 底板存在")
	var full_plate := lobby.get_node("LobbyChrome/FullPlate") as TextureRect
	_check(
		full_plate.texture != null
		and full_plate.texture.resource_path == "res://assets/art/ui/lan_lobby/lan_lobby_full_plate_v2.png",
		"大厅使用项目所有者指定的高保真参考图",
	)
	_check(lobby.has_node("LobbyChrome/InteractionLayer/AddressInput"), "预置 IP 与端口输入框存在")
	_check(lobby.has_node("LobbyChrome/InteractionLayer/PortInput"), "预置隐藏端口输入存在")
	_check(lobby.has_node("LobbyChrome/InteractionLayer/CopyAddressButton"), "预置复制地址热区存在")
	_check(lobby.has_node("LobbyChrome/InteractionLayer/HostButton"), "预置创建按钮热区存在")
	_check(lobby.has_node("LobbyChrome/InteractionLayer/JoinButton"), "预置加入按钮热区存在")
	_check(lobby.has_node("LobbyChrome/InteractionLayer/DisconnectButton"), "预置离开按钮热区存在")
	_check(lobby.has_node("NetworkBoard"), "大厅预置共享棋盘 UI 实例")
	var network_board: Control = lobby.get_node("NetworkBoard") as Control
	_check(network_board != null and bool(network_board.get("network_mode")), "共享棋盘 UI 已启用 LAN 驱动模式")
	_check(network_board != null and network_board.get("network_session_path") == NodePath("../LanNetworkSession"),
			"共享棋盘 UI 指向预置网络会话节点")
	var network_session: Node = lobby.get_node("LanNetworkSession")
	_check(int(network_session.default_port) == 27771, "预置默认端口为 27771")
	_check(str(network_session.get_connection_snapshot().get("state", "")) == "disconnected", "大厅初始状态未连接")
	var host_button: Button = lobby.get_node("LobbyChrome/InteractionLayer/HostButton") as Button
	_check(host_button.has_focus(), "大厅打开后创建按钮取得键盘焦点")
	var address_input := lobby.get_node("LobbyChrome/InteractionLayer/AddressInput") as LineEdit
	var address_preview := lobby.get_node("LobbyChrome/InteractionLayer/AddressPreview") as Label
	_check(address_input.text == "192.168.1.20:27771", "房主地址与目标参考图一致")
	_check(address_preview.text == address_input.text, "复制地址与可见输入保持同步")
	address_input.text = "10.0.0.8:28888"
	address_input.text_changed.emit(address_input.text)
	await process_frame
	var port_input := lobby.get_node("LobbyChrome/InteractionLayer/PortInput") as SpinBox
	_check(int(port_input.value) == 28888, "地址输入可同步提取联机端口")
	_check(address_preview.text == "10.0.0.8:28888", "编辑后的地址继续同步到复制值")
	var lobby_source: String = FileAccess.get_file_as_string("res://scripts/prototype/network/lan_lobby.gd")
	_check(not lobby_source.contains("FullState") and not lobby_source.contains("RuleEngine"), "Lobby 脚本没有规则核心或 FullState 旁路")
	lobby.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("LAN_LOBBY_SCENE_TEST_PASSED")
		quit(0)
		return
	print("LAN_LOBBY_SCENE_TEST_FAILED count=%d" % failures.size())
	quit(1)
