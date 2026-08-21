extends RefCounted

const POLICY_VERSION: String = "veilfront-dependency-boundary-v2"
const FORMAL_ROOTS: Array[String] = [
	"res://scripts/game",
	"res://scenes/game",
	"res://resources/game",
]
const SCANNED_EXTENSIONS: Array[String] = ["gd", "tscn", "tres", "gdshader"]

var _regex_cache: Dictionary = {}


func scan_project() -> Dictionary:
	var paths: Array[String] = []
	for root_path: String in FORMAL_ROOTS:
		_collect_files(root_path, paths)
	paths.sort()

	var violations: Array[Dictionary] = []
	for path: String in paths:
		var source: String = FileAccess.get_file_as_string(path)
		if FileAccess.get_open_error() != OK:
			violations.append(_violation(
				"FORMAL_FILE_UNREADABLE",
				path,
				0,
				"正式文件无法读取",
				""
			))
			continue
		violations.append_array(scan_text(path, source))

	return {
		"policy_version": POLICY_VERSION,
		"scanned_files": paths.size(),
		"violations": violations,
	}


func scan_text(path: String, source: String) -> Array:
	var violations: Array[Dictionary] = []
	var scope: String = _scope_for_path(path)
	var raw_lines: PackedStringArray = source.split("\n")

	for line_index: int in raw_lines.size():
		var code_line: String = _strip_comment(raw_lines[line_index])
		var symbol_line: String = _remove_string_contents(code_line)
		var line_number: int = line_index + 1
		_scan_global_asset_references(path, code_line, line_number, violations)
		match scope:
			"contracts":
				_scan_contracts(path, code_line, symbol_line, line_number, violations)
			"domain":
				_scan_domain(path, code_line, symbol_line, line_number, violations)
			"application":
				_scan_application_line(path, code_line, line_number, violations)
			"projection":
				_scan_projection_line(path, code_line, symbol_line, line_number, violations)
			"presentation", "tutorial":
				_scan_consumer(path, code_line, symbol_line, line_number, violations)
			"ports":
				_scan_port_line(path, code_line, symbol_line, line_number, violations)
			_:
				pass

	var signatures: Array[Dictionary] = _extract_function_signatures(source)
	for signature_record: Dictionary in signatures:
		var signature: String = str(signature_record.get("text", ""))
		var line_number: int = int(signature_record.get("line", 0))
		if not _is_public_signature(signature):
			continue
		match scope:
			"application":
				if _matches("\\bFullState\\b", signature):
					violations.append(_violation(
						"APPLICATION_AUTHORITY_API",
						path,
						line_number,
						"application 公开签名不得暴露 FullState 参数或返回值",
						signature
					))
				if _signature_has_named_parameter(signature, [
					"viewer", "viewer_side", "observer", "observer_side", "actor_side",
				]):
					violations.append(_violation(
						"APPLICATION_VIEWER_API",
						path,
						line_number,
						"application 公开签名不得接受调用者提供的 viewer/observer/actor_side",
						signature
					))
			"projection":
				if _projection_signature_has_raw_viewer(signature):
					violations.append(_violation(
						"PROJECTION_VIEWER_API",
						path,
						line_number,
						"projection 不得公开 viewer_side/observer_side 或 String viewer 选择入口",
						signature
					))
			"ports":
				if _signature_has_named_parameter(signature, [
					"seed", "rng", "rng_state", "viewer", "viewer_side",
					"observer", "observer_side", "actor_side",
				]):
					violations.append(_violation(
						"PORT_AUTHORITY_API",
						path,
						line_number,
						"公开 port 不得接受规则 seed/RNG 或任意 viewer/actor 选择参数",
						signature
					))
			_:
				pass

	return violations


func _scan_global_asset_references(
	path: String,
	code_line: String,
	line_number: int,
	violations: Array[Dictionary]
) -> void:
	if code_line.contains("res://scripts/prototype/") \
	or code_line.contains("res://scenes/prototype/") \
	or code_line.contains("res://resources/prototype/"):
		violations.append(_violation(
			"FORMAL_ASSET_PROTOTYPE_REFERENCE",
			path,
			line_number,
			"正式运行时不得引用 prototype 资产",
			code_line
		))
	if _matches("res://[^\\\"']*/ai/", code_line):
		violations.append(_violation(
			"FORMAL_ASSET_AI_REFERENCE",
			path,
			line_number,
			"正式 Iteration 1 运行时不得预加载 AI 资产",
			code_line
		))
	if _matches("res://[^\\\"']*/network/", code_line) \
	and not code_line.contains("res://scenes/game/network/formal_lan_session.tscn"):
		violations.append(_violation(
			"FORMAL_ASSET_NETWORK_REFERENCE",
			path,
			line_number,
			"正式运行时只能引用已批准的正式 LAN 会话场景",
			code_line
		))


