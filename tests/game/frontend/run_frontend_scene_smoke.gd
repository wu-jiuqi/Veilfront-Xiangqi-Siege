extends SceneTree

const CATALOG := preload("res://resources/game/levels/level_catalog.tres")


func _init() -> void:
	var start_scene := load("res://scenes/game/frontend/start_screen.tscn") as PackedScene
	var level_scene := load("res://scenes/game/frontend/level_select.tscn") as PackedScene
	assert(start_scene != null, "start screen scene must load")
	assert(level_scene != null, "level select scene must load")
	assert(not FileAccess.file_exists("res://scenes/game/frontend/main_menu.tscn"), "legacy main menu scene must be removed")
	assert(not FileAccess.file_exists("res://scripts/game/frontend/main_menu.gd"), "legacy main menu script must be removed")
	assert(not FileAccess.file_exists("res://scripts/game/frontend/main_menu.gd.uid"), "legacy main menu script UID must be removed")
	assert(CATALOG.levels.size() == 14, "catalog must contain T0-T10 and C1-C3")
	assert(CATALOG.find_level("T0").available, "T0 must be available")
	assert(CATALOG.find_level("T1").unlock_after == "T0", "tutorial unlock chain must start at T0")
	assert(CATALOG.find_level("C1").category == "challenge", "C1 must be a challenge")

	var start_root := start_scene.instantiate()
	root.add_child(start_root)
	await process_frame
	var enter_prompt := start_root.get_node("%EnterPrompt") as Label
	var prompt_animation := start_root.get_node("%PromptAnimation") as AnimationPlayer
	var sequence_player := start_root.get_node("%SequencePlayer") as AnimationPlayer
	assert(enter_prompt.text == "点击任意位置继续")
	assert(start_root.get_node("Stage/Environment").texture.resource_path == "res://assets/art/ui/start_sequence/gate_environment_open_v1.png")
	assert(sequence_player.has_animation(&"opening_sequence"))
	assert(is_equal_approx(sequence_player.get_animation(&"opening_sequence").length, 4.85))
	assert(start_root.get_node("Stage/DoorLayer/LeftDoor").texture.resource_path == "res://assets/art/ui/start_sequence/gate_left_door_v2.png")
	assert(start_root.get_node("Stage/DoorLayer/RightDoor").texture.resource_path == "res://assets/art/ui/start_sequence/gate_right_door_v2.png")
	var menu_overlay := start_root.get_node("MenuOverlay")
	var mist_character_texture := menu_overlay.get_node("UiRoot/MistCharacter").texture as AtlasTexture
	var frontier_character_texture := menu_overlay.get_node("UiRoot/FrontierCharacter").texture as AtlasTexture
	assert(mist_character_texture != null)
	assert(frontier_character_texture != null)
	assert(mist_character_texture.atlas.resource_path == "res://assets/art/ui/start_sequence/veilfront_logo_gold_pair_v2.png")
	assert(frontier_character_texture.atlas == mist_character_texture.atlas)
	assert(mist_character_texture.region == Rect2(0.0, 0.0, 887.0, 887.0))
	assert(frontier_character_texture.region == Rect2(887.0, 0.0, 887.0, 887.0))
	assert(mist_character_texture != frontier_character_texture, "title characters must use independent atlas regions")
	var settings_button := menu_overlay.get_node("UiRoot/SettingsButton") as Button
	var mist_character := menu_overlay.get_node("UiRoot/MistCharacter") as TextureRect
	var frontier_character := menu_overlay.get_node("UiRoot/FrontierCharacter") as TextureRect
	var game_subtitle := menu_overlay.get_node("UiRoot/GameSubtitle") as TextureRect
	assert(_anchors_match(settings_button, Rect2(0.0125, 0.022222, 0.05, 0.088889)))
	assert(settings_button.text.is_empty(), "settings shield button must not render a text label")
	assert(settings_button.icon.resource_path == "res://assets/art/ui/start_sequence/settings_infantry_shield_gear_v1.png")
	assert(settings_button.tooltip_text == "设置")
	_assert_true_alpha("res://assets/art/ui/start_sequence/settings_infantry_shield_gear_v1.png")
	assert(_anchors_match(mist_character, Rect2(0.3875, 0.166667, 0.19, 0.32)))
	assert(_is_vector_near(mist_character.pivot_offset, Vector2(121.6, 115.2)))
	assert(_anchors_match(frontier_character, Rect2(0.4125, 0.477778, 0.18125, 0.311111)))
	assert(_is_vector_near(frontier_character.pivot_offset, Vector2(116.0, 112.0)))
	assert(_anchors_match(game_subtitle, Rect2(0.55, 0.688889, 0.0625, 0.111111)))
	assert(_is_vector_near(game_subtitle.pivot_offset, Vector2(40.0, 40.0)))
	assert(menu_overlay.get_node("UiRoot/GameSubtitle").texture.resource_path == "res://assets/art/ui/start_sequence/veilfront_subtitle_square_seal_v2.png")
	assert(menu_overlay.get_node("UiRoot/ImpactMist") is ColorRect, "title impacts must use a fog disturbance layer")
	assert(menu_overlay.get_node("UiRoot/MenuPanel/LanButton").text == "联机对战")
	assert(menu_overlay.get_node("UiRoot/MenuPanel/LevelModeButton").text == "关卡模式")
	assert(menu_overlay.get_node("UiRoot/MenuPanel/CommunityButton").text == "社群")
	assert(menu_overlay.get_node("UiRoot/MenuPanel/QuitButton").text == "退出游戏")
	var sword_button_texture := load("res://assets/art/ui/start_sequence/menu_bronze_sword_button_v1.png") as Texture2D
	assert(sword_button_texture != null, "bronze sword menu texture must load")
	var menu_panel := menu_overlay.get_node("UiRoot/MenuPanel") as VBoxContainer
	assert(_anchors_match(menu_panel, Rect2(0.73125, 0.2, 0.25625, 0.555556)))
	for spacer_name: String in ["LanLevelSpacer", "LevelCommunitySpacer", "CommunityQuitSpacer"]:
		var spacer := menu_panel.get_node(spacer_name) as Control
		assert(_is_vector_near(spacer.custom_minimum_size, Vector2(0.0, 37.3333)), "%s must preserve equal sword spacing" % spacer_name)
	for button_name: String in ["LanButton", "LevelModeButton", "CommunityButton", "QuitButton"]:
		var sword_button := menu_overlay.get_node("UiRoot/MenuPanel/%s" % button_name) as Button
		assert(sword_button.offset_transform_enabled, "%s must use visual-only entry motion" % button_name)
		assert(_is_vector_near(sword_button.custom_minimum_size, Vector2(0.0, 72.0)), "%s must match the authored layout height" % button_name)
		assert(sword_button.get_theme_stylebox(&"normal") is StyleBoxTexture, "%s must use the bronze sword texture style" % button_name)
		assert((sword_button.get_theme_stylebox(&"normal") as StyleBoxTexture).texture.resource_path == sword_button_texture.resource_path)
	var impact_material := menu_overlay.get_node("UiRoot/ImpactMist").material as ShaderMaterial
	var initial_impact_center: Vector2 = impact_material.get_shader_parameter(&"impact_center")
	assert(initial_impact_center.is_equal_approx(Vector2(0.4825, 0.326667)), "impact mist must start at the relocated mist character")
	var menu_intro := (menu_overlay.get_node("MenuIntroPlayer") as AnimationPlayer).get_animation(&"menu_intro")
	var impact_center_track := menu_intro.find_track(NodePath("UiRoot/ImpactMist:material:shader_parameter/impact_center"), Animation.TYPE_VALUE)
	assert(impact_center_track >= 0, "menu intro must animate the impact center")
	var expected_impact_centers: Array[Vector2] = [
		Vector2(0.4825, 0.326667),
		Vector2(0.4825, 0.326667),
		Vector2(0.503125, 0.633333),
		Vector2(0.58125, 0.744444),
	]
	for key_index: int in expected_impact_centers.size():
		var impact_center: Vector2 = menu_intro.track_get_key_value(impact_center_track, key_index)
		assert(impact_center.is_equal_approx(expected_impact_centers[key_index]), "impact mist key %d must follow the authored logo position" % key_index)
	var fog_shader := load("res://assets/shaders/ui/gate_fog_curtain.gdshader") as Shader
	assert(fog_shader.code.contains("random_gradient"), "fog must use smooth gradient noise instead of moving square cells")
	assert(fog_shader.code.contains("vec2 warp"), "fog must use a domain-warped irregular flow field")
	assert(fog_shader.code.contains("density_boost"), "fog must expose a persistent density control")
	assert(fog_shader.code.contains("full_screen_lock"), "fully revealed fog must cover the complete viewport")
	assert(fog_shader.code.contains("drift_amplitude"), "fog must expose a broad irregular drift control")
	var impact_mist_shader := load("res://assets/shaders/ui/title_impact_mist.gdshader") as Shader
	assert(impact_mist_shader.code.contains("impact_strength"), "title impacts must drive an irregular fog pulse")
	var door_shader := load("res://assets/shaders/ui/gate_door_open.gdshader") as Shader
	assert(door_shader.code.contains("edge_feather_pixels"), "door edges must be feathered into the gate frame")
	assert(door_shader.code.contains("shadow_lift"), "door shadows must be lifted so the general and marshal marks remain readable")
	var prompt_font := enter_prompt.get_theme_font(&"font") as FontVariation
	assert(prompt_font.resource_path == "res://resources/game/ui/start_prompt_font.tres")
	assert(prompt_font.base_font.resource_path == "res://assets/fonts/ramega_zhang_qingping/ramega_zhang_qingping_xingshu.ttf")
	for character: String in enter_prompt.text:
		assert(prompt_font.has_char(character.unicode_at(0)), "start prompt font must contain character: %s" % character)
	assert(enter_prompt.get_theme_font_size(&"font_size") == 32)
	var prompt_color := enter_prompt.get_theme_color(&"font_color")
	assert(prompt_color.r > prompt_color.g and prompt_color.g > prompt_color.b, "start prompt must use a pale gold color")
	var blink_animation := prompt_animation.get_animation(&"prompt_blink")
	assert(blink_animation.loop_mode == Animation.LOOP_LINEAR)
	assert(is_equal_approx(blink_animation.length, 1.8))
	prompt_animation.pause()
	prompt_animation.seek(0.0, true)
	var bright_alpha := enter_prompt.modulate.a
	prompt_animation.seek(0.9, true)
	assert(enter_prompt.modulate.a < bright_alpha, "start prompt animation must blink by reducing alpha")
	start_root.queue_free()
	await process_frame

	var level_root := level_scene.instantiate()
	root.add_child(level_root)
	await process_frame
	assert(level_root.get_node("%TutorialGrid").get_child_count() == 11)
	assert(level_root.get_node("%ChallengeGrid").get_child_count() == 3)
	for card: Control in level_root.get_node("%TutorialGrid").get_children():
		assert(not card.get_node("%NodeButton").disabled, "tutorial test node must be open")
	for card: Control in level_root.get_node("%ChallengeGrid").get_children():
		assert(not card.get_node("%NodeButton").disabled, "challenge test node must be open")
	assert(level_root.get_node("DesignCanvas/CampaignBackground").texture.resource_path == "res://assets/art/ui/level_select/level_select_empty_background_v2.png")
	assert(level_root.get_node("%DetailCode").text == "T0")
	assert(level_root.get_node("%EnterButton").size.y >= 44.0)
	var first_node_texture := level_root.get_node("%TutorialGrid").get_child(0).get_node("%SelectedState").texture as Texture2D
	assert(first_node_texture.resource_path == "res://assets/art/ui/level_select/components/node_selected_v2.png")
	assert(level_root.get_node("%BackButton").focus_mode != Control.FOCUS_NONE)
	print("FRONTEND_SCENE_SMOKE_PASS catalog=14 tutorial=11 challenge=3 level_ui=approved_master_v2")
	quit()


func _is_vector_near(actual: Vector2, expected: Vector2, tolerance: float = 0.01) -> bool:
	return actual.distance_to(expected) <= tolerance


func _anchors_match(control: Control, expected: Rect2, tolerance: float = 0.000001) -> bool:
	return (
		absf(control.anchor_left - expected.position.x) <= tolerance
		and absf(control.anchor_top - expected.position.y) <= tolerance
		and absf(control.anchor_right - expected.end.x) <= tolerance
		and absf(control.anchor_bottom - expected.end.y) <= tolerance
	)


func _assert_true_alpha(texture_path: String) -> void:
	var texture := load(texture_path) as Texture2D
	assert(texture != null, "settings shield texture must load")
	var image := texture.get_image()
	assert(image != null and not image.is_empty(), "settings shield must expose imported pixels")
	assert(image.detect_alpha() != Image.ALPHA_NONE, "settings shield must keep chroma-key alpha")
	assert(image.get_pixel(0, 0).a <= 0.05, "settings shield corner must be transparent")
	assert(image.get_pixel(image.get_width() / 2, image.get_height() / 2).a >= 0.95, "settings shield center must remain opaque")
