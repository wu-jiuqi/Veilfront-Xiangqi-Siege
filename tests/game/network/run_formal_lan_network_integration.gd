extends SceneTree

const NETWORK_SCENE_PATH: String = \
	"res://scenes/game/network/formal_lan_session.tscn"
const TEST_PORT: int = 29772
const ApplicationHostScript = preload(
	"res://scripts/game/application/application_host.gd"
)
const FormalLanProtocol = preload(
	"res://scripts/game/contracts/formal_lan_protocol.gd"
)

var _failures: Array[String] = []
var _server_root: Node
var _client_root: Node
var _server_session: Node
var _client_session: Node
var _server_host: Node
var _client_host: Node
var _server_state: Dictionary = {}
var _client_state: Dictionary = {}
var _server_views: Array[Dictionary] = []
var _client_views: Array[Dictionary] = []
var _server_previews: Array = []
var _client_previews: Array = []
var _server_feedback: Array[Dictionary] = []
var _client_feedback: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load(NETWORK_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "正式 LAN 预置场景可加载")
	if packed_scene == null:
		_finish()
		return
	_setup_two_multiplayer_roots(packed_scene)

	var server_port: RefCounted = _server_session.create_client_port()
	var client_port: RefCounted = _client_session.create_client_port()
	_check(server_port == _server_session.create_client_port(), "房主重复获取同一 ClientPort")
	_check(client_port == _client_session.create_client_port(), "客户端重复获取同一 ClientPort")
	_check(_server_host.bind_client_port(server_port), "房主 ClientPort 可绑定 ApplicationHost")
	_check(_client_host.bind_client_port(client_port), "客户端 ClientPort 可绑定 ApplicationHost")
	_connect_observers()

	var hosted: Dictionary = _server_session.host_game(471221, TEST_PORT, {
		"full_round_limit_hypothesis": 50,
	})
	_check(bool(hosted.get("ok", false)), "房主创建正式 ENet 会话")
	var joined: Dictionary = _client_session.join_game("127.0.0.1", TEST_PORT)
	_check(bool(joined.get("ok", false)), "客户端发起正式 ENet 连接")
	if not bool(hosted.get("ok", false)) or not bool(joined.get("ok", false)):
		_finish()
		return

	var seated: bool = await _wait_until(func() -> bool:
		return str(_server_state.get("local_seat", "")) == "red" \
			and str(_client_state.get("local_seat", "")) == "black" \
			and bool(_server_state.get("peer_connected", false)) \
			and bool(_client_state.get("peer_connected", false))
	, 360)
	_check(seated, "loopback 完成 host/join 与红黑席位分配")
	if not seated:
		_finish()
		return

	_server_session.set_ready(true)
	_client_session.set_ready(true)
	var both_ready: bool = await _wait_until(func() -> bool:
		return bool(_server_state.get("red_ready", false)) \
			and bool(_server_state.get("black_ready", false)) \
			and bool(_server_state.get("can_start", false)) \
			and bool(_client_state.get("red_ready", false)) \
			and bool(_client_state.get("black_ready", false))
	, 360)
	_check(both_ready, "双方 ready 同步且仅房主满足开局条件")
	if not both_ready:
		_finish()
		return

	var started: Dictionary = _server_session.start_match()
	_check(bool(started.get("ok", false)), "房主启动正式权威对局")
	var initial_batches: bool = await _wait_until(func() -> bool:
		return not _server_views.is_empty() and not _client_views.is_empty() \
			and bool(_server_state.get("match_started", false)) \
			and bool(_client_state.get("match_started", false))
	, 360)
	_check(initial_batches, "开局向红黑分别下发首个正式观察者批次")
	if not initial_batches:
		_finish()
		return

	_check(_server_session.has_authoritative_application(), "正式规则核心只存在于 host")
	_check(not _client_session.has_authoritative_application(), "客户端不持有正式规则核心")
	_check(_all_views_belong_to(_server_views, "red"), "房主端只收到红方 PlayerView")
	_check(_all_views_belong_to(_client_views, "black"), "客户端只收到黑方 PlayerView")
	_check(_all_views_are_observer_safe(_server_views), "房主下行无 seed/RNG/FullState")
	_check(_all_views_are_observer_safe(_client_views), "客户端下行无 seed/RNG/FullState")
	_check(_protocol_bytes_are_deterministic(), "相同观察者输入生成字节等价下行批次")
	_check(_protocol_rejects_extra_fields(), "正式 LAN 协议拒绝额外与隐藏字段")
	_check(_all_action_types_are_whitelisted(), "正式动作合同覆盖移动/炮击/献祭/跳过/超时")

	var red_preview: Dictionary = _first_legal_move(_server_previews)
	_check(not red_preview.is_empty(), "红方获得正式移动预览")
	if red_preview.is_empty():
		_finish()
		return
	_server_host.prepare_action(str(red_preview.get("preview_id", "")))
	_server_host.confirm_prepared_action(str(red_preview.get("preview_id", "")))
	var red_completed: bool = await _wait_until(func() -> bool:
		return int(_server_state.get("action_index", -1)) == 1 \
			and int(_client_state.get("action_index", -1)) == 1 \
			and str(_client_state.get("active_side", "")) == "black"
	, 360)
	_check(red_completed, "红方正式移动经可靠 RPC 结算并切换黑方回合")
	if not red_completed:
		_finish()
		return

	var original_request_id: String = str(
		_server_feedback.back().get("request_id", "") if not _server_feedback.is_empty() else ""
	)
	var duplicate_request: Dictionary = FormalLanProtocol.encode_action_request(
		original_request_id, 0, red_preview
	)
	if bool(duplicate_request.get("ok", false)):
		_server_session._process_action_request(
			1, str(duplicate_request.get("bytes", ""))
		)
	_check(not _server_feedback.is_empty() \
		and str(_server_feedback.back().get("error_code", "")) == "duplicate_request",
		"重复 request_id 被房主拒绝且不重复结算")
	_check(int(_server_state.get("action_index", -1)) == 1, "重复请求不推进 action_index")

	var stale_request: Dictionary = FormalLanProtocol.encode_action_request(
		"test:stale:black", 0, {
			"piece_id": "",
			"action_type": "pass",
			"target_cell": [],
			"skill_type": "",
		}
	)
	if bool(stale_request.get("ok", false)):
		_server_session._process_action_request(
			int(_client_state.get("local_peer_id", 0)),
			str(stale_request.get("bytes", ""))
		)
	var stale_rejected: bool = await _wait_until(func() -> bool:
		return not _client_feedback.is_empty() \
			and str(_client_feedback.back().get("error_code", "")) == "stale_action_index"
	, 360)
	_check(stale_rejected, "过期 expected_action_index 被房主拒绝")
	_check(int(_client_state.get("action_index", -1)) == 1, "过期请求不推进 action_index")

	var black_preview: Dictionary = _first_legal_move(_client_previews)
	_check(not black_preview.is_empty(), "黑方获得正式移动预览")
	if black_preview.is_empty():
		_finish()
		return
	_client_host.prepare_action(str(black_preview.get("preview_id", "")))
	_client_host.confirm_prepared_action(str(black_preview.get("preview_id", "")))
	var black_completed: bool = await _wait_until(func() -> bool:
		return int(_server_state.get("action_index", -1)) == 2 \
			and int(_client_state.get("action_index", -1)) == 2 \
			and str(_server_state.get("active_side", "")) == "red"
	, 360)
	_check(black_completed, "黑方正式移动经可靠 RPC 结算并切回红方回合")
	_check(_all_views_belong_to(_server_views, "red"), "多批次后红方端仍未串入黑方视图")
	_check(_all_views_belong_to(_client_views, "black"), "多批次后黑方端仍未串入红方视图")

	_client_session.disconnect_from_game()
	var disconnected: bool = await _wait_until(func() -> bool:
		return str(_server_state.get("state", "")) == "peer_disconnected" \
			and not bool(_server_state.get("peer_connected", true)) \
			and not bool(_server_state.get("match_started", true))
	, 360)
	_check(disconnected, "远端断线后 host 清理席位与权威对局")
	_check(not _server_session.has_authoritative_application(), "断线清理销毁 host 规则核心引用")

	_server_session.disconnect_from_game()
	var rehosted: Dictionary = _server_session.host_new_game(TEST_PORT + 1)
	var rejoined: Dictionary = _client_session.join_game("127.0.0.1", TEST_PORT + 1)
	_check(bool(rehosted.get("ok", false)) and bool(rejoined.get("ok", false)),
		"断线后可用 authority 内部 seed 再次建房")
	var reseated: bool = await _wait_until(func() -> bool:
		return bool(_server_state.get("peer_connected", false)) \
			and bool(_client_state.get("peer_connected", false)) \
			and str(_client_state.get("local_seat", "")) == "black"
	, 360)
	_check(reseated, "再次建房完成新的红黑席位闭环")
	_check(_first_forbidden_path(_server_state).is_empty() \
		and _first_forbidden_path(_client_state).is_empty(),
		"内部随机 seed 不进入 public_state")
	_server_session.disconnect_from_game()
	var server_lost: bool = await _wait_until(func() -> bool:
		return str(_client_state.get("state", "")) == "server_disconnected" \
			and str(_client_state.get("error_code", "")) == "server_disconnected"
	, 360)
	_check(server_lost, "服务器断开后客户端清理 peer 并发布明确状态")
	_finish()