func _scan_contracts(
	path: String,
	code_line: String,
	symbol_line: String,
	line_number: int,
	violations: Array[Dictionary]
) -> void:
	if _matches("\\b(Node|Node2D|Node3D|Control|SceneTree|PackedScene)\\b", symbol_line):
		violations.append(_violation(
			"CONTRACTS_SCENE_TYPE",
			path,
			line_number,
			"contracts 不得依赖 SceneTree/Node/Control/PackedScene",
			symbol_line
		))
	if code_line.contains("res://scenes/"):
		violations.append(_violation(
			"CONTRACTS_SCENE_REFERENCE",
			path,
			line_number,
			"contracts 不得引用具体场景",
			code_line
		))


func _scan_domain(
	path: String,
	code_line: String,
	symbol_line: String,
	line_number: int,
	violations: Array[Dictionary]
) -> void:
	if _matches("\\b(Node|Node2D|Node3D|Control|SceneTree|PackedScene)\\b", symbol_line):
		violations.append(_violation(
			"DOMAIN_GODOT_TYPE",
			path,
			line_number,
			"domain 不得依赖 Node/Control/SceneTree/PackedScene",
			symbol_line
		))
	var forbidden_fragments: Array[String] = [
		"res://scenes/", "/application/", "/projection/", "/presentation/",
		"/tutorial/", "/ports/", "/network/", "/ai/", "/prototype/",
	]
	if _contains_any(code_line, forbidden_fragments) \
	or _matches("\\b[A-Za-z_][A-Za-z0-9_]*(Application|Projector|Presenter|Tutorial|Network|Port)\\b", symbol_line):
		violations.append(_violation(
			"DOMAIN_FORBIDDEN_DEPENDENCY",
			path,
			line_number,
			"domain 不得依赖 application/projection/presentation/tutorial/ports/network/AI/prototype",
			code_line
		))


func _scan_application_line(
	path: String,
	code_line: String,
	line_number: int,
	violations: Array[Dictionary]
) -> void:
	var forbidden_fragments: Array[String] = [
		"res://scenes/", "/presentation/", "/tutorial/", "/network/", "/ai/", "/prototype/",
	]
	if _contains_any(code_line, forbidden_fragments):
		violations.append(_violation(
			"APPLICATION_FORBIDDEN_DEPENDENCY",
			path,
			line_number,
			"application 不得依赖具体场景、presentation、tutorial、network、AI 或 prototype",
			code_line
		))


func _scan_projection_line(
	path: String,
	code_line: String,
	symbol_line: String,
	line_number: int,
	violations: Array[Dictionary]
) -> void:
	var forbidden_fragments: Array[String] = [
		"/presentation/", "/tutorial/", "/network/", "/ai/", "/prototype/",
	]
	if _contains_any(code_line, forbidden_fragments):
		violations.append(_violation(
			"PROJECTION_FORBIDDEN_DEPENDENCY",
			path,
			line_number,
			"projection 不得依赖消费者、传输、AI 或 prototype",
			code_line
		))
	if _matches(
		"\\b(full_state|state_snapshot|authority_state)\\s*(\\[[^]]*\\]|\\.[A-Za-z_][A-Za-z0-9_]*)\\s*=",
		symbol_line
	) or _matches(
		"\\b(full_state|state_snapshot|authority_state)\\.(set|erase|clear|append|push_back|push_front|pop_back|pop_front|assign|merge|sort|shuffle)\\s*\\(",
		symbol_line
	):
		violations.append(_violation(
			"PROJECTION_STATE_MUTATION",
			path,
			line_number,
			"projection 不得修改 FullState 或 authority snapshot",
			symbol_line
		))


func _scan_consumer(
	path: String,
	code_line: String,
	symbol_line: String,
	line_number: int,
	violations: Array[Dictionary]
) -> void:
	var forbidden_fragments: Array[String] = [
		"/domain/", "/projection/", "/prototype/", "/network/", "/ai/",
	]
	if _contains_any(code_line, forbidden_fragments):
		violations.append(_violation(
			"CONSUMER_FORBIDDEN_DEPENDENCY",
			path,
			line_number,
			"presentation/tutorial 不得引用 domain、projection、prototype、network 或 AI",
			code_line
		))
	if _matches(
		"\\b(FullState|DomainEvent|DomainError|AuthoritativeReplay|AuthoritativeReplayRecord|RuleEngine|MatchState|SeededRandom|rng_state|initial_flag_positions|full_audit)\\b",
		symbol_line
	):
		violations.append(_violation(
			"CONSUMER_AUTHORITY_SYMBOL",
			path,
			line_number,
			"presentation/tutorial 不得引用 authority-only 类型或字段",
			symbol_line
		))


func _scan_port_line(
	path: String,
	code_line: String,
	symbol_line: String,
	line_number: int,
	violations: Array[Dictionary]
) -> void:
	var forbidden_fragments: Array[String] = [
		"/domain/", "/projection/", "/prototype/", "/network/", "/ai/",
	]
	if _contains_any(code_line, forbidden_fragments):
		violations.append(_violation(
			"PORT_FORBIDDEN_DEPENDENCY",
			path,
			line_number,
			"公开 port 不得引用 authority 实现、prototype、network 或 AI",
			code_line
		))
	if _matches(
		"\\b(FullState|DomainEvent|DomainError|AuthoritativeReplay|AuthoritativeReplayRecord|RuleEngine|MatchState|SeededRandom|rng_state|initial_flag_positions|full_audit|raw_replay|raw_event)\\b",
		symbol_line
	):
		violations.append(_violation(
			"PORT_AUTHORITY_SYMBOL",
			path,
			line_number,
			"公开 port 不得暴露 authority-only 类型、字段或 raw replay/event",
			symbol_line
		))


