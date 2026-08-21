extends RefCounted

const BoundaryScanner = preload("res://tests/game/architecture/check_dependency_boundaries.gd")


func run_suite() -> Dictionary:
	var failures: Array[String] = []
	var checks: int = 0
	var scanner: RefCounted = BoundaryScanner.new()

	checks += _expect_rule(
		scanner,
		"res://scripts/game/domain/bad_node.gd",
		"extends Node\n",
		"DOMAIN_GODOT_TYPE",
		failures
	)
	checks += _expect_rule(
		scanner,
		"res://scripts/game/domain/bad_dependency.gd",
		"extends RefCounted\nconst App = preload(\"res://scripts/game/application/match_application.gd\")\n",
		"DOMAIN_FORBIDDEN_DEPENDENCY",
		failures
	)
	checks += _expect_rule(
		scanner,
		"res://scripts/game/domain/bad_scene_load.gd",
		"extends RefCounted\nfunc build_scene() -> Resource:\n\treturn load(\"res://scenes/game/match/match_screen.tscn\")\n",
		"DOMAIN_FORBIDDEN_DEPENDENCY",
		failures
	)
	checks += _expect_rule(
		scanner,
		"res://scripts/game/application/bad_state_api.gd",
		"extends RefCounted\nfunc expose_state() -> FullState:\n\treturn null\n",
		"APPLICATION_AUTHORITY_API",
		failures
	)
	checks += _expect_rule(
		scanner,
		"res://scripts/game/application/bad_viewer_api.gd",
		"extends RefCounted\nfunc get_view(viewer_side: String) -> Dictionary:\n\treturn {}\n",
		"APPLICATION_VIEWER_API",
		failures
	)
	checks += _expect_rule(
		scanner,
		"res://scripts/game/projection/bad_viewer_api.gd",
		"extends RefCounted\nfunc project(viewer_side: String) -> Dictionary:\n\treturn {}\n",
		"PROJECTION_VIEWER_API",
		failures
	)
	checks += _expect_rule(
		scanner,
		"res://scripts/game/projection/bad_state_mutation.gd",
		"extends RefCounted\nfunc project(full_state: Dictionary) -> void:\n\tfull_state[\"active_side\"] = \"red\"\n",
		"PROJECTION_STATE_MUTATION",
		failures
	)
	checks += _expect_rule(
		scanner,
		"res://scripts/game/presentation/bad_raw_event.gd",
		"extends RefCounted\nfunc render(event: DomainEvent) -> void:\n\tpass\n",
		"CONSUMER_AUTHORITY_SYMBOL",
		failures
	)
	checks += _expect_rule(
		scanner,
		"res://scripts/game/tutorial/bad_domain_path.gd",
		"extends RefCounted\nconst Rules = preload(\"res://scripts/game/domain/rules.gd\")\n",
		"CONSUMER_FORBIDDEN_DEPENDENCY",
		failures
	)
	checks += _expect_rule(
		scanner,
		"res://scripts/game/ports/bad_seed_api.gd",
		"extends RefCounted\nfunc start(seed: int) -> void:\n\tpass\n",
		"PORT_AUTHORITY_API",
		failures
	)
	checks += _expect_rule(
		scanner,
		"res://scenes/game/app/bad_root.tscn",
		"[ext_resource type=\"Script\" path=\"res://scripts/prototype/network/lan_protocol.gd\" id=\"1\"]\n",
		"FORMAL_ASSET_PROTOTYPE_REFERENCE",
		failures
	)
	checks += _expect_rule(
		scanner,
		"res://scenes/game/app/bad_network.tscn",
		"[ext_resource type=\"PackedScene\" path=\"res://scenes/game/network/rogue_session.tscn\" id=\"1\"]\n",
		"FORMAL_ASSET_NETWORK_REFERENCE",
		failures
	)

	var safe_sources: Array[Dictionary] = [
		{
			"path": "res://scripts/game/domain/rules.gd",
			"source": "extends RefCounted\nfunc resolve(state: Dictionary, intent: Dictionary) -> Dictionary:\n\treturn state.duplicate(true)\n",
		},
		{
			"path": "res://scripts/game/application/match_application.gd",
			"source": "extends RefCounted\nfunc submit_intent(intent: Dictionary) -> Dictionary:\n\treturn intent\n",
		},
		{
			"path": "res://scripts/game/projection/player_view_projector.gd",
			"source": "extends RefCounted\nfunc project_player_view(state_snapshot: Dictionary, viewer_context: RefCounted) -> Dictionary:\n\treturn {}\n",
		},
		{
			"path": "res://scripts/game/presentation/match_screen_presenter.gd",
			"source": "extends RefCounted\n# FullState is forbidden here.\nfunc render_player_view(view: Dictionary) -> void:\n\tvar label: String = \"FullState is not a UI dependency\"\n\tprint(label, view.size())\n",
		},
		{
			"path": "res://scripts/game/tutorial/tutorial_director.gd",
			"source": "extends RefCounted\nfunc accept_visible_event(event: Dictionary) -> void:\n\tprint(event.get(\"message_key\", \"\"))\n",
		},
		{
			"path": "res://scripts/game/ports/match_client_port.gd",
			"source": "extends RefCounted\nsignal player_view_updated(view: Dictionary)\nfunc request_action_previews(piece_id: String) -> void:\n\tprint(piece_id)\n",
		},
		{
			"path": "res://scenes/game/app/formal_lan_game_app.tscn",
			"source": "[ext_resource type=\"PackedScene\" path=\"res://scenes/game/network/formal_lan_session.tscn\" id=\"1\"]\n",
		},
	]
	for sample: Dictionary in safe_sources:
		checks += 1
		var violations: Array = scanner.scan_text(str(sample["path"]), str(sample["source"]))
		if not violations.is_empty():
			failures.append("安全样例被误报 %s: %s" % [sample["path"], violations])

	return {
		"ok": failures.is_empty(),
		"checks": checks,
		"failures": failures,
	}


func _expect_rule(
	scanner: RefCounted,
	path: String,
	source: String,
	expected_rule_id: String,
	failures: Array[String]
) -> int:
	var violations: Array = scanner.scan_text(path, source)
	for violation: Dictionary in violations:
		if str(violation.get("rule_id", "")) == expected_rule_id:
			return 1
	failures.append("%s 未命中规则 %s，实际=%s" % [path, expected_rule_id, violations])
	return 1
