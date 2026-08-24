extends SceneTree

const APP_SCENE: PackedScene = preload("res://scenes/game/app/formal_lan_game_app.tscn")
const TEST_PORT: int = 29779

var _failures: Array[String] = []
var _server_root: Node
var _client_root: Node
var _server_app: Control
var _client_app: Control


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_setup_apps()
	await process_frame
	await process_frame
	var server_lobby: Control = _server_app.get_node("ScreenHost/FormalLanLobby")
	var client_lobby: Control = _client_app.get_node("ScreenHost/FormalLanLobby")
	var server_session: Node = _server_app.get_node("FormalLanSession")
	var client_session: Node = _client_app.get_node("FormalLanSession")

	_set_endpoint(server_lobby, "127.0.0.1", TEST_PORT)
	server_lobby.get_node("%HostButton").emit_signal("pressed")
	_set_endpoint(client_lobby, "127.0.0.1", TEST_PORT)
	client_lobby.get_node("%JoinButton").emit_signal("pressed")
	var seated := await _wait_until(func() -> bool:
		var server_state: Dictionary = server_session.get_public_state_snapshot()
		var client_state: Dictionary = client_session.get_public_state_snapshot()
		return bool(server_state.get("peer_connected", false)) \
			and bool(client_state.get("peer_connected", false)) \
			and str(server_state.get("local_seat", "")) == "red" \
			and str(client_state.get("local_seat", "")) == "black"
	)
	_check(seated, "正式组合根完成大厅创建、加入和红黑入席")
	if not seated:
		await _finish()
		return

	var server_ready := server_lobby.get_node("%ReadyButton") as Button
	var client_ready := client_lobby.get_node("%ReadyButton") as Button
	_check(server_ready.visible and client_ready.visible, "双方入席后显式准备按钮可见")
	server_ready.button_pressed = true
	client_ready.button_pressed = true
	var both_ready := await _wait_until(func() -> bool:
		return bool(server_session.get_public_state_snapshot().get("can_start", false)) \
			and bool(client_session.get_public_state_snapshot().get("black_ready", false))
	)
	_check(both_ready, "双方显式准备经权威会话同步")
	var start_button := server_lobby.get_node("%StartButton") as Button
	_check(start_button.visible and not start_button.disabled, "仅房主在双方准备后获得开局按钮")
	_check(not (client_lobby.get_node("%StartButton") as Button).visible, "客户端不显示开局按钮")
	start_button.emit_signal("pressed")

	var entered_match := await _wait_until(func() -> bool:
		return _server_app.get_node("ScreenHost/MatchScreen").visible \
			and _client_app.get_node("ScreenHost/MatchScreen").visible \
			and not _server_app.get_node("ScreenHost/MatchScreen").get_player_view_snapshot().is_empty() \
			and not _client_app.get_node("ScreenHost/MatchScreen").get_player_view_snapshot().is_empty()
	)
	_check(entered_match, "正式大厅经房主开局进入双方 MatchScreen")
	if not entered_match:
		await _finish()
		return

	var server_match: Control = _server_app.get_node("ScreenHost/MatchScreen")
	var client_match: Control = _client_app.get_node("ScreenHost/MatchScreen")
	_check(str(server_match.get_player_view_snapshot().get("viewer_side", "")) == "red", "房主 MatchScreen 只绑定赤方 PlayerView")
	_check(str(client_match.get_player_view_snapshot().get("viewer_side", "")) == "black", "客户端 MatchScreen 只绑定玄方 PlayerView")
	_check(not (server_match.get_node("MatchHudV3/SafeMargin/MainRows/TopBand/FactionRight/MirrorButton") as Button).visible, "LAN 隐藏镜像视角按钮")
	_check((server_match.get_node("MatchHudV3/SafeMargin/MainRows/TopBand/FactionLeft/ReturnButton") as Button).visible, "LAN 显示退出对局按钮")
	_check(
		not (server_match.get_node("TerminalDialog").get_node("%RestartButton") as BaseButton).visible,
		"LAN 隐藏直接重赛按钮",
	)
	var fog: Node = server_match.find_child("FogOverlay", true, false)
	_check(fog != null and bool(fog.get_visual_snapshot().get("uses_player_view_only", false)), "正式 MatchScreen 使用 PlayerView-only 动态迷雾")
	server_match.apply_marker(Vector2i(1, 1), "circle")
	_check(int(server_match.get_board_render_snapshot().get("marker_count", 0)) == 1, "LAN 私有标记只保存在本地 MatchScreen")

	var red_moved := await _submit_first_move(server_match, server_session, false)
	_check(red_moved, "赤方通过正式 MatchScreen 选择、确认并提交移动")
	var red_synced := await _wait_until(func() -> bool:
		return int(server_session.get_public_state_snapshot().get("action_index", -1)) == 1 \
			and int(client_session.get_public_state_snapshot().get("action_index", -1)) == 1 \
			and int(client_match.get_player_view_snapshot().get("action_index", -1)) == 1 \
			and not client_session.create_client_port()._available_previews.is_empty()
	)
	if not red_synced:
		var remote_peer_id: int = int(client_session.get_public_state_snapshot().get("local_peer_id", 0))
		print("RED_SYNC_DIAGNOSTIC server_state=%s client_state=%s server_view_index=%s client_view_index=%s server_frames=%s client_frames=%s host_sequences=%s host_batch_peers=%s remote_batch_bytes=%d server_previews=%d client_previews=%d" % [
			JSON.stringify(server_session.get_public_state_snapshot()),
			JSON.stringify(client_session.get_public_state_snapshot()),
			str(server_match.get_player_view_snapshot().get("action_index", -1)),
			str(client_match.get_player_view_snapshot().get("action_index", -1)),
			str(server_session.create_client_port()._last_frame_sequence),
			str(client_session.create_client_port()._last_frame_sequence),
			JSON.stringify(server_session._frame_sequence_by_peer),
			JSON.stringify(server_session._observer_batch_by_peer.keys()),
			str(server_session._observer_batch_by_peer.get(remote_peer_id, "")).length(),
			server_session.create_client_port()._available_previews.size(),
			client_session.create_client_port()._available_previews.size(),
		])
	_check(red_synced, "赤方移动同步到双方正式 HUD")

	var black_moved := await _submit_first_move(client_match, client_session, true)
	_check(black_moved, "玄方通过正式 MatchScreen 提交远端移动")
	_check(bool(client_match.get_presentation_snapshot().get("submission_pending", false)), "远端提交期间启用防重复锁")
	var black_synced := await _wait_until(func() -> bool:
		return int(server_session.get_public_state_snapshot().get("action_index", -1)) == 2 \
			and int(client_session.get_public_state_snapshot().get("action_index", -1)) == 2 \
			and not bool(client_match.get_presentation_snapshot().get("submission_pending", true))
	)
	_check(black_synced, "玄方移动同步后解除提交锁并切回赤方")
	_server_app._on_player_view_updated({
		"terminal": true,
		"viewer_side": "red",
		"winner": "red",
		"win_reason": "three_flags",
		"full_round_index": 18,
		"flags": [
			{"discovered": true, "owner": "red"},
			{"discovered": true, "owner": "red"},
			{"discovered": true, "owner": "red"},
		],
		"casualties": [],
	})
	var terminal_dialog := server_match.get_node("TerminalDialog") as MatchTerminalDialog
	await process_frame
	var terminal_snapshot: Dictionary = terminal_dialog.get_presentation_snapshot()
	_check(
		terminal_dialog.visible \
		and terminal_snapshot.get("result_text") == "胜利" \
		and terminal_snapshot.get("reason_text") == "夺得三面军旗" \
		and terminal_snapshot.get("flag_value") == "3 : 0",
		"终局只按本地 PlayerView 显示胜负、公开原因与回顾",
	)
	_check(
		not bool(terminal_snapshot.get("restart_visible")) \
		and bool(terminal_snapshot.get("lobby_visible")) \
		and not bool(terminal_snapshot.get("level_select_visible")),
		"LAN 终局只提供返回大厅",
	)
	_check(
		(server_match.get_node("TerminalDialog").get_node("%LobbyButton") as BaseButton).has_focus(),
		"LAN 终局默认聚焦返回大厅",
	)
	terminal_dialog.hide_result()

	server_match.emit_signal("return_requested")
	var leave_dialog := _server_app.get_node("GlobalOverlayHost/LeaveSessionDialog") as TerracottaModalDialog
	_check(leave_dialog.visible, "对局返回先显示离开确认")
	await process_frame
	_check(leave_dialog.get_cancel_button().has_focus(), "离开确认默认聚焦取消")
	leave_dialog.hide()
	leave_dialog.emit_signal("confirmed")
	var disconnected := await _wait_until(func() -> bool:
		return str(server_session.get_public_state_snapshot().get("state", "")) == "disconnected" \
			and (_client_app.get_node("GlobalOverlayHost/ConnectionErrorDialog") as TerracottaModalDialog).visible
	)
	_check(disconnected, "房主离开后客户端进入阻断式断线恢复")
	if disconnected:
		(_client_app.get_node("GlobalOverlayHost/ConnectionErrorDialog") as TerracottaModalDialog).emit_signal("confirmed")
		await process_frame
	_check(server_lobby.visible and client_lobby.visible, "清理端口和预览后双方返回正式大厅")
	var cleared_board: Dictionary = server_match.get_board_render_snapshot()
	var cleared_minimap: Dictionary = server_match.get_hud_snapshot().get("minimap", {})
	_check(int(cleared_board.get("piece_count", -1)) == 0 \
		and int(cleared_board.get("flag_count", -1)) == 0 \
		and int(cleared_board.get("marker_count", -1)) == 0, "断线清除旧棋子、旗帜与私有标记")
	_check(int(cleared_minimap.get("piece_count", -1)) == 0 \
		and int(cleared_minimap.get("flag_count", -1)) == 0, "断线清除小地图旧 PlayerView")
	await _finish()


