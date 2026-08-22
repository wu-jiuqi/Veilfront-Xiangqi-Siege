extends SceneTree

const BOARD_VIEWPORT_SCENE: PackedScene = preload(
	"res://scenes/game/match/board/board_viewport.tscn"
)
const VIEWPORT_SIZE: Vector2i = Vector2i(600, 544)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	root.add_child(viewport)
	var board_viewport := BOARD_VIEWPORT_SCENE.instantiate() as SubViewportContainer
	board_viewport.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(board_viewport)
	await process_frame

	await _check_own_move_keeps_camera(board_viewport)
	await _check_hidden_enemy_move_keeps_camera(board_viewport)
	await _check_visible_enemy_move_follows_piece(board_viewport)

	board_viewport.queue_free()
	viewport.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TURN_CAMERA_VISIBILITY_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TURN_CAMERA_VISIBILITY_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_own_move_keeps_camera(board_viewport: SubViewportContainer) -> void:
	board_viewport.clear_session_view()
	board_viewport.render_player_view(_turn_view(
		"red", "red", 0, Vector2i(5, 1), Vector2i(5, 16), true
	))
	await process_frame
	var camera_before_move: Vector2 = await _move_camera_away(board_viewport)
	board_viewport.render_player_view(_turn_view(
		"red", "black", 1, Vector2i(5, 2), Vector2i(5, 16), true
	))
	await process_frame
	var snapshot: Dictionary = board_viewport.get_render_snapshot()
	_expect(
		(snapshot.get("camera_position", Vector2.ZERO) as Vector2).is_equal_approx(
			camera_before_move
		),
		"own move reset or moved the player's camera"
	)
	_expect(
		not bool(snapshot.get("camera_motion_active", true)),
		"own move started automatic camera motion"
	)


func _check_hidden_enemy_move_keeps_camera(
	board_viewport: SubViewportContainer
) -> void:
	board_viewport.clear_session_view()
	board_viewport.render_player_view(_turn_view(
		"red", "black", 0, Vector2i(5, 1), Vector2i.ZERO, false
	))
	await process_frame
	var camera_before_move: Vector2 = await _move_camera_away(board_viewport)
	board_viewport.render_player_view(_turn_view(
		"red", "red", 1, Vector2i(5, 1), Vector2i.ZERO, false
	))
	await process_frame
	var snapshot: Dictionary = board_viewport.get_render_snapshot()
	_expect(
		(snapshot.get("camera_position", Vector2.ZERO) as Vector2).is_equal_approx(
			camera_before_move
		),
		"hidden enemy move reset or moved the player's camera"
	)
	_expect(
		not bool(snapshot.get("camera_motion_active", true)),
		"hidden enemy move started automatic camera motion"
	)


func _check_visible_enemy_move_follows_piece(
	board_viewport: SubViewportContainer
) -> void:
	board_viewport.clear_session_view()
	board_viewport.render_player_view(_turn_view(
		"red", "black", 0, Vector2i(5, 1), Vector2i(5, 16), true
	))
	await process_frame
	var camera_before_move: Vector2 = await _move_camera_away(board_viewport)
	board_viewport.render_player_view(_turn_view(
		"red", "red", 1, Vector2i(5, 1), Vector2i(5, 20), true
	))
	await process_frame
	var motion_snapshot: Dictionary = board_viewport.get_render_snapshot()
	_expect(
		bool(motion_snapshot.get("camera_motion_active", false)),
		"visible enemy move did not start automatic camera motion"
	)
	await create_timer(0.4).timeout
	var camera_after_move: Vector2 = board_viewport.get_render_snapshot().get(
		"camera_position", Vector2.ZERO
	) as Vector2
	_expect(
		camera_after_move.distance_to(camera_before_move) > 1.0,
		"visible enemy move did not move the camera toward that piece"
	)


func _move_camera_away(board_viewport: SubViewportContainer) -> Vector2:
	board_viewport.navigate_to_overview_ratio(Vector2(0.18, 0.18))
	await create_timer(0.2).timeout
	return board_viewport.get_render_snapshot().get("camera_position", Vector2.ZERO) as Vector2


func _turn_view(
	viewer_side: String,
	active_side: String,
	action_index: int,
	own_position: Vector2i,
	enemy_position: Vector2i,
	include_enemy: bool
) -> Dictionary:
	var pieces: Array[Dictionary] = [{
		"alive": true,
		"id": "%s-camera-general" % viewer_side,
		"in_reserve": false,
		"piece_type": "general",
		"position": [own_position.x, own_position.y],
		"side": viewer_side,
		"status_tags": ["owned"],
	}]
	var visible_cells: Array = [[own_position.x, own_position.y]]
	if include_enemy:
		var enemy_side: String = "black" if viewer_side == "red" else "red"
		pieces.append({
			"alive": true,
			"id": "%s-camera-rook" % enemy_side,
			"in_reserve": false,
			"piece_type": "rook",
			"position": [enemy_position.x, enemy_position.y],
			"side": enemy_side,
			"status_tags": ["visible"],
		})
		visible_cells.append([enemy_position.x, enemy_position.y])
	return {
		"viewer_side": viewer_side,
		"active_side": active_side,
		"action_index": action_index,
		"board": {"width": 9, "height": 24},
		"visible_cells": visible_cells,
		"hidden_detection_cells": [],
		"pieces": pieces,
		"flags": [],
		"walls": [],
		"capture_ghosts": [],
		"vision_overlays": {},
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
