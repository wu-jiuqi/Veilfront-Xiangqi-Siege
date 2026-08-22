extends SceneTree

const ASSET_PAIRS: Array[Dictionary] = [
	{
		"source": "res://assets/art/structures/terracotta_warriors/walls/generated_v1/city_wall_chroma_v1.png",
		"runtime": "res://assets/art/structures/terracotta_warriors/walls/generated_v1/city_wall_v1.png",
	},
	{
		"source": "res://assets/art/flags/terracotta_warriors/round_v1/neutral_flag_round_chroma_v1.png",
		"runtime": "res://assets/art/flags/terracotta_warriors/round_v1/neutral_flag_round_v1.png",
	},
	{
		"source": "res://assets/art/flags/terracotta_warriors/round_v1/red_flag_round_chroma_v1.png",
		"runtime": "res://assets/art/flags/terracotta_warriors/round_v1/red_flag_round_v1.png",
	},
	{
		"source": "res://assets/art/flags/terracotta_warriors/round_v1/black_flag_round_chroma_v1.png",
		"runtime": "res://assets/art/flags/terracotta_warriors/round_v1/black_flag_round_v1.png",
	},
]

var _failures: Array[String] = []


func _init() -> void:
	for pair: Dictionary in ASSET_PAIRS:
		_check_pair(str(pair["source"]), str(pair["runtime"]))
	if _failures.is_empty():
		print("PURPLE_CHROMA_ASSET_CONTRACT_PASS assets=%d" % ASSET_PAIRS.size())
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("PURPLE_CHROMA_ASSET_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_pair(source_path: String, runtime_path: String) -> void:
	var source := Image.new()
	var runtime := Image.new()
	_expect(
		source.load(ProjectSettings.globalize_path(source_path)) == OK,
		"cannot load purple-screen source %s" % source_path
	)
	_expect(
		runtime.load(ProjectSettings.globalize_path(runtime_path)) == OK,
		"cannot load keyed runtime asset %s" % runtime_path
	)
	if source.is_empty() or runtime.is_empty():
		return
	for point: Vector2i in _corner_points(source):
		var color := source.get_pixelv(point)
		_expect(
			color.r >= 0.82 and color.b >= 0.82 and color.g <= 0.24,
			"purple-screen corner is not chroma purple in %s" % source_path
		)
	for point: Vector2i in _corner_points(runtime):
		_expect(
			runtime.get_pixelv(point).a <= 0.01,
			"runtime corner remained opaque after purple keying in %s" % runtime_path
		)
	_expect(
		runtime.get_pixelv(Vector2i(runtime.get_width() / 2, runtime.get_height() / 2)).a >= 0.9,
		"runtime foreground center was removed by purple keying in %s" % runtime_path
	)


func _corner_points(image: Image) -> Array[Vector2i]:
	return [
		Vector2i.ZERO,
		Vector2i(image.get_width() - 1, 0),
		Vector2i(0, image.get_height() - 1),
		Vector2i(image.get_width() - 1, image.get_height() - 1),
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
