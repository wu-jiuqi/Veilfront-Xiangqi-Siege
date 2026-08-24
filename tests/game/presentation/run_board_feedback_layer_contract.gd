extends SceneTree

const BOARD_VIEWPORT_SCENE: PackedScene = preload(
	"res://scenes/game/match/board/board_viewport.tscn"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := SubViewport.new()
	host.size = Vector2i(640, 540)
	root.add_child(host)
	var board_viewport := BOARD_VIEWPORT_SCENE.instantiate() as SubViewportContainer
	var board_sub_viewport := board_viewport.get_node("BoardSubViewport") as SubViewport
	board_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	board_viewport.size = Vector2(host.size)
	host.add_child(board_viewport)
	await process_frame

	var board_world := board_sub_viewport.get_node("BoardWorld") as Node2D
	var feedback_layer := board_sub_viewport.get_node_or_null("BoardFeedbackLayer") as Node2D
	_expect(feedback_layer != null, "main BoardViewport is missing BoardFeedbackLayer")
	_expect(
		board_world.get_node_or_null("BoardFeedbackLayer") == null,
		"BoardFeedbackLayer was embedded into minimap-reusable BoardWorld"
	)
	_expect(
		feedback_layer != null and feedback_layer.get_parent() == board_sub_viewport,
		"BoardFeedbackLayer is not a direct BoardSubViewport child"
	)

	var emitter_pool: BoardAudioEmitterPool = board_viewport.get_board_audio_emitter_pool()
	var vfx_director: VfxDirector = board_viewport.get_vfx_director()
	_expect(emitter_pool != null, "board audio emitter getter returned null")
	_expect(vfx_director != null, "VFX director getter returned null")
	_expect(
		emitter_pool == feedback_layer.get_node_or_null("BoardAudioEmitterPool"),
		"board audio emitter getter did not expose the preset instance"
	)
	_expect(
		vfx_director == feedback_layer.get_node_or_null("VfxRoot"),
		"VFX director getter did not expose the preset instance"
	)
	_expect(emitter_pool.preset_player_count() == 8, "board audio preset pool is not 8")
	var pool_snapshot: Dictionary = vfx_director.get_pool_snapshot()
	_expect(
		int(pool_snapshot.get("world_slot_count", -1)) == 9
		and int(pool_snapshot.get("global_slot_count", -1)) == 3,
		"VFX preset pool is not 9 world + 3 global"
	)

	board_viewport.set_presentation_side("black")
	_expect(emitter_pool.presentation_side == "black", "audio side did not sync to black")
	_expect(vfx_director.display_side == "black", "VFX side did not sync to black")

	var resized_theme := (board_world.board_theme as BoardTheme).duplicate(true) as BoardTheme
	resized_theme.cell_size = Vector2(96.0, 112.0)
	board_viewport.set_presentation_assets(resized_theme, board_world.map_option as BoardMapOption)
	_expect(
		emitter_pool.cell_size == resized_theme.cell_size,
		"audio cell size did not sync from BoardWorld"
	)
	_expect(
		vfx_director.cell_size == resized_theme.cell_size,
		"VFX cell size did not sync from BoardWorld"
	)

	board_viewport.queue_free()
	host.queue_free()
	await process_frame
	if _failures.is_empty():
		print(
			"BOARD_FEEDBACK_LAYER_CONTRACT_PASS audio_pool=8 vfx_pool=9+3 "
			+ "side_sync=true cell_size_sync=true minimap_isolation=true"
		)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("BOARD_FEEDBACK_LAYER_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
