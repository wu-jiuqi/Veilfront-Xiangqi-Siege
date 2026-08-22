extends SceneTree

const SCENE_PATHS: Array[String] = [
	"res://scenes/game/app/game_app.tscn",
	"res://scenes/game/match/match_screen.tscn",
	"res://scenes/game/tutorial/tutorial_level.tscn",
]

const COMPONENT_SCENE_PATHS: Array[String] = [
	"res://scenes/game/match/board/board_viewport.tscn",
	"res://scenes/game/match/board/board_world.tscn",
	"res://scenes/game/match/board/fog_overlay.tscn",
	"res://scenes/game/match/board/marker_overlay.tscn",
	"res://scenes/game/match/board/tactical_overlay.tscn",
	"res://scenes/game/match/board/interaction_overlay.tscn",
	"res://scenes/game/match/board/piece_view.tscn",
	"res://scenes/game/match/board/flag_view.tscn",
	"res://scenes/game/match/board/capture_ghost_view.tscn",
	"res://scenes/game/match/board/wall_view.tscn",
	"res://scenes/game/ui/match_hud_v2.tscn",
	"res://scenes/game/ui/tactical_minimap.tscn",
	"res://scenes/game/ui/match_header.tscn",
	"res://scenes/game/ui/turn_progress_incense.tscn",
	"res://scenes/game/ui/match_status_panel.tscn",
	"res://scenes/game/ui/action_confirmation_panel.tscn",
	"res://scenes/game/ui/marker_menu.tscn",
	"res://scenes/game/ui/terminal_dialog.tscn",
	"res://scenes/game/ui/tutorial_overlay.tscn",
	"res://scenes/game/ui/tutorial_pause_menu.tscn",
]

const REQUIRED_INPUT_ACTIONS: Array[StringName] = [
	&"board_select",
	&"board_cancel_or_marker",
	&"board_confirm",
	&"board_pan_up",
	&"board_pan_down",
	&"board_pan_left",
	&"board_pan_right",
	&"board_zoom_in",
	&"board_zoom_out",
	&"tutorial_skip",
	&"ui_cancel",
]