func _setup_two_multiplayer_roots(packed_scene: PackedScene) -> void:
	_server_root = Node.new()
	_server_root.name = "ServerRoot"
	_client_root = Node.new()
	_client_root.name = "ClientRoot"
	root.add_child(_server_root)
	root.add_child(_client_root)
	set_multiplayer(MultiplayerAPI.create_default_interface(), _server_root.get_path())
	set_multiplayer(MultiplayerAPI.create_default_interface(), _client_root.get_path())
	_server_session = packed_scene.instantiate()
	_client_session = packed_scene.instantiate()
	_server_root.add_child(_server_session)
	_client_root.add_child(_client_session)
	_server_host = ApplicationHostScript.new()
	_client_host = ApplicationHostScript.new()
	_server_host.name = "ApplicationHost"
	_client_host.name = "ApplicationHost"
	_server_root.add_child(_server_host)
	_client_root.add_child(_client_host)


func _connect_observers() -> void:
	_server_host.session_state_changed.connect(func(state: Dictionary) -> void:
		_server_state = state.duplicate(true)
	)
	_client_host.session_state_changed.connect(func(state: Dictionary) -> void:
		_client_state = state.duplicate(true)
	)
	_server_host.player_view_updated.connect(func(view: Dictionary) -> void:
		_server_views.append(view.duplicate(true))
	)
	_client_host.player_view_updated.connect(func(view: Dictionary) -> void:
		_client_views.append(view.duplicate(true))
	)
	_server_host.action_previews_updated.connect(func(previews: Array) -> void:
		_server_previews = previews.duplicate(true)
	)
	_client_host.action_previews_updated.connect(func(previews: Array) -> void:
		_client_previews = previews.duplicate(true)
	)
	_server_session.action_feedback_received.connect(func(feedback: Dictionary) -> void:
		_server_feedback.append(feedback.duplicate(true))
	)
	_client_session.action_feedback_received.connect(func(feedback: Dictionary) -> void:
		_client_feedback.append(feedback.duplicate(true))
	)


