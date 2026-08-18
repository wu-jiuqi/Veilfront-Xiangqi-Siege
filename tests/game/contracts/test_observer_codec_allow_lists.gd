extends RefCounted

const PlayerViewCodec = preload("res://scripts/game/contracts/player_view_codec.gd")
const VisibleEventCodec = preload("res://scripts/game/contracts/visible_event_codec.gd")
const VisibleErrorCodec = preload("res://scripts/game/contracts/visible_error_codec.gd")
const ActionPreviewCodec = preload("res://scripts/game/contracts/action_preview_codec.gd")
const FixtureMatchClientPort = preload("res://tests/game/contracts/fixture_match_client_port.gd")

const RED_FIXTURE_PATH: String = "res://tests/game/contracts/fixtures/red_player_view_minimal_v1.json"
const BLACK_FIXTURE_PATH: String = "res://tests/game/contracts/fixtures/black_player_view_minimal_v1.json"

const VISIBLE_EVENT_JSON: String = "{\"action_index\":0,\"actor_side_public\":\"red\",\"event_type\":\"fixture.ready\",\"message_key\":\"fixture.ready\",\"piece_public\":{},\"position_public\":[],\"public_payload\":{},\"schema_version\":\"veilfront-visible-event-v1\",\"timing_bucket\":\"immediate\",\"visible_sequence\":1}"
const VISIBLE_ERROR_JSON: String = "{\"action_index\":0,\"consumed\":false,\"intent_id\":\"fixture-intent\",\"message_key\":\"action.invalid_request\",\"public_code\":\"invalid_request\",\"resolution\":\"rejected_without_consumption\",\"schema_version\":\"veilfront-visible-error-v1\",\"timing_bucket\":\"immediate\"}"
const ACTION_PREVIEW_JSON: String = "{\"action_type\":\"move\",\"classification\":\"KNOWN_LEGAL\",\"confirmation_required\":true,\"message_key\":\"action.move\",\"piece_id\":\"fixture-piece\",\"preview_id\":\"fixture-preview\",\"public_cost\":{},\"schema_version\":\"veilfront-action-preview-v1\",\"skill_type\":\"\",\"target_cell\":[1,1]}"


func run_suite() -> Dictionary:
	var failures: Array[String] = []
	var checks: int = 0
	var red_json: String = _read_fixture(RED_FIXTURE_PATH, failures)
	var black_json: String = _read_fixture(BLACK_FIXTURE_PATH, failures)

	checks += _expect_round_trip(PlayerViewCodec, red_json, "red PlayerView", failures)
	checks += _expect_round_trip(PlayerViewCodec, black_json, "black PlayerView", failures)
	checks += _expect_round_trip(VisibleEventCodec, VISIBLE_EVENT_JSON, "VisibleEvent", failures)
	checks += _expect_round_trip(VisibleErrorCodec, VISIBLE_ERROR_JSON, "VisibleError", failures)
	checks += _expect_round_trip(ActionPreviewCodec, ACTION_PREVIEW_JSON, "ActionPreview", failures)

	for forbidden_field: String in ["seed", "position", "private_marker", "raw_sequence"]:
		checks += _expect_root_field_rejected(red_json, forbidden_field, failures)
	checks += _expect_decode_rejected(
		PlayerViewCodec,
		"{\"schema_version\":\"veilfront-player-view-v1\"," + red_json.substr(1),
		"duplicate key",
		failures
	)
	checks += _expect_decode_rejected(
		PlayerViewCodec,
		red_json.replace("\"veilfront-player-view-v1\"", "\"veilfront-player-view-v2\""),
		"unsupported schema",
		failures
	)
	checks += _expect_decode_rejected(PlayerViewCodec, red_json + "\n", "non canonical bytes", failures)

	var red_result: Dictionary = PlayerViewCodec.decode(red_json)
	var black_result: Dictionary = PlayerViewCodec.decode(black_json)
	checks += 1
	if not bool(red_result.get("ok", false)) or not bool(black_result.get("ok", false)) \
	or red_result.get("value", {}).get("viewer_side", "") != "red" \
	or black_result.get("value", {}).get("viewer_side", "") != "black":
		failures.append("红黑 fixture 未保持各自绑定观察者身份")

	checks += _check_decode_alias_isolation(red_json, failures)
	checks += _check_two_ports_do_not_cross_views(failures)
	checks += _check_port_rejects_viewer_rebind(failures)
	checks += _check_port_signal_order(failures)
	checks += _check_port_public_api_has_no_viewer_selector(failures)

	return {"ok": failures.is_empty(), "checks": checks, "failures": failures}


func _read_fixture(path: String, failures: Array[String]) -> String:
	var content: String = FileAccess.get_file_as_string(path)
	if FileAccess.get_open_error() != OK:
		failures.append("fixture 无法读取: %s" % path)
		return ""
	return content.strip_edges()


func _expect_round_trip(
	codec: Variant,
	canonical_json: String,
	label: String,
	failures: Array[String]
) -> int:
	var decoded: Dictionary = codec.decode(canonical_json)
	if not bool(decoded.get("ok", false)):
		failures.append("%s decode 失败: %s" % [label, decoded.get("error_code", "")])
		return 1
	var encoded: Dictionary = codec.encode(decoded.get("value", {}))
	if not bool(encoded.get("ok", false)) or encoded.get("bytes", "") != canonical_json:
		failures.append("%s canonical 往返不等价" % label)
	return 1


