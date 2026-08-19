extends SceneTree

const PIECE_SCENE: PackedScene = preload("res://scenes/game/match/board_3d/piece_3d.tscn")
const TEST_SCENE: PackedScene = preload("res://scenes/dev/art/piece_art_test_3d.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_piece_scene()
	_check_test_scene()
	if _failures.is_empty():
		print("PIECE_ART_TEST_3D_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("PIECE_ART_TEST_3D_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_piece_scene() -> void:
	var piece: Node3D = PIECE_SCENE.instantiate() as Node3D
	var sprite: Sprite3D = piece.get_node("VisualPivot/Sprite3D") as Sprite3D
	_expect(sprite != null, "Piece3D must preset VisualPivot/Sprite3D")
	if sprite != null:
		_expect(sprite.billboard == 2, "Sprite3D must use Fixed-Y billboard mode")
		_expect(sprite.alpha_cut == 2, "Sprite3D must use Opaque Pre-Pass")
		_expect(not sprite.shaded, "Sprite3D must remain unshaded")
		_expect(not sprite.no_depth_test, "Sprite3D must keep depth testing")
		_expect(not sprite.fixed_size, "Sprite3D must not use fixed screen size")
		_expect(sprite.cast_shadow == 0, "Sprite3D must not cast realtime shadows")
		_expect(is_equal_approx(sprite.pixel_size, 0.00208333), "upright profile must target 1.6 world-unit canvas height")
		_expect(sprite.offset.is_equal_approx(Vector2(0, 337.92)), "upright profile must place the 0.94 foot anchor on the Node3D origin")
	_expect(piece.get_node_or_null("FakeShadow") is MeshInstance3D, "Piece3D must preset a fake shadow")
	_expect(piece.get_node_or_null("VisualPivot/FootAnchor") is Marker3D, "Piece3D must expose a foot anchor")
	var area: Area3D = piece.get_node_or_null("InteractionArea") as Area3D
	_expect(area != null, "Piece3D must preset an Area3D interaction surface")
	_expect(piece.get_node_or_null("InteractionArea/CollisionShape3D") is CollisionShape3D, "Area3D must own CollisionShape3D")
	_expect(piece.get_node_or_null("Feedback/SelectionRing") is MeshInstance3D, "Piece3D must preset selection feedback")
	piece.free()


func _check_test_scene() -> void:
	var test_scene: Node3D = TEST_SCENE.instantiate() as Node3D
	var board_base: MeshInstance3D = test_scene.get_node("Board3D/BoardBase") as MeshInstance3D
	var board_mesh: BoxMesh = board_base.mesh as BoxMesh
	_expect(board_mesh != null, "test scene must preset a BoxMesh board")
	if board_mesh != null:
		_expect(board_mesh.size.is_equal_approx(Vector3(11.4, 0.22, 29.4)), "board size must match the frozen 9x24 baseline")
	_expect(test_scene.get_node_or_null("WorldEnvironment") is WorldEnvironment, "test scene must preset WorldEnvironment")
	_expect(test_scene.get_node_or_null("Lighting/DirectionalLight3D") is DirectionalLight3D, "test scene must preset DirectionalLight3D")
	_expect(test_scene.get_node_or_null("Board3D/GridOverlay") is MeshInstance3D, "test scene must preset GridOverlay")
	_expect(test_scene.get_node_or_null("Board3D/FogSurface") is MeshInstance3D, "test scene must reserve one FogSurface")
	_expect(test_scene.get_node_or_null("Board3D/HighlightRoot") is MultiMeshInstance3D, "test scene must reserve HighlightRoot")
	var piece_root: Node3D = test_scene.get_node("PieceRoot") as Node3D
	_expect(piece_root.get_child_count() == 6, "test scene must provide six near/middle/far overlap slots")
	var camera: Camera3D = test_scene.get_node("CameraRig/PitchPivot/Camera3D") as Camera3D
	_expect(is_equal_approx(camera.fov, 30.0), "test camera must use the frozen 30 degree FOV")
	_expect(camera.rotation_degrees.x >= -55.0 and camera.rotation_degrees.x <= -45.0, "test camera pitch must stay inside the 45-55 degree calibration band")
	test_scene.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