func _extract_function_signatures(source: String) -> Array[Dictionary]:
	var signatures: Array[Dictionary] = []
	var raw_lines: PackedStringArray = source.split("\n")
	var collecting: bool = false
	var signature: String = ""
	var start_line: int = 0
	var paren_depth: int = 0

	for line_index: int in raw_lines.size():
		var code_line: String = _remove_string_contents(_strip_comment(raw_lines[line_index])).strip_edges()
		if not collecting:
			if not code_line.begins_with("func "):
				continue
			collecting = true
			start_line = line_index + 1
			signature = code_line
			paren_depth = _count_character(code_line, "(") - _count_character(code_line, ")")
		else:
			signature += " " + code_line
			paren_depth += _count_character(code_line, "(") - _count_character(code_line, ")")

		if collecting and paren_depth <= 0 and signature.contains(":"):
			signatures.append({"text": signature, "line": start_line})
			collecting = false
			signature = ""
			start_line = 0
			paren_depth = 0

	return signatures


func _is_public_signature(signature: String) -> bool:
	var regex_match: RegExMatch = _search("^func\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*\\(", signature)
	if regex_match == null:
		return false
	var function_name: String = regex_match.get_string(1)
	return not function_name.begins_with("_")


func _signature_has_named_parameter(signature: String, names: Array[String]) -> bool:
	for parameter_name: String in names:
		var pattern: String = "(?:\\(|,)\\s*%s\\s*(?::|,|\\))" % parameter_name
		if _matches(pattern, signature):
			return true
	return false


func _projection_signature_has_raw_viewer(signature: String) -> bool:
	if _signature_has_named_parameter(signature, ["viewer_side", "observer_side"]):
		return true
	return _matches("(?:\\(|,)\\s*(viewer|observer)\\s*:\\s*String\\b", signature)


func _scope_for_path(path: String) -> String:
	var scope_names: Array[String] = [
		"contracts", "domain", "application", "projection", "presentation", "tutorial", "ports",
	]
	for scope_name: String in scope_names:
		if path.begins_with("res://scripts/game/%s/" % scope_name):
			return scope_name
	return "formal_asset" if path.begins_with("res://scenes/game/") \
		or path.begins_with("res://resources/game/") else ""


func _collect_files(root_path: String, paths: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(root_path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		var extension: String = file_name.get_extension().to_lower()
		if SCANNED_EXTENSIONS.has(extension):
			paths.append(root_path.path_join(file_name))
	for child_name: String in directory.get_directories():
		_collect_files(root_path.path_join(child_name), paths)


func _strip_comment(line: String) -> String:
	var quote: String = ""
	var escaped: bool = false
	for index: int in line.length():
		var character: String = line.substr(index, 1)
		if escaped:
			escaped = false
			continue
		if character == "\\" and not quote.is_empty():
			escaped = true
			continue
		if character == "\"" or character == "'":
			if quote.is_empty():
				quote = character
			elif quote == character:
				quote = ""
			continue
		if character == "#" and quote.is_empty():
			return line.substr(0, index)
	return line


func _remove_string_contents(line: String) -> String:
	var output: String = ""
	var quote: String = ""
	var escaped: bool = false
	for index: int in line.length():
		var character: String = line.substr(index, 1)
		if escaped:
			output += " "
			escaped = false
			continue
		if character == "\\" and not quote.is_empty():
			output += " "
			escaped = true
			continue
		if character == "\"" or character == "'":
			if quote.is_empty():
				quote = character
			elif quote == character:
				quote = ""
			output += " "
			continue
		output += character if quote.is_empty() else " "
	return output


func _contains_any(text: String, fragments: Array[String]) -> bool:
	for fragment: String in fragments:
		if text.contains(fragment):
			return true
	return false


func _count_character(text: String, character: String) -> int:
	return text.length() - text.replace(character, "").length()


func _matches(pattern: String, text: String) -> bool:
	return _search(pattern, text) != null


func _search(pattern: String, text: String) -> RegExMatch:
	var regex: RegEx = _regex_cache.get(pattern) as RegEx
	if regex == null:
		regex = RegEx.new()
		var compile_error: int = regex.compile(pattern)
		if compile_error != OK:
			push_error("依赖扫描器正则编译失败 pattern=%s error=%d" % [pattern, compile_error])
			return null
		_regex_cache[pattern] = regex
	return regex.search(text)


func _violation(
	rule_id: String,
	path: String,
	line_number: int,
	detail: String,
	excerpt: String
) -> Dictionary:
	return {
		"rule_id": rule_id,
		"path": path,
		"line": line_number,
		"detail": detail,
		"excerpt": excerpt.strip_edges(),
	}