func _expect_root_field_rejected(
	canonical_json: String,
	field_name: String,
	failures: Array[String]
) -> int:
	var decoded: Dictionary = PlayerViewCodec.decode(canonical_json)
	if not bool(decoded.get("ok", false)):
		failures.append("注入测试基线无法 decode")
		return 1
	var tampered: Dictionary = decoded.get("value", {}).duplicate(true)
	tampered[field_name] = 1
	var encoded_tampered: String = JSON.stringify(tampered, "", true, true)
	return _expect_decode_rejected(PlayerViewCodec, encoded_tampered, field_name, failures)


func _expect_decode_rejected(
	codec: Variant,
	encoded: String,
	label: String,
	failures: Array[String]
) -> int:
	var result: Dictionary = codec.decode(encoded)
	if bool(result.get("ok", false)):
		failures.append("非法输入未拒绝: %s" % label)
	return 1


func _check_decode_alias_isolation(red_json: String, failures: Array[String]) -> int:
	var first: Dictionary = PlayerViewCodec.decode(red_json)
	var second: Dictionary = PlayerViewCodec.decode(red_json)
	first.get("value", {}).get("visible_cells", []).append([2, 2])
	if second.get("value", {}).get("visible_cells", []).size() != 1:
		failures.append("两次 decode 共享了可变数组别名")
	return 1


func _check_two_ports_do_not_cross_views(failures: Array[String]) -> int:
	var red_port: Variant = FixtureMatchClientPort.new(RED_FIXTURE_PATH)
	var black_port: Variant = FixtureMatchClientPort.new(BLACK_FIXTURE_PATH)
	var observed_sides: Dictionary = {"red": "", "black": ""}
	red_port.player_view_updated.connect(func(view: Dictionary) -> void:
		observed_sides["red"] = str(view.get("viewer_side", ""))
	)
	black_port.player_view_updated.connect(func(view: Dictionary) -> void:
		observed_sides["black"] = str(view.get("viewer_side", ""))
	)
	var red_publish: Dictionary = red_port.publish_fixture()
	var black_publish: Dictionary = black_port.publish_fixture()
	if not bool(red_publish.get("ok", false)) or not bool(black_publish.get("ok", false)) \
	or observed_sides["red"] != "red" or observed_sides["black"] != "black":
		failures.append(
			"同时存在的红黑 fixture port 发生失败或视角串线 red=%s/%s black=%s/%s" % [
				red_publish, observed_sides["red"], black_publish, observed_sides["black"],
			]
		)
	return 1


func _check_port_public_api_has_no_viewer_selector(failures: Array[String]) -> int:
	var port: Variant = FixtureMatchClientPort.new(RED_FIXTURE_PATH)
	var forbidden_methods: Array[String] = [
		"get_view", "get_player_view", "switch_viewer", "set_viewer", "request_viewer",
	]
	for method_name: String in forbidden_methods:
		if port.has_method(method_name):
			failures.append("MatchClientPort 暴露观察者选择方法: %s" % method_name)
	var forbidden_parameters: Array[String] = [
		"viewer", "viewer_side", "observer", "observer_side", "actor_side",
	]
	for method: Dictionary in port.get_method_list():
		var method_name: String = str(method.get("name", ""))
		if method_name.begins_with("_"):
			continue
		for argument: Dictionary in method.get("args", []):
			if str(argument.get("name", "")) in forbidden_parameters:
				failures.append("公共方法 %s 暴露观察者选择参数" % method_name)
	return 1


func _check_port_rejects_viewer_rebind(failures: Array[String]) -> int:
	var port: Variant = FixtureMatchClientPort.new(RED_FIXTURE_PATH)
	var observed_sides: Array[String] = []
	port.player_view_updated.connect(func(view: Dictionary) -> void:
		observed_sides.append(str(view.get("viewer_side", "")))
	)
	var initial_result: Dictionary = port.publish_fixture()
	var rebind_result: Dictionary = port.attempt_rebind(BLACK_FIXTURE_PATH)
	if not bool(initial_result.get("ok", false)) \
	or bool(rebind_result.get("ok", false)) \
	or observed_sides != ["red"]:
		failures.append("已绑定端口未拒绝切换到另一观察者 fixture")
	return 1


func _check_port_signal_order(failures: Array[String]) -> int:
	var port: Variant = FixtureMatchClientPort.new(RED_FIXTURE_PATH)
	var order: Array[String] = []
	port.player_view_updated.connect(func(_view: Dictionary) -> void: order.append("view"))
	port.visible_events_received.connect(func(_events: Array) -> void: order.append("events"))
	port.visible_error_received.connect(func(_error: Dictionary) -> void: order.append("error"))
	port.action_previews_updated.connect(func(_previews: Array) -> void: order.append("previews"))
	port.prepared_action_changed.connect(func(_preview_id: String) -> void: order.append("prepared"))
	var publish_result: Dictionary = port.publish_fixture()
	var expected: Array[String] = ["view", "events", "error", "previews", "prepared"]
	if not bool(publish_result.get("ok", false)) or order != expected:
		failures.append("端口下行信号顺序错误: %s" % order)
	return 1