func _setup_apps() -> void:
	_server_root = Node.new()
	_server_root.name = "FullStackServerRoot"
	_client_root = Node.new()
	_client_root.name = "FullStackClientRoot"
	root.add_child(_server_root)
	root.add_child(_client_root)
	set_multiplayer(MultiplayerAPI.create_default_interface(), _server_root.get_path())
	set_multiplayer(MultiplayerAPI.create_default_interface(), _client_root.get_path())
	_server_app = APP_SCENE.instantiate() as Control
	_client_app = APP_SCENE.instantiate() as Control
	_disable_board_rendering(_server_app)
	_disable_board_rendering(_client_app)
	_server_root.add_child(_server_app)
	_client_root.add_child(_client_app)


func _disable_board_rendering(app: Control) -> void:
	# This contract verifies LAN lifecycle, PlayerView safety, and HUD state. It
	# never samples pixels, so rendering two formal large board targets only adds
	# GPU/driver lifecycle cost to the headless runner.
	var board_render_target := app.get_node(
		"ScreenHost/MatchScreen/MatchHudV3/SafeMargin/MainRows/BodyBand/CenterColumn/BoardFrame/BoardViewport/BoardSubViewport"
	) as SubViewport
	board_render_target.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _set_endpoint(lobby: Control, address: String, port: int) -> void:
	(lobby.get_node("%AddressInput") as LineEdit).text = "%s:%d" % [address, port]
	(lobby.get_node("%PortInput") as SpinBox).value = float(port)