func _protocol_bytes_are_deterministic() -> bool:
	if _server_session._application == null:
		return false
	var payload: Dictionary = _server_session._application.current_payload_for_side("red")
	var first: Dictionary = FormalLanProtocol.encode_observer_batch("red", payload, 99)
	var second: Dictionary = FormalLanProtocol.encode_observer_batch("red", payload, 99)
	return bool(first.get("ok", false)) and bool(second.get("ok", false)) \
		and str(first.get("bytes", "")) == str(second.get("bytes", ""))


func _protocol_rejects_extra_fields() -> bool:
	var encoded_batch: String = _server_session.get_current_observer_batch_bytes()
	var decoded: Dictionary = FormalLanProtocol.decode_observer_batch(encoded_batch)
	if not bool(decoded.get("ok", false)):
		return false
	var extra_outer: Dictionary = decoded.get("value", {}).duplicate(true)
	extra_outer["seed"] = 471221
	if bool(FormalLanProtocol.decode_observer_batch(
		JSON.stringify(extra_outer, "", true, true)
	).get("ok", false)):
		return false
	var hidden_view: Variant = JSON.parse_string(str(
		decoded.get("value", {}).get("player_view_json", "")
	))
	if not hidden_view is Dictionary:
		return false
	hidden_view["rng"] = {"state": 1}
	var hidden_outer: Dictionary = decoded.get("value", {}).duplicate(true)
	hidden_outer["player_view_json"] = JSON.stringify(hidden_view, "", true, true)
	return not bool(FormalLanProtocol.decode_observer_batch(
		JSON.stringify(hidden_outer, "", true, true)
	).get("ok", false))


