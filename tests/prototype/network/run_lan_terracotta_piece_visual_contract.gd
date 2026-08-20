extends SceneTree

const BOARD_SHELL := preload("res://scenes/prototype/board_shell.tscn")
const LAN_LOBBY := preload("res://scenes/prototype/network/lan_lobby.tscn")

var failures: Array[String] = []


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-side="):
			call_deferred("_capture_lan_view")
			return
	call_deferred("_run")


func _run() -> void:
	var board_shell: PanelContainer = BOARD_SHELL.instantiate()
	root.add_child(board_shell)
	await process_frame
	var surface: Control = board_shell.get_node(
		"BoardMargin/BoardColumn/BoardScroll/BoardSurface"
	) as Control
	_check(surface != null, "LAN棋盘表面预置可加载")
	_check(surface != null and surface.has_method("piece_art_catalog_snapshot"),
		"棋盘暴露14纹理映射合同")
	_check(surface != null and surface.has_method("piece_art_render_snapshot"),
		"棋盘暴露仅由PlayerView驱动的贴图绘制合同")
	if surface == null or not surface.has_method("piece_art_render_snapshot"):
		_finish(board_shell)
		return

	var catalog: Dictionary = surface.call("piece_art_catalog_snapshot")
	_check(catalog.size() == 14, "红黑双方七兵种共14张纹理")
	for side: String in ["red", "black"]:
		for piece_type: String in ["pawn", "cannon", "rook", "horse", "elephant", "advisor", "general"]:
			var key: String = "%s:%s" % [side, piece_type]
			_check(catalog.has(key), "纹理映射包含%s" % key)
			_check(str(catalog.get(key, "")).contains("/%s_" % side), "%s映射到正确阵营纹理" % key)

	var full_view: Dictionary = _full_visible_lan_view()
	surface.set_board_data(full_view, [], "", [], "move", true)
	var rendered: Array = surface.call("piece_art_render_snapshot")
	_check(rendered.size() == 32, "标准全显PlayerView绘制红黑双方共32枚棋子")
	_check(_role_counts_match(rendered), "双方均保持5兵、2炮、2车、2马、2相、2士、1将")
	_check(_all_art_is_proportional_and_anchored(rendered), "14类贴图均等比缩放并以脚底锚定交点")

	var restricted_view: Dictionary = full_view.duplicate(true)
	restricted_view["pieces"] = [
		full_view["pieces"][0].duplicate(true),
		full_view["pieces"][16].duplicate(true),
		{
			"id": "red-hidden-dead", "side": "red", "piece_type": "general",
			"alive": false, "in_reserve": false, "position": [5, 12],
		},
		{
			"id": "black-hidden-reserve", "side": "black", "piece_type": "general",
			"alive": true, "in_reserve": true, "position": [5, 13],
		},
	]
	surface.set_board_data(restricted_view, [], "", [], "move", false)
	rendered = surface.call("piece_art_render_snapshot")
	_check(rendered.size() == 2, "贴图层只绘制PlayerView中在场存活的棋子")
	_check(_rendered_ids(rendered) == ["black-rook-1", "red-rook-1"],
		"隐藏、阵亡和reserve棋子不会产生贴图绘制项")

	var local_graybox_view: Dictionary = full_view.duplicate(true)
	local_graybox_view["schema_version"] = "prototype-player-view-v1"
	surface.set_board_data(local_graybox_view, [], "", [], "move", true)
	_check(surface.call("piece_art_render_snapshot").is_empty(),
		"非LAN PlayerView继续使用原圆形字棋回退")

	_finish(board_shell)


func _full_visible_lan_view() -> Dictionary:
	var pieces: Array = []
	_append_side(pieces, "red", 1, 3, 4)
	_append_side(pieces, "black", 24, 22, 21)
	return {
		"schema_version": "lan-player-view-v3",
		"viewer_side": "red",
		"active_side": "red",
		"action_index": 0,
		"full_round_index": 0,
		"full_round_limit_hypothesis": 50,
		"round_limit_status": "hypothesis_cli_overridable",
		"implementation_revision": "prototype-core-revision-5",
		"terminal": false,
		"winner": "",
		"win_reason": "",
		"pieces": pieces,
		"visible_cells": _all_board_cells(),
		"contact_intel": [],
		"capture_ghosts": [],
		"flags": [],
		"vision_overlays": {},
		"casualties": [],
		"walls": [],
		"player_events": [],
	}


func _all_board_cells() -> Array:
	var cells: Array = []
	for y: int in range(1, 25):
		for x: int in range(1, 10):
			cells.append([x, y])
	return cells