func _submit_first_move(match_screen: Control, session: Node, expect_pending: bool) -> bool:
	var port: RefCounted = session.create_client_port()
	var preview: Dictionary = {}
	for preview_value: Variant in port._available_previews:
		if preview_value is Dictionary \
		and str(preview_value.get("action_type", "")) == "move" \
		and str(preview_value.get("classification", "")) == "KNOWN_LEGAL":
			preview = preview_value.duplicate(true)
			break
	if preview.is_empty():
		return false
	var piece_position: Array = []
	for piece_value: Variant in match_screen.get_player_view_snapshot().get("pieces", []):
		if piece_value is Dictionary and str(piece_value.get("id", "")) == str(preview.get("piece_id", "")):
			piece_position = piece_value.get("position", []).duplicate()
			break
	var target: Array = preview.get("target_cell", [])
	if piece_position.size() != 2 or target.size() != 2:
		return false
	match_screen.handle_board_point(Vector2i(int(piece_position[0]), int(piece_position[1])))
	match_screen.handle_board_point(Vector2i(int(target[0]), int(target[1])))
	if str(match_screen.get_local_interaction_state()) != "CONFIRMING":
		return false
	match_screen.confirm_prepared_action()
	if expect_pending and not bool(match_screen.get_presentation_snapshot().get("submission_pending", false)):
		return false
	return true


func _wait_until(predicate: Callable, maximum_frames: int = 480) -> bool:
	for _frame: int in maximum_frames:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if is_instance_valid(_client_app):
		_client_app.get_node("FormalLanSession").disconnect_from_game()
	if is_instance_valid(_server_app):
		_server_app.get_node("FormalLanSession").disconnect_from_game()
	if is_instance_valid(_client_root):
		_client_root.queue_free()
	if is_instance_valid(_server_root):
		_server_root.queue_free()
	# 首次导入后，屏幕级粒子与纹理可能跨越数帧才完成 RenderingServer 释放。
	# 保留完整泄漏检查，同时为队列释放提供确定性的收尾窗口。
	for _cleanup_frame: int in 8:
		await process_frame
	if _failures.is_empty():
		print("FORMAL_LAN_FULL_STACK_LOOPBACK_PASS ux=ready-start-match-submit-disconnect")
		quit(0)
		return
	print("FORMAL_LAN_FULL_STACK_LOOPBACK_FAIL failures=%d" % _failures.size())
	quit(1)