func _all_action_types_are_whitelisted() -> bool:
	var fixtures: Dictionary = {
		"move": [1, 1],
		"bombard": [2, 5],
		"resurrect": [],
		"pass": [],
		"skip": [],
		"timeout": [],
	}
	for action_type: String in fixtures:
		var encoded: Dictionary = FormalLanProtocol.encode_action_request(
			"contract:%s" % action_type,
			0,
			{
				"piece_id": "fixture" if action_type in ["move", "bombard", "resurrect"] else "",
				"action_type": action_type,
				"target_cell": fixtures[action_type],
				"skill_type": "",
			}
		)
		if not bool(encoded.get("ok", false)) \
		or not bool(FormalLanProtocol.decode_action_request(
			str(encoded.get("bytes", ""))
		).get("ok", false)):
			return false
	return true


func _first_legal_move(previews: Array) -> Dictionary:
	for preview_value: Variant in previews:
		if preview_value is Dictionary \
		and str(preview_value.get("action_type", "")) == "move" \
		and str(preview_value.get("classification", "")) == "KNOWN_LEGAL":
			return preview_value.duplicate(true)
	return {}


func _all_views_belong_to(views: Array[Dictionary], side: String) -> bool:
	if views.is_empty():
		return false
	for view: Dictionary in views:
		if str(view.get("viewer_side", "")) != side:
			return false
	return true


func _all_views_are_observer_safe(views: Array[Dictionary]) -> bool:
	for view: Dictionary in views:
		if not _first_forbidden_path(view).is_empty():
			return false
	return true


func _first_forbidden_path(value: Variant, path: String = "$") -> String:
	var forbidden: Array[String] = [
		"seed", "match_seed", "rng", "full_state", "state_summary",
		"random_samples", "vision_sources", "prepared_action",
	]
	if value is Dictionary:
		for key_value: Variant in value.keys():
			var key: String = str(key_value).to_lower()
			if key in forbidden:
				return "%s.%s" % [path, key]
			var nested: String = _first_forbidden_path(value[key_value], "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
	elif value is Array:
		for index: int in value.size():
			var nested: String = _first_forbidden_path(value[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
	return ""


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in maximum_frames:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if is_instance_valid(_client_session):
		_client_session.disconnect_from_game()
	if is_instance_valid(_server_session):
		_server_session.disconnect_from_game()
	if is_instance_valid(_server_root):
		set_multiplayer(null, _server_root.get_path())
		_server_root.queue_free()
	if is_instance_valid(_client_root):
		set_multiplayer(null, _client_root.get_path())
		_client_root.queue_free()
	if _failures.is_empty():
		print("FORMAL_LAN_NETWORK_INTEGRATION_PASSED")
		quit(0)
		return
	print("FORMAL_LAN_NETWORK_INTEGRATION_FAILED count=%d" % _failures.size())
	quit(1)
