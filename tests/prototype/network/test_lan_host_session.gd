extends RefCounted

const LanProtocol = preload("res://scripts/prototype/network/lan_protocol.gd")
const LanHostSession = preload("res://scripts/prototype/network/lan_host_session.gd")


static func run_suite() -> bool:
	var failures: Array[String] = []
	var session: RefCounted = LanHostSession.new()
	var initialized: Dictionary = session.initialize(471001, 50)
	_expect(bool(initialized.get("ok", false)), "房主会话初始化", failures)
	var joined: Dictionary = session.register_remote_peer(2)
	_expect(bool(joined.get("ok", false)), "远端 peer 加入", failures)
	_expect(str(joined.get("seat", "")) == "black", "加入者固定黑方", failures)
	_expect(not bool(session.register_remote_peer(3).get("ok", false)), "第三名玩家被房间容量拒绝", failures)

	var red_delivery: Dictionary = session.player_delivery_for_peer(1)
	var black_delivery: Dictionary = session.player_delivery_for_peer(2)
	_expect(bool(LanProtocol.validate_player_delivery(red_delivery).get("ok", false)), "红方下行通过白名单", failures)
	_expect(bool(LanProtocol.validate_player_delivery(black_delivery).get("ok", false)), "黑方下行通过白名单", failures)
	_expect(str(red_delivery.get("seat", "")) == "red", "房主固定红方", failures)
	_expect(str(black_delivery.get("seat", "")) == "black", "客户端投影绑定黑方", failures)
	_expect(str(red_delivery.get("player_view", {}).get("viewer_side", "")) == "red", "红方只收红方 PlayerView", failures)
	_expect(str(black_delivery.get("player_view", {}).get("viewer_side", "")) == "black", "黑方只收黑方 PlayerView", failures)
	_expect(str(red_delivery.get("player_view", {}).get("schema_version", "")) == LanProtocol.NETWORK_PLAYER_VIEW_SCHEMA, "下行使用网络专用 PlayerView 白名单", failures)
	_expect(not red_delivery.get("player_view", {}).has("match_seed"), "红方网络快照不下发可推导隐藏随机结果的种子", failures)
	_expect(not black_delivery.get("player_view", {}).has("match_seed"), "黑方网络快照不下发可推导隐藏随机结果的种子", failures)
	_expect(_flags_respect_discovery(red_delivery), "红方网络 DTO 的旗位遵守发现记忆边界", failures)
	_expect(_flags_respect_discovery(black_delivery), "黑方网络 DTO 的旗位遵守发现记忆边界", failures)
	_expect(LanProtocol.first_forbidden_path(red_delivery).is_empty(), "红方下行没有 FullState 受禁字段", failures)
	_expect(LanProtocol.first_forbidden_path(black_delivery).is_empty(), "黑方下行没有 FullState 受禁字段", failures)
	var polluted_delivery: Dictionary = black_delivery.duplicate(true)
	polluted_delivery["player_view"]["hidden_pieces"] = []
	_expect(
		str(LanProtocol.validate_player_delivery(polluted_delivery).get("error", "")) == "player_view_fields_invalid",
		"PlayerView 新增非白名单字段会阻断下行",
		failures
	)
	var flag_polluted_delivery: Dictionary = black_delivery.duplicate(true)
	flag_polluted_delivery["player_view"]["flags"][0]["discovered"] = false
	flag_polluted_delivery["player_view"]["flags"][0]["position"] = [5, 12]
	var polluted_flag_result: Dictionary = LanProtocol.validate_player_delivery(flag_polluted_delivery)
	_expect(
		str(polluted_flag_result.get("error", "")) == "undiscovered_flag_position_leak",
		"未发现旗帜混入位置时会阻断下行",
		failures
	)
	var source_view_with_hidden_flag: Dictionary = red_delivery["player_view"].duplicate(true)
	source_view_with_hidden_flag["schema_version"] = "player-view-v1"
	source_view_with_hidden_flag["match_seed"] = 999
	source_view_with_hidden_flag["flags"][0]["discovered"] = true
	source_view_with_hidden_flag["flags"][0]["position"] = [1, 9]
	source_view_with_hidden_flag["flags"][0]["capture_progress"] = 2
	var sanitized_delivery: Dictionary = LanProtocol.build_player_delivery("red", source_view_with_hidden_flag)
	_expect(not sanitized_delivery["player_view"].has("match_seed"), "下行构造器删除源投影中的 match_seed", failures)
	_expect(_flags_respect_discovery(sanitized_delivery), "下行构造器保留已发现旗位并维持迷雾边界", failures)
	_expect(sanitized_delivery["player_view"]["flags"][0]["position"] == [1, 9], "已发现旗位可同步到发现方", failures)
	_expect(int(sanitized_delivery["player_view"]["flags"][0]["capture_progress"]) == 2, "下行构造器保留公开夺旗进度", failures)

	var resurrect_request: Dictionary = LanProtocol.build_action_request("red-resurrect", 0, {
		"piece_id": "red-advisor-1",
		"action_type": "resurrect",
		"target_cell": [],
		"skill_type": "advisor_resurrection",
	})
	var resurrect_validation: Dictionary = LanProtocol.validate_action_request(resurrect_request)
	_expect(bool(resurrect_validation.get("ok", false)), "士主动复活动作通过网络协议白名单", failures)
	_expect(resurrect_validation.get("request", {}).get("intent", {}).get("target_cell", []) == [0, 0], "非空间复活动作规范化为固定哨兵格", failures)

	var black_early: Dictionary = session.submit_request(2, _pass_request("black-early", 0))
	_expect(str(black_early.get("error", "")) == "not_active_side", "非行动方不能提交", failures)
	var stale_red: Dictionary = session.submit_request(1, _pass_request("red-stale", 1))
	_expect(str(stale_red.get("error", "")) == "stale_action_index", "过期或超前 action index 被拒绝", failures)
	var illegal_red: Dictionary = session.submit_request(1, LanProtocol.build_action_request(
		"red-illegal",
		0,
		{"piece_id": "missing", "action_type": "move", "target_cell": [5, 6], "skill_type": ""}
	))
	_expect(str(illegal_red.get("error", "")) == "known_illegal", "公开已知非法行动不进入规则结算", failures)

	var red_pass: Dictionary = session.submit_request(1, _pass_request("red-pass", 0))
	_expect(bool(red_pass.get("consumed", false)), "红方 pass 被权威结算", failures)
	_expect(int(red_pass.get("next_action_index", -1)) == 1, "红方行动后推进到 action 1", failures)
	var duplicate_red: Dictionary = session.submit_request(1, _pass_request("red-pass", 0))
	_expect(str(duplicate_red.get("error", "")) == "duplicate_request", "重复请求 ID 被拒绝", failures)
	var black_after_red: Dictionary = session.player_delivery_for_peer(2)
	_expect(int(black_after_red.get("player_view", {}).get("action_index", -1)) == 1, "黑方收到推进后的 PlayerView", failures)
	_expect(str(black_after_red.get("player_view", {}).get("active_side", "")) == "black", "红方行动后轮到黑方", failures)

	var black_pass: Dictionary = session.submit_request(2, _pass_request("black-pass", 1))
	_expect(bool(black_pass.get("consumed", false)), "黑方 pass 被权威结算", failures)
	_expect(int(black_pass.get("next_action_index", -1)) == 2, "双方各一步后推进到 action 2", failures)
	var public_snapshot: Dictionary = session.public_session_snapshot()
	_expect(not public_snapshot.has("board") and not public_snapshot.has("rng"), "公开会话摘要不含 FullState/RNG", failures)
	_expect(not bool(public_snapshot.get("remote_reconnect_supported", true)), "公开会话明确不支持断线重连", failures)
	session.unregister_peer(2)
	var reconnect_attempt: Dictionary = session.register_remote_peer(4)
	_expect(str(reconnect_attempt.get("error", "")) == "reconnect_not_supported", "远端掉线后必须重新开房而非重连旧局", failures)

	var request_with_extra_field: Dictionary = _pass_request("extra", 2)
	request_with_extra_field["debug"] = true
	var extra_result: Dictionary = session.submit_request(1, request_with_extra_field)
	_expect(str(extra_result.get("error", "")) == "request_fields_invalid", "请求额外字段被协议白名单拒绝", failures)

	for failure: String in failures:
		push_error("LAN_HOST_SESSION_FAIL: %s" % failure)
	return failures.is_empty()


static func _pass_request(request_id: String, action_index: int) -> Dictionary:
	return LanProtocol.build_action_request(request_id, action_index, {
		"piece_id": "",
		"action_type": "pass",
		"target_cell": [],
		"skill_type": "",
	})


static func _expect(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)


static func _flags_respect_discovery(delivery: Dictionary) -> bool:
	for flag_value: Variant in delivery.get("player_view", {}).get("flags", []):
		if not flag_value is Dictionary:
			return false
		var flag: Dictionary = flag_value
		if not flag.has("discovered") or not flag.has("position"):
			return false
		if flag.has("flag_position") or flag.has("flag_cell"):
			return false
		var position: Array = flag.get("position", [])
		if bool(flag.get("discovered", false)) != (position.size() == 2):
			return false
	return true
