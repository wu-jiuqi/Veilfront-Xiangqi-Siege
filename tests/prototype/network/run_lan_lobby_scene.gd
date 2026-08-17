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
	_check(lobby.has_node("CenterPanel/PanelMargin/Content/JoinRow/AddressInput"), "预置 IP 输入框存在")
	_check(lobby.has_node("CenterPanel/PanelMargin/Content/PortRow/PortInput"), "预置端口输入存在")
	_check(lobby.has_node("CenterPanel/PanelMargin/Content/ActionRow/HostButton"), "预置创建按钮存在")
	_check(lobby.has_node("CenterPanel/PanelMargin/Content/ActionRow/JoinButton"), "预置加入按钮存在")
	_check(lobby.has_node("NetworkBoard"), "大厅预置共享棋盘 UI 实例")
	var network_board: Control = lobby.get_node("NetworkBoard") as Control
	_check(network_board != null and bool(network_board.get("network_mode")), "共享棋盘 UI 已启用 LAN 驱动模式")
	_check(network_board != null and network_board.get("network_session_path") == NodePath("../LanNetworkSession"),
			"共享棋盘 UI 指向预置网络会话节点")
	var network_session: Node = lobby.get_node("LanNetworkSession")
	_check(int(network_session.default_port) == 27771, "预置默认端口为 27771")
	_check(str(network_session.get_connection_snapshot().get("state", "")) == "disconnected", "大厅初始状态未连接")
	var host_button: Button = lobby.get_node("CenterPanel/PanelMargin/Content/ActionRow/HostButton") as Button
	_check(host_button.has_focus(), "大厅打开后创建按钮取得键盘焦点")
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