func _append_side(pieces: Array, side: String, back_y: int, cannon_y: int, pawn_y: int) -> void:
	var serials: Dictionary = {}
	var back_types: Array[String] = [
		"rook", "horse", "elephant", "advisor", "general", "advisor", "elephant", "horse", "rook",
	]
	for index: int in back_types.size():
		_append_piece(pieces, serials, side, back_types[index], Vector2i(index + 1, back_y))
	for x: int in [2, 8]:
		_append_piece(pieces, serials, side, "cannon", Vector2i(x, cannon_y))
	for x: int in [1, 3, 5, 7, 9]:
		_append_piece(pieces, serials, side, "pawn", Vector2i(x, pawn_y))


func _append_piece(
	pieces: Array,
	serials: Dictionary,
	side: String,
	piece_type: String,
	position: Vector2i
) -> void:
	serials[piece_type] = int(serials.get(piece_type, 0)) + 1
	pieces.append({
		"id": "%s-%s-%d" % [side, piece_type, int(serials[piece_type])],
		"side": side,
		"piece_type": piece_type,
		"alive": true,
		"in_reserve": false,
		"position": [position.x, position.y],
	})


func _role_counts_match(rendered: Array) -> bool:
	var expected: Dictionary = {
		"pawn": 5, "cannon": 2, "rook": 2, "horse": 2,
		"elephant": 2, "advisor": 2, "general": 1,
	}
	for side: String in ["red", "black"]:
		var counts: Dictionary = {}
		for spec: Dictionary in rendered:
			if str(spec.get("side", "")) == side:
				var piece_type: String = str(spec.get("piece_type", ""))
				counts[piece_type] = int(counts.get(piece_type, 0)) + 1
		if counts != expected:
			return false
	return true


func _all_art_is_proportional_and_anchored(rendered: Array) -> bool:
	for spec: Dictionary in rendered:
		var source_size: Vector2 = spec.get("source_size", Vector2.ZERO)
		var rect: Rect2 = spec.get("rect", Rect2())
		var center: Vector2 = spec.get("center", Vector2.ZERO)
		var anchor_y: float = float(spec.get("anchor_y", 0.0))
		if source_size.x <= 0.0 or source_size.y <= 0.0 or rect.size.y <= 0.0:
			return false
		if not is_equal_approx(source_size.x / source_size.y, rect.size.x / rect.size.y):
			return false
		if not is_equal_approx(rect.position.y + rect.size.y * anchor_y, center.y):
			return false
	return true


func _rendered_ids(rendered: Array) -> Array[String]:
	var ids: Array[String] = []
	for spec: Dictionary in rendered:
		ids.append(str(spec.get("piece_id", "")))
	ids.sort()
	return ids


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
		return
	failures.append(description)
	push_error("FAIL: %s" % description)


func _capture_lan_view() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("LAN visual capture requires a windowed Godot session.")
		quit(2)
		return
	var side: String = "red"
	var output_path: String = "user://lan-terracotta-piece-red.png"
	var capture_size := Vector2i(1280, 720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-side="):
			side = argument.trim_prefix("--capture-side=")
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--size="):
			var parts: PackedStringArray = argument.trim_prefix("--size=").to_lower().split("x")
			if parts.size() == 2:
				capture_size = Vector2i(int(parts[0]), int(parts[1]))
	root.size = capture_size
	var lobby: Control = LAN_LOBBY.instantiate()
	root.add_child(lobby)
	await process_frame
	await process_frame
	var player_view: Dictionary = _full_visible_lan_view()
	player_view["viewer_side"] = side
	player_view["active_side"] = side
	var network_board: Control = lobby.get_node("NetworkBoard") as Control
	network_board.call("_on_network_player_view_received", player_view)
	lobby.call("_on_player_view_received", player_view)
	var title: Label = network_board.get_node(
		"SafeMargin/Page/HeaderPanel/HeaderMargin/HeaderRow/Title"
	) as Label
	title.text = "局域网真人对战 · %s" % ("红方房主" if side == "red" else "黑方客户端")
	await process_frame
	await process_frame
	var board_scroll: ScrollContainer = network_board.get_node(
		"SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/BoardScroll"
	) as ScrollContainer
	board_scroll.scroll_vertical = int(board_scroll.get_v_scroll_bar().max_value)
	await process_frame
	await process_frame
	var error: Error = root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("LAN visual capture failed: %s" % error_string(error))
		quit(1)
		return
	print("LAN_TERRACOTTA_PIECE_CAPTURE_SAVED side=%s path=%s" % [side, output_path])
	quit(0)


func _finish(board_shell: Node) -> void:
	board_shell.queue_free()
	await process_frame
	if failures.is_empty():
		print("LAN_TERRACOTTA_PIECE_VISUAL_CONTRACT_PASSED")
		quit(0)
		return
	print("LAN_TERRACOTTA_PIECE_VISUAL_CONTRACT_FAILED count=%d" % failures.size())
	quit(1)
