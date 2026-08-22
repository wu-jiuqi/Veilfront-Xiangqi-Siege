extends SceneTree

const TERMINAL_SCENE: PackedScene = preload("res://scenes/game/ui/terminal_dialog.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var dialog := TERMINAL_SCENE.instantiate() as MatchTerminalDialog
	root.add_child(dialog)
	await process_frame
	await process_frame
	_expect(dialog != null, "terminal dialog must instantiate as MatchTerminalDialog")
	if dialog == null:
		_finish()
		return

	_expect(dialog.get_node_or_null("Dimmer") == null, "terminal dialog must not own a generated background")
	var panel := dialog.get_node("SafeMargin/Center/ResultPanel") as Control
	var panel_art := panel.get_node("PanelArt") as TextureRect
	_expect(
		panel_art.texture != null \
		and panel_art.texture.resource_path.ends_with("terminal_result_panel_v2.png"),
		"terminal frame must use the approved chroma-keyed result-panel PNG",
	)
	var restart_button := dialog.get_node("%RestartButton") as TextureButton
	var lobby_button := dialog.get_node("%LobbyButton") as TextureButton
	_expect(
		restart_button.texture_normal.resource_path.ends_with("terminal_result_button_primary_v2.png") \
		and lobby_button.texture_normal.resource_path.ends_with("terminal_result_button_secondary_v2.png") \
		and lobby_button.texture_hover.resource_path.ends_with("terminal_result_button_primary_v2.png"),
		"terminal actions must use PNG plates for normal and hover states",
	)
	var panel_image := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/art/ui/terminal_result/terminal_result_panel_v2.png")
	)
	_expect(
		panel_image != null and panel_image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF],
		"terminal result panel must preserve a real alpha channel after chroma keying",
	)

	var victory_view := {
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
		"casualties": [
			{"side": "red"},
			{"side": "black"},
			{"side": "black"},
		],
	}
	dialog.show_result(victory_view, MatchTerminalDialog.CONTEXT_PREVIEW)
	await process_frame
	var snapshot := dialog.get_presentation_snapshot()
	_expect(dialog.visible, "terminal result must become visible")
	_expect(snapshot.get("result_text") == "胜利", "viewer-side winner must render victory")
	_expect(snapshot.get("reason_text") == "夺得三面军旗", "public win reason must map to player text")
	_expect(snapshot.get("red_outcome") == "胜利" and snapshot.get("black_outcome") == "败北", "faction outcomes must be explicit")
	_expect(snapshot.get("round_value") == "18", "full round count must render")
	_expect(snapshot.get("flag_value") == "3 : 0", "public flag ownership must be counted by faction")
	_expect(snapshot.get("casualty_value") == "1 : 2", "public casualties must be counted by faction")
	_expect(
		bool(snapshot.get("restart_visible")) \
		and bool(snapshot.get("lobby_visible")) \
		and bool(snapshot.get("level_select_visible")),
		"preview context must expose all approved action variants",
	)
	_expect((dialog.get_node("%RestartButton") as BaseButton).has_focus(), "preview result must focus replay")

	var emissions := {"restart": 0, "destination": ""}
	dialog.restart_requested.connect(func() -> void: emissions.restart += 1)
	dialog.exit_requested.connect(
		func(destination: String) -> void: emissions.destination = destination
	)
	(dialog.get_node("%RestartButton") as BaseButton).emit_signal("pressed")
	_expect(
		emissions.restart == 1 and dialog.visible,
		"replay must emit once and remain visible until a fresh PlayerView arrives",
	)
	dialog.hide_result()

	var defeat_view := victory_view.duplicate(true)
	defeat_view.viewer_side = "black"
	dialog.show_result(defeat_view, MatchTerminalDialog.CONTEXT_LAN)
	await process_frame
	snapshot = dialog.get_presentation_snapshot()
	_expect(snapshot.get("result_text") == "败北", "opponent winner must render defeat")
	_expect(
		not bool(snapshot.get("restart_visible")) \
		and bool(snapshot.get("lobby_visible")) \
		and not bool(snapshot.get("level_select_visible")),
		"LAN context must only expose return to lobby",
	)
	_expect((dialog.get_node("%LobbyButton") as BaseButton).has_focus(), "LAN result must focus return to lobby")
	(dialog.get_node("%LobbyButton") as BaseButton).emit_signal("pressed")
	_expect(
		emissions.destination == MatchTerminalDialog.DESTINATION_LOBBY,
		"lobby action must emit the explicit lobby destination",
	)

	var draw_view := victory_view.duplicate(true)
	draw_view.winner = "draw"
	draw_view.win_reason = "round_limit_draw"
	dialog.show_result(draw_view, MatchTerminalDialog.CONTEXT_LEVEL)
	await process_frame
	snapshot = dialog.get_presentation_snapshot()
	_expect(snapshot.get("result_text") == "和局", "draw winner must render draw")
	_expect(snapshot.get("red_outcome") == "和局" and snapshot.get("black_outcome") == "和局", "draw must apply to both factions")
	_expect(
		bool(snapshot.get("restart_visible")) \
		and not bool(snapshot.get("lobby_visible")) \
		and bool(snapshot.get("level_select_visible")),
		"level context must expose replay and level selection",
	)
	(dialog.get_node("%LevelSelectButton") as BaseButton).emit_signal("pressed")
	_expect(
		emissions.destination == MatchTerminalDialog.DESTINATION_LEVEL_SELECT,
		"level action must emit the explicit level-select destination",
	)

	dialog.size = Vector2(960.0, 540.0)
	await process_frame
	snapshot = dialog.get_presentation_snapshot()
	var panel_size: Vector2 = snapshot.get("panel_size", Vector2.ZERO)
	_expect(
		panel_size.x <= 924.5 and panel_size.y <= 504.5,
		"960x540 result frame must stay inside safe margins: %s" % panel_size,
	)
	_expect((dialog.get_node("%RestartButton") as BaseButton).custom_minimum_size.y >= 44.0, "result actions must keep desktop/controller target height")
	var previous_panel_size := panel_size
	for target_size: Vector2 in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		dialog.size = target_size
		await process_frame
		panel_size = dialog.get_presentation_snapshot().get("panel_size", Vector2.ZERO)
		_expect(
			panel_size.x <= target_size.x - 35.5 and panel_size.y <= target_size.y - 35.5,
			"result frame must stay inside safe margins at %s: %s" % [target_size, panel_size],
		)
		_expect(
			panel_size.x >= previous_panel_size.x and panel_size.y >= previous_panel_size.y,
			"result frame must scale monotonically across desktop resolutions",
		)
		previous_panel_size = panel_size

	dialog.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TERMINAL_DIALOG_CONTRACT_PASS contexts=3 responsive=960x540,1280x720,1920x1080")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TERMINAL_DIALOG_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)
