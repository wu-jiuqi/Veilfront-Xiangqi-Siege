extends SceneTree

const BOARD_VIEWPORT_SCENE: PackedScene = preload(
	"res://scenes/game/match/board/board_viewport.tscn"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport: SubViewportContainer = BOARD_VIEWPORT_SCENE.instantiate()
	root.add_child(viewport)
	await process_frame
	await process_frame
	var input_surface: Control = viewport.get_node("ScreenInputSurface")
	var cell := Vector2i(4, 5)
	_hover(input_surface, viewport.get_container_position_for_authority_cell(cell))
	await process_frame
	_expect(
		str(viewport.get_render_snapshot().get("coordinate_text", "")) == "坐标：（4, 5）",
		"red presentation hover did not show authority coordinate"
	)

	input_surface.mouse_exited.emit()
	await process_frame
	_expect(
		str(viewport.get_render_snapshot().get("coordinate_text", "")) == "坐标：—",
		"coordinate readout did not clear away from an intersection"
	)

	viewport.set_presentation_side("black")
	viewport.focus_authority_cell(cell)
	await process_frame
	var mirrored_position: Vector2 = viewport.get_container_position_for_authority_cell(cell)
	_hover(input_surface, mirrored_position)
	await process_frame
	_expect(
		str(viewport.get_render_snapshot().get("coordinate_text", "")) == "坐标：（4, 5）",
		"mirrored presentation changed the authority coordinate readout"
	)

	if _failures.is_empty():
		print("BOARD_HOVER_COORDINATE_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _hover(input_surface: Control, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	input_surface.gui_input.emit(motion)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
