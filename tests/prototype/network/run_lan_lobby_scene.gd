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
	_check(not lobby.has_node("LobbyChrome/FullPlate"), "大厅不再依赖整屏 PNG 底板")
	_check(lobby.has_node("LobbyChrome/HeaderFrame"), "顶部栏为独立 PNG 切片")
	_check(lobby.has_node("LobbyChrome/RoomInfoPanel"), "房间信息为独立 PNG 切片")
	_check(lobby.has_node("LobbyChrome/VersusPanel"), "阵营展示为独立 PNG 切片")
	_check(lobby.has_node("LobbyChrome/RulesPanel"), "战局规则为独立 PNG 切片")
	_check(lobby.has_node("LobbyChrome/StatusPanel"), "状态栏为独立 PNG 切片")
	_check(lobby.has_node("LobbyChrome/ActionGroup"), "操作栏为独立 PNG 切片")
	var versus_panel := lobby.get_node("LobbyChrome/VersusPanel") as TextureRect
	_check(
		versus_panel.texture != null
		and versus_panel.texture.resource_path == "res://assets/art/ui/lan_lobby/slices_v3/versus_panel.png",
		"阵营模块引用批准母版生成的切片",
	)
	_check(lobby.has_node("LobbyChrome/AddressInput"), "预置 IP 与端口输入框存在")
	_check(lobby.has_node("LobbyChrome/PortInput"), "预置隐藏端口输入存在")
	_check(lobby.has_node("LobbyChrome/CopyAddressButton"), "预置复制地址贴图按钮存在")
	_check(lobby.has_node("LobbyChrome/HostButton"), "预置创建房间贴图按钮存在")
	_check(lobby.has_node("LobbyChrome/JoinButton"), "预置加入房间贴图按钮存在")
	_check(lobby.has_node("LobbyChrome/DisconnectButton"), "预置离开房间贴图按钮存在")
	_check(lobby.has_node("NetworkBoard"), "大厅预置共享棋盘 UI 实例")
	var network_board: Control = lobby.get_node("NetworkBoard") as Control
	_check(network_board != null and bool(network_board.get("network_mode")), "共享棋盘 UI 已启用 LAN 驱动模式")
	_check(network_board != null and network_board.get("network_session_path") == NodePath("../LanNetworkSession"),
			"共享棋盘 UI 指向预置网络会话节点")
	var network_session: Node = lobby.get_node("LanNetworkSession")
	_check(int(network_session.default_port) == 27771, "预置默认端口为 27771")
	_check(str(network_session.get_connection_snapshot().get("state", "")) == "disconnected", "大厅初始状态未连接")
	var host_button: BaseButton = lobby.get_node("LobbyChrome/HostButton") as BaseButton
	_check(host_button.has_focus(), "大厅打开后创建按钮取得键盘焦点")
	var address_input := lobby.get_node("LobbyChrome/AddressInput") as LineEdit
	var address_preview := lobby.get_node("LobbyChrome/AddressPreview") as Label
	_check(address_input.text.ends_with(":27771"), "默认显示本机局域网地址与联机端口")
	_check(address_preview.text == address_input.text, "复制地址与可见输入保持同步")
	var room_code := lobby.get_node("LobbyChrome/RoomCodeValue") as Label
	_check(room_code.text == "雾疆-0771", "房间代号由当前端口稳定生成")
	address_input.text = "10.0.0.8:28888"
	address_input.text_changed.emit(address_input.text)
	await process_frame
	var port_input := lobby.get_node("LobbyChrome/PortInput") as SpinBox
	_check(int(port_input.value) == 28888, "地址输入可同步提取联机端口")
	_check(address_preview.text == "10.0.0.8:28888", "编辑后的地址继续同步到复制值")
	_check(room_code.text == "雾疆-0888", "修改端口后房间代号同步更新")
	var copy_button := lobby.get_node("LobbyChrome/CopyAddressButton") as TextureButton
	_check(copy_button.texture_normal != null and copy_button.texture_hover != null,
			"复制按钮具有正常与悬停 PNG 状态")
	var disconnect_button := lobby.get_node("LobbyChrome/DisconnectButton") as TextureButton
	_check(disconnect_button.texture_disabled != null and disconnect_button.disabled,
			"离开按钮具有独立禁用贴图且初始不可用")
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
