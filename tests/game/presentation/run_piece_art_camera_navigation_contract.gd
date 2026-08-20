extends SceneTree

const TEST_SCENE: PackedScene = preload("res://scenes/dev/art/piece_art_test_3d.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_scene := TEST_SCENE.instantiate() as Node3D
	root.add_child(test_scene)
	await process_frame
	var rig := test_scene.get_node("CameraRig")
	var camera := test_scene.get_node("CameraRig/PitchPivot/Camera3D") as Camera3D
	_check_middle_drag_state(rig)
	_check_rotation_limits(rig, camera)
	_check_pan_limits(rig, camera)
	_check_zoom_limits(rig, camera)
	test_scene.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PIECE_ART_CAMERA_NAVIGATION_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("PIECE_ART_CAMERA_NAVIGATION_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_middle_drag_state(rig: Node) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	rig._unhandled_input(press)
	_expect(rig.is_orbit_dragging(), "middle mouse press must begin camera rotation")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_MIDDLE
	release.pressed = false
	rig._unhandled_input(release)
	_expect(not rig.is_orbit_dragging(), "middle mouse release must end camera rotation")


func _check_rotation_limits(rig: Node, camera: Camera3D) -> void:
	rig.apply_orbit_delta(Vector2(10000.0, 10000.0))
	_expect(camera.rotation_degrees.x >= rig.min_pitch_degrees - 0.01, "camera pitch must not expose the board underside")
	_expect(rig.rotation_degrees.y >= rig.min_yaw_degrees - 0.01, "camera yaw must keep the board within the navigation arc")
	rig.apply_orbit_delta(Vector2(-20000.0, -20000.0))
	_expect(camera.rotation_degrees.x <= rig.max_pitch_degrees + 0.01, "camera pitch must remain downward at the upper limit")
	_expect(rig.rotation_degrees.y <= rig.max_yaw_degrees + 0.01, "camera yaw must keep the board within the navigation arc")
	_expect(is_zero_approx(camera.rotation_degrees.z), "camera navigation must not introduce roll")


func _check_pan_limits(rig: Node3D, camera: Camera3D) -> void:
	var initial_height := rig.global_position.y
	rig.apply_pan_input(Vector2(1.0, 1.0), 1000.0)
	_expect(rig.global_position.x <= rig.pan_bounds_max.x, "camera target must stay inside the board right edge")
	_expect(rig.global_position.z <= rig.pan_bounds_max.y, "camera target must stay inside the board back edge")
	rig.apply_pan_input(Vector2(-1.0, -1.0), 2000.0)
	_expect(rig.global_position.x >= rig.pan_bounds_min.x, "camera target must stay inside the board left edge")
	_expect(rig.global_position.z >= rig.pan_bounds_min.y, "camera target must stay inside the board front edge")
	_expect(is_equal_approx(rig.global_position.y, initial_height), "WASD movement must remain on the board plane")
	_expect(camera.global_position.y > 0.22, "camera must remain above the board base")


func _check_zoom_limits(rig: Node, camera: Camera3D) -> void:
	_expect(InputMap.has_action(rig.zoom_in_action), "camera zoom-in action must exist in Input Map")
	_expect(InputMap.has_action(rig.zoom_out_action), "camera zoom-out action must exist in Input Map")
	var starting_distance: float = camera.position.length()
	var zoom_in_event := InputEventAction.new()
	zoom_in_event.action = rig.zoom_in_action
	zoom_in_event.pressed = true
	rig._unhandled_input(zoom_in_event)
	_expect(camera.position.length() < starting_distance, "mouse wheel up must move the camera closer to the board")
	var orbit_direction: Vector3 = camera.position.normalized()
	rig.apply_zoom_steps(1000.0)
	_expect(is_equal_approx(camera.position.length(), rig.min_zoom_distance), "zoom in must stop at the minimum distance")
	_expect(camera.position.normalized().dot(orbit_direction) > 0.999, "zoom must preserve the current orbit direction")
	rig.apply_zoom_steps(-2000.0)
	_expect(is_equal_approx(camera.position.length(), rig.max_zoom_distance), "zoom out must stop at the maximum distance")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