const PURE_DRAW_OVERLAYS: Array[String] = [
	"FogOverlay",
	"MarkerOverlay",
	"TacticalOverlay",
	"InteractionOverlay",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_input_map()
	for scene_path: String in SCENE_PATHS:
		await _check_scene(scene_path)
	for scene_path: String in COMPONENT_SCENE_PATHS:
		await _check_component_scene(scene_path)
	_check_board_theme()

	if _failures.is_empty():
		print(
			"FORMAL_SCENE_SMOKE_PASS roots=%d components=%d inputs=%d"
			% [SCENE_PATHS.size(), COMPONENT_SCENE_PATHS.size(), REQUIRED_INPUT_ACTIONS.size()]
		)
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	print("FORMAL_SCENE_SMOKE_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_input_map() -> void:
	for action: StringName in REQUIRED_INPUT_ACTIONS:
		if not InputMap.has_action(action):
			_failures.append("missing Input Map action: %s" % action)

	_check_mouse_binding(&"board_select", MOUSE_BUTTON_LEFT)
	_check_mouse_binding(&"board_cancel_or_marker", MOUSE_BUTTON_RIGHT)
	_check_mouse_binding(&"board_zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_check_mouse_binding(&"board_zoom_out", MOUSE_BUTTON_WHEEL_DOWN)
	_check_key_binding(&"board_select", KEY_ENTER)
	_check_key_binding(&"board_cancel_or_marker", KEY_ESCAPE)
	_check_key_binding(&"board_confirm", KEY_SPACE)
	_check_key_binding(&"board_pan_up", KEY_W)
	_check_key_binding(&"board_pan_up", KEY_UP)
	_check_key_binding(&"board_pan_down", KEY_S)
	_check_key_binding(&"board_pan_down", KEY_DOWN)
	_check_key_binding(&"board_pan_left", KEY_A)
	_check_key_binding(&"board_pan_left", KEY_LEFT)
	_check_key_binding(&"board_pan_right", KEY_D)
	_check_key_binding(&"board_pan_right", KEY_RIGHT)
	_check_key_binding(&"board_zoom_in", KEY_PLUS)
	_check_key_binding(&"board_zoom_out", KEY_MINUS)
	_check_key_binding(&"tutorial_skip", KEY_T)
	_check_key_binding(&"ui_cancel", KEY_ESCAPE)


func _check_mouse_binding(action: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		return
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button_index:
			return
	_failures.append("missing mouse binding: %s -> %d" % [action, button_index])


func _check_key_binding(action: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action):
		return
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == physical_keycode:
			return
	_failures.append("missing key binding: %s -> %d" % [action, physical_keycode])


func _check_scene(scene_path: String) -> void:
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		_failures.append("scene failed to load: %s" % scene_path)
		return
	var instance: Node = packed_scene.instantiate()
	if instance == null:
		_failures.append("scene failed to instantiate: %s" % scene_path)
		return
	root.add_child(instance)
	await process_frame
	if scene_path.ends_with("game_app.tscn"):
		_check_game_app(instance)
	elif scene_path.ends_with("match_screen.tscn"):
		_check_match_screen(instance)
	elif scene_path.ends_with("tutorial_level.tscn"):
		_check_tutorial_level(instance)

	instance.queue_free()
	await process_frame


func _check_component_scene(scene_path: String) -> void:
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		_failures.append("component scene failed to load: %s" % scene_path)
		return
	var instance: Node = packed_scene.instantiate()
	if instance == null:
		_failures.append("component scene failed to instantiate: %s" % scene_path)
		return
	instance.free()


func _check_game_app(instance: Node) -> void:
	for required_path: String in [
		"ApplicationHost",
		"ScreenHost/MatchScreen",
		"GlobalOverlayHost/TransitionOverlay",
		"GlobalOverlayHost/FatalErrorDialog",
		"AccessibilityAnnouncer",
	]:
		if instance.get_node_or_null(required_path) == null:
			_failures.append("GameApp missing preset node: %s" % required_path)
	if instance is Control and instance.theme == null:
		_failures.append("GameApp must use a registered UI Theme")


func _check_match_screen(instance: Node) -> void:
	if instance.get_script() == null:
		_failures.append("MatchScreen controller script failed to load")
	for required_path: String in [
		"MatchHudV2",
		"MatchHudV2/BoardFrame/BoardViewport",
		"MatchHudV2/BoardFrame/BoardViewport/ScreenInputSurface",
		"MatchHudV2/FactionLeft",
		"MatchHudV2/FactionRight",
		"MatchHudV2/UnitInfo",
		"MatchHudV2/ObjectiveEvents",
		"MatchHudV2/Minimap/TacticalMinimap",
		"MatchHudV2/Minimap/TacticalMinimap/BirdEyeViewportContainer/BirdEyeViewport/BoardWorld",
		"MatchHudV2/PieceInfoDrawer",
		"MatchHudV2/IncenseTurnClock",
		"MatchHudV2/IncenseTurnClock/TimerIncenseSlot",
		"MatchHudV2/IncenseTurnClock/IncenseStandSlot",
		"MatchHudV2/IncenseTurnClock/RoundIncenseSlot",
		"MatchHudV2/IncenseTurnClock/RoundDisplaySlot",
		"MarkerMenu",
		"ActionConfirmationPanel",
		"TutorialOverlayHost",
		"TerminalDialog",
	]:
		if instance.get_node_or_null(required_path) == null:
			_failures.append("MatchScreen missing preset node: %s" % required_path)
	var board_world: Node = instance.get_node_or_null(
		"MatchHudV2/BoardFrame/BoardViewport/BoardSubViewport/BoardWorld"
	)
	if board_world == null:
		_failures.append("MatchScreen missing preset BoardWorld")
		return
	if _count_named_nodes(board_world, "FogOverlay") != 1:
		_failures.append("BoardWorld must contain exactly one FogOverlay")
	if _count_named_nodes(board_world, "InputSurface") != 1:
		_failures.append("BoardWorld must contain exactly one InputSurface")
	for overlay_name: String in PURE_DRAW_OVERLAYS:
		var overlay: Control = _find_named_node(board_world, overlay_name) as Control
		if overlay == null:
			_failures.append("BoardWorld missing overlay: %s" % overlay_name)
		elif overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_failures.append("pure draw overlay must ignore mouse: %s" % overlay_name)
	var input_surface: Control = _find_named_node(board_world, "InputSurface") as Control
	if input_surface != null:
		if input_surface.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_failures.append("nested BoardWorld InputSurface must defer to the screen interaction surface")
		if input_surface.focus_mode != Control.FOCUS_ALL:
			_failures.append("InputSurface must accept keyboard focus")
	var screen_input_surface: Control = instance.get_node_or_null(
		"MatchHudV2/BoardFrame/BoardViewport/ScreenInputSurface"
	) as Control
	if screen_input_surface == null:
		_failures.append("MatchScreen missing screen-space board interaction surface")
	elif screen_input_surface.mouse_filter != Control.MOUSE_FILTER_STOP:
		_failures.append("screen-space board interaction surface must stop GUI input")
	if _count_tree_nodes(board_world) >= 100:
		_failures.append("BoardWorld preset tree is unexpectedly large; do not create 216 cell nodes")


func _check_tutorial_level(instance: Node) -> void:
	for required_path: String in [
		"ApplicationHost",
		"MatchScreen",
		"TutorialOverlay",
		"TutorialDirector",
		"TutorialPauseMenu",
	]:
		if instance.get_node_or_null(required_path) == null:
			_failures.append("TutorialLevel missing preset node: %s" % required_path)
	var match_screen: Node = instance.get_node_or_null("MatchScreen")
	var pause_menu: Control = instance.get_node_or_null("TutorialPauseMenu") as Control
	if pause_menu != null:
		if pause_menu.process_mode != Node.PROCESS_MODE_ALWAYS:
			_failures.append("TutorialPauseMenu must process while the scene tree is paused")
		if pause_menu.visible:
			_failures.append("TutorialPauseMenu must start hidden")
		if match_screen != null and pause_menu.get_index() <= match_screen.get_index():
			_failures.append("TutorialPauseMenu must receive Escape before MatchScreen cancellation")


func _check_board_theme() -> void:
	var board_theme: Resource = load(
		"res://resources/game/content/boards/ancient_battlefield_board_theme.tres"
	)
	if board_theme == null:
		_failures.append("ancient battlefield BoardTheme failed to load")
		return
	var property_names: Array[String] = []
	for property: Dictionary in board_theme.get_property_list():
		property_names.append(str(property.get("name", "")))
	for forbidden: String in ["seed", "rng", "viewer", "full_state", "rules_revision"]:
		if forbidden in property_names:
			_failures.append("BoardTheme contains forbidden gameplay field: %s" % forbidden)
	if board_theme.get("wall_scene_set").is_empty():
		_failures.append("BoardTheme must map at least one wall PackedScene")
	if board_theme.get("piece_scene_set").is_empty():
		_failures.append("BoardTheme must map at least one piece PackedScene")
	if board_theme.get("flag_scene") == null:
		_failures.append("BoardTheme must map a flag PackedScene")
	if board_theme.get("ghost_scene") == null:
		_failures.append("BoardTheme must map a capture ghost PackedScene")
	var marker_assets: Dictionary = board_theme.get("marker_assets") as Dictionary
	if marker_assets.size() != 3:
		_failures.append("BoardTheme must map the three formal marker AtlasTextures")


func _count_named_nodes(node: Node, target_name: String) -> int:
	var count: int = 1 if node.name == target_name else 0
	for child: Node in node.get_children():
		count += _count_named_nodes(child, target_name)
	return count


func _find_named_node(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_named_node(child, target_name)
		if found != null:
			return found
	return null


func _count_tree_nodes(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _count_tree_nodes(child)
	return count
