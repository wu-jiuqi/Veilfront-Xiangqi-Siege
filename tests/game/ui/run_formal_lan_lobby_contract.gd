extends SceneTree

const LOBBY_SCENE: PackedScene = preload("res://scenes/game/frontend/formal_lan_lobby.tscn")
const LOBBY_SOURCE := "res://scenes/game/frontend/formal_lan_lobby.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lobby := LOBBY_SCENE.instantiate() as Control
	root.add_child(lobby)
	await process_frame
	_expect(lobby != null, "formal LAN lobby did not instantiate")
	if lobby == null:
		_finish()
		return

	var source := FileAccess.get_file_as_string(LOBBY_SOURCE)
	_expect(not source.contains("res://scenes/prototype"), "formal lobby still depends on prototype scenes")
	_expect(not source.contains("LanNetworkSession"), "formal lobby still owns a network session")
	var signal_info: Dictionary = _find_signal(lobby, "host_requested")
	_expect(signal_info.get("args", []).size() == 1, "lobby must not expose a private match seed")

	lobby.render_connection_snapshot({"state": "disconnected"})
	var rules_turn_clock_value := _rules_turn_clock_value(lobby)
	_expect(rules_turn_clock_value != null, "lobby must keep the preset turn-clock label required by its renderer")
	if rules_turn_clock_value == null:
		_finish()
		return
	_expect(
		rules_turn_clock_value.text == "回合计时：以战局配置为准",
		"idle lobby must show the configured turn-clock fallback",
	)
	_expect(_host_button(lobby).visible and not _host_button(lobby).disabled, "host action must be available while idle")
	_expect(_join_button(lobby).visible and not _join_button(lobby).disabled, "join action must be available while idle")
	_expect(_disconnect_button(lobby).disabled, "disconnect must be disabled while idle")
	_expect(not _ready_button(lobby).visible, "ready must be hidden before seating")
	_expect(not _start_button(lobby).visible, "start must be hidden before seating")

	lobby.render_connection_snapshot({
		"state": "hosting",
		"role": "host",
		"local_seat": "red",
		"peer_connected": false,
	})
	_expect(not _host_button(lobby).visible and not _join_button(lobby).visible, "host/join must lock after opening a room")
	_expect(not _disconnect_button(lobby).disabled, "host must be able to close an open room")

	lobby.render_connection_snapshot({
		"state": "lobby",
		"role": "host",
		"local_seat": "red",
		"peer_connected": true,
		"red_ready": false,
		"black_ready": false,
		"can_start": false,
		"turn_timeout_seconds": 45,
	})
	_expect(_ready_button(lobby).visible and not _ready_button(lobby).disabled, "seated player must be able to ready")
	_expect(_start_button(lobby).visible and _start_button(lobby).disabled, "host start must wait for both players")
	_expect(
		_art_texture_path(_ready_button(lobby), &"art_texture").ends_with("ready_confirm_button_v2.png"),
		"ready action must use the generated confirm-ready PNG",
	)
	_expect(
		_art_texture_path(_ready_button(lobby), &"pressed_art_texture").ends_with("ready_cancel_button_v2.png"),
		"pressed ready action must use the generated cancel-ready PNG",
	)
	_expect(
		_art_texture_path(_start_button(lobby), &"art_texture").ends_with("start_game_button_v2.png"),
		"host start action must use the generated start-game PNG",
	)
	_expect(
		_focus_frame_style(_ready_button(lobby)) is StyleBoxFlat,
		"ready action must keep a local focus frame instead of inheriting the global button texture",
	)
	_expect(rules_turn_clock_value.text == "每回合 45 秒", "lobby must render the synchronized turn clock")

	lobby.render_connection_snapshot({
		"state": "ready",
		"role": "host",
		"local_seat": "red",
		"peer_connected": true,
		"red_ready": true,
		"black_ready": true,
		"can_start": true,
	})
	_expect(_start_button(lobby).visible and not _start_button(lobby).disabled, "host start must unlock when both players are ready")

	lobby.render_connection_snapshot({
		"state": "ready",
		"role": "client",
		"local_seat": "black",
		"peer_connected": true,
		"red_ready": true,
		"black_ready": true,
		"can_start": false,
	})
	_expect(not _start_button(lobby).visible, "client must never receive the start control")
	_expect(_copy_address_button(lobby).disabled, "client must not copy a host endpoint as its room address")

	lobby.queue_free()
	await process_frame
	_finish()


func _find_signal(node: Object, signal_name: String) -> Dictionary:
	for signal_info: Dictionary in node.get_signal_list():
		if str(signal_info.get("name", "")) == signal_name:
			return signal_info
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FORMAL_LAN_LOBBY_CONTRACT_PASS states=5 private_seed=absent")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FORMAL_LAN_LOBBY_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _host_button(lobby: Node) -> BaseButton:
	return lobby.get_node("%HostButton") as BaseButton


func _join_button(lobby: Node) -> BaseButton:
	return lobby.get_node("%JoinButton") as BaseButton


func _disconnect_button(lobby: Node) -> BaseButton:
	return lobby.get_node("%DisconnectButton") as BaseButton


func _ready_button(lobby: Node) -> Button:
	return lobby.get_node("%ReadyButton") as Button


func _start_button(lobby: Node) -> Button:
	return lobby.get_node("%StartButton") as Button


func _copy_address_button(lobby: Node) -> BaseButton:
	return lobby.get_node("%CopyAddressButton") as BaseButton


func _rules_turn_clock_value(lobby: Node) -> Label:
	return lobby.get_node_or_null("%RulesTurnClockValue") as Label


func _art_texture_path(button: Button, property_name: StringName) -> String:
	var texture := button.get(property_name) as Texture2D
	if texture == null:
		return ""
	return texture.resource_path


func _focus_frame_style(button: Button) -> StyleBox:
	var focus_frame := button.get_node_or_null("%FocusFrame") as Panel
	return focus_frame.get_theme_stylebox(&"panel") if focus_frame != null else null
