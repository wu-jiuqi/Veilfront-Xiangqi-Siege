extends SceneTree

const BOARD_WORLD_SCENE: PackedScene = preload(
	"res://scenes/game/match/board/board_world.tscn"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var board_world: Node2D = BOARD_WORLD_SCENE.instantiate() as Node2D
	root.add_child(board_world)
	var red_rook := _piece("red-rook", "red", "rook", Vector2i(5, 20))
	var black_pawn := _piece("black-pawn", "black", "pawn", Vector2i(5, 18))
	board_world.call("render_player_view", _view([red_rook, black_pawn]))
	await process_frame
	_expect(
		(board_world.call("get_render_snapshot") as Dictionary).get("piece_animation_events", []).is_empty(),
		"initial board population should not replay landing tweens for every piece"
	)

	board_world.call("set_interaction", Vector2i(5, 20), [])
	var selected_snapshot: Dictionary = board_world.call("get_render_snapshot")
	_expect(int(selected_snapshot.get("selected_piece_count", 0)) == 1, "selected piece did not start its halo tween")
	board_world.call("clear_interaction")
	_expect(
		int((board_world.call("get_render_snapshot") as Dictionary).get("selected_piece_count", -1)) == 0,
		"clearing interaction did not stop the selection tween"
	)

	red_rook["position"] = [5, 19]
	board_world.call("render_player_view", _view([red_rook, black_pawn]))
	var move_snapshot: Dictionary = board_world.call("get_render_snapshot")
	_expect(_has_event(move_snapshot, "move", "red-rook"), "normal move tween event was not emitted")
	var piece_renderer := board_world.get_node("PieceLayer")
	_expect(
		str((piece_renderer.call("get_piece_animation_snapshot", "red-rook") as Dictionary).get("kind", "")) == "move",
		"moving piece did not enter the move animation state"
	)
	await create_timer(0.42).timeout
	_expect(
		str((piece_renderer.call("get_piece_animation_snapshot", "red-rook") as Dictionary).get("kind", "")) == "idle",
		"move tween did not settle back to idle"
	)

	red_rook["position"] = [5, 18]
	black_pawn["alive"] = false
	black_pawn["position"] = []
	board_world.call("render_player_view", _view([red_rook, black_pawn]))
	var capture_snapshot: Dictionary = board_world.call("get_render_snapshot")
	_expect(_has_event(capture_snapshot, "capture", "red-rook"), "capturing piece did not play the eat tween")
	_expect(_has_event(capture_snapshot, "captured", "black-pawn"), "captured piece did not play its removal tween")
	await create_timer(0.56).timeout
	_expect(piece_renderer.get_child_count() == 1, "captured piece view was not freed after its tween")

	var landed_guard := _piece("red-guard", "red", "advisor", Vector2i(4, 20))
	board_world.call("render_player_view", _view([red_rook, black_pawn, landed_guard]))
	var land_snapshot: Dictionary = board_world.call("get_render_snapshot")
	_expect(_has_event(land_snapshot, "land", "red-guard"), "new board piece did not play the landing tween")
	_expect(
		str((piece_renderer.call("get_piece_animation_snapshot", "red-guard") as Dictionary).get("kind", "")) == "land",
		"new board piece did not enter the landing animation state"
	)
	await create_timer(0.42).timeout
	_expect(
		str((piece_renderer.call("get_piece_animation_snapshot", "red-guard") as Dictionary).get("kind", "")) == "idle",
		"landing tween did not settle back to idle"
	)

	board_world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PIECE_TWEEN_ANIMATION_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("PIECE_TWEEN_ANIMATION_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _piece(piece_id: String, side: String, piece_type: String, cell: Vector2i) -> Dictionary:
	return {
		"alive": true,
		"id": piece_id,
		"in_reserve": false,
		"piece_type": piece_type,
		"position": [cell.x, cell.y],
		"side": side,
		"status_tags": [],
	}


func _view(pieces: Array) -> Dictionary:
	return {
		"viewer_side": "red",
		"board": {"width": 9, "height": 24},
		"pieces": pieces,
		"flags": [],
		"walls": [],
	}


func _has_event(snapshot: Dictionary, kind: String, piece_id: String) -> bool:
	for event_value: Variant in snapshot.get("piece_animation_events", []):
		if event_value is Dictionary \
		and str(event_value.get("kind", "")) == kind \
		and str(event_value.get("piece_id", "")) == piece_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
