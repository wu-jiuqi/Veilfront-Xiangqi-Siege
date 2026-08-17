extends SceneTree

const NETWORK_SCENE_PATH: String = "res://scenes/prototype/network/lan_network_session.tscn"
const TEST_PORT: int = 28771

var failures: Array[String] = []
var server_root: Node
var client_root: Node
var server_session: Node
var client_session: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load(NETWORK_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "联网会话预置场景可加载")
	if packed_scene == null:
		_finish()
		return

	server_root = Node.new()
	server_root.name = "ServerRoot"
	client_root = Node.new()
	client_root.name = "ClientRoot"
	root.add_child(server_root)
	root.add_child(client_root)
	set_multiplayer(MultiplayerAPI.create_default_interface(), server_root.get_path())
	set_multiplayer(MultiplayerAPI.create_default_interface(), client_root.get_path())
	server_session = packed_scene.instantiate()
	client_session = packed_scene.instantiate()
	server_root.add_child(server_session)
	client_root.add_child(client_session)

	var hosted: Dictionary = server_session.host_game(471001, TEST_PORT, 50)
	_check(bool(hosted.get("ok", false)), "ENet 房主创建成功")
	if not bool(hosted.get("ok", false)):
		_finish()
		return
	var joined: Dictionary = client_session.join_game("127.0.0.1", TEST_PORT)
	_check(bool(joined.get("ok", false)), "ENet 客户端启动连接")
	if not bool(joined.get("ok", false)):
		_finish()
		return

	var connected: bool = await _wait_until(func() -> bool:
		return not client_session.get_player_view_snapshot().is_empty()
	, 360)
	_check(connected, "两套 MultiplayerAPI 通过 loopback 完成席位与首个 PlayerView 下发")
	if not connected:
		_finish()
		return

	var server_view: Dictionary = server_session.get_player_view_snapshot()
	var client_view: Dictionary = client_session.get_player_view_snapshot()
	_check(str(server_view.get("viewer_side", "")) == "red", "房主实例仅持有红方 PlayerView")
	_check(str(client_view.get("viewer_side", "")) == "black", "客户端实例仅持有黑方 PlayerView")
	_check(not server_view.has("board") and not server_view.has("rng"), "房主 UI 快照不含 FullState/RNG")
	_check(not client_view.has("board") and not client_view.has("rng"), "客户端 UI 快照不含 FullState/RNG")

	server_session.submit_intent(_pass_intent())
	var red_completed: bool = await _wait_until(func() -> bool:
		return int(client_session.get_player_view_snapshot().get("action_index", -1)) == 1
	, 360)
	_check(red_completed, "红方行动通过可靠 RPC 推进并下发黑方 PlayerView")
	if red_completed:
		client_session.submit_intent(_pass_intent())
		var black_completed: bool = await _wait_until(func() -> bool:
			return int(server_session.get_player_view_snapshot().get("action_index", -1)) == 2 \
			and int(client_session.get_player_view_snapshot().get("action_index", -1)) == 2
		, 360)
		_check(black_completed, "黑方行动通过可靠 RPC 后双方推进到同一 action index")

	_finish()


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in maximum_frames:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _pass_intent() -> Dictionary:
	return {
		"piece_id": "",
		"action_type": "pass",
		"target_cell": [],
		"skill_type": "",
	}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if is_instance_valid(server_session):
		server_session.disconnect_from_game()
	if is_instance_valid(client_session):
		client_session.disconnect_from_game()
	if is_instance_valid(server_root):
		set_multiplayer(null, server_root.get_path())
		server_root.queue_free()
	if is_instance_valid(client_root):
		set_multiplayer(null, client_root.get_path())
		client_root.queue_free()
	if failures.is_empty():
		print("LAN_NETWORK_INTEGRATION_PASSED")
		quit(0)
		return
	print("LAN_NETWORK_INTEGRATION_FAILED count=%d" % failures.size())
	quit(1)
