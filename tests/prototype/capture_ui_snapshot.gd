extends SceneTree

const MAIN_SCENE := preload("res://scenes/prototype/gate1_logic_lab.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI snapshot requires a windowed Godot session.")
		quit(2)
		return
	var capture_size := Vector2i(1280, 720)
	var output_path: String = "user://gate1-ui-snapshot.png"
	var scroll_position: String = "top"
	var overlay_demo: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--size="):
			var size_parts: PackedStringArray = argument.trim_prefix("--size=").to_lower().split("x")
			if size_parts.size() == 2:
				capture_size = Vector2i(int(size_parts[0]), int(size_parts[1]))
		elif argument.begins_with("--scroll="):
			scroll_position = argument.trim_prefix("--scroll=")
		elif argument == "--overlay-demo":
			overlay_demo = true
	root.size = capture_size
	var scene := MAIN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	if overlay_demo:
		var surface := scene.get_node(
			"SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/BoardScroll/BoardSurface"
		) as Control
		var demo_view: Dictionary = scene.get_player_view_snapshot()
		demo_view["vision_overlays"] = {
			"rook_paths": [{
				"piece_id": "red-rook-demo",
				"cells": [[5, 9], [5, 10], [5, 11], [5, 12], [5, 13], [5, 14]],
			}],
			"elephant_reveal_zones": [{
				"piece_id": "red-elephant-demo",
				"cells": [[1, 9], [2, 9], [3, 9], [4, 9], [5, 9]],
			}],
			"elephant_block_fields": [{
				"piece_id": "red-elephant-demo",
				"cells": [
					[2, 10], [3, 10], [4, 10],
					[2, 11], [3, 11], [4, 11],
					[2, 12], [3, 12], [4, 12],
				],
			}],
		}
		surface.set_board_data(demo_view, [], "", [], "move", false)
		await process_frame
	if scroll_position != "top":
		var board_scroll := scene.get_node(
			"SafeMargin/Page/Workspace/BoardShell/BoardMargin/BoardColumn/BoardScroll"
		) as ScrollContainer
		var maximum_scroll: int = int(board_scroll.get_v_scroll_bar().max_value)
		board_scroll.scroll_vertical = maximum_scroll if scroll_position == "bottom" else maximum_scroll / 2
		await process_frame
	var error: Error = root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("UI snapshot save failed: %s" % error_string(error))
		quit(1)
		return
	print("UI_SNAPSHOT_SAVED path=%s" % output_path)
	quit(0)
