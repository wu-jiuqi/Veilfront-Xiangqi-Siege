extends SceneTree

const OVERLAY_SCENE: PackedScene = preload("res://scenes/game/ui/loading_transition_overlay.tscn")
const LOADING_OUTPUT := "res://evidence/ui/loading-transition-motion-v1-loading-1280x720.png"
const FAILURE_OUTPUT := "res://evidence/ui/loading-transition-motion-v1-failure-1280x720.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var overlay := OVERLAY_SCENE.instantiate() as Control
	viewport.add_child(overlay)
	for _frame: int in 3:
		await process_frame
	var failure_card := overlay.get_node("FailureLayer/FailureAnchor/FailureCard") as PanelContainer
	overlay.start_loading("正在同步迷雾边界…")
	overlay.set_progress(67.0)
	await create_timer(0.8).timeout
	var loading_result := await _save_viewport(viewport, LOADING_OUTPUT)
	overlay.show_failure("加载失败", "未能抵达战场", "场景资源响应超时，请重试。")
	await create_timer(0.8).timeout
	print("LOADING_TRANSITION_FAILURE_RECT position=%s size=%s min=%s margin_min=%s" % [failure_card.position, failure_card.size, failure_card.get_combined_minimum_size(), (failure_card.get_node("Margin") as Control).get_combined_minimum_size()])
	var failure_result := await _save_viewport(viewport, FAILURE_OUTPUT)
	var passed := loading_result == OK and failure_result == OK
	print(
		"LOADING_TRANSITION_PREVIEW_%s loading=%s failure=%s"
		% ["PASS" if passed else "FAIL", LOADING_OUTPUT, FAILURE_OUTPUT]
	)
	overlay.queue_free()
	viewport.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _save_viewport(viewport: SubViewport, output_path: String) -> Error:
	for _frame: int in 3:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/ui"))
	var viewport_texture := viewport.get_texture()
	if viewport_texture == null:
		return ERR_CANT_CREATE
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		return ERR_CANT_CREATE
	return image.save_png(ProjectSettings.globalize_path(output_path))
