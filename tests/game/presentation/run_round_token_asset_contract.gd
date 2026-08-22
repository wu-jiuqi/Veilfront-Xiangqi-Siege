extends SceneTree

const TOKEN_PATHS: Array[String] = [
	"res://assets/art/pieces/round_tokens_v1/red_general_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/red_guard_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/red_minister_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/red_cavalry_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/red_chariot_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/red_trebuchet_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/red_infantry_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/black_general_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/black_guard_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/black_minister_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/black_cavalry_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/black_chariot_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/black_trebuchet_token_v1.png",
	"res://assets/art/pieces/round_tokens_v1/black_infantry_token_v1.png",
]
const CONTACT_SHEET_PATH: String = \
	"res://evidence/gate2/art-samples/round-tokens-v1/round-tokens-64px-contact-sheet.png"
const OUTPUT_SIZE: int = 512
const SMALL_SIZE: int = 64
const MIN_TRANSPARENT_PADDING: int = 20
const KEY_HUE: float = 0.83

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(TOKEN_PATHS.size() == 14, "圆形棋子资产没有覆盖双阵营各七种棋子")
	for token_path: String in TOKEN_PATHS:
		_check_token(token_path)
	var contact_sheet := Image.load_from_file(ProjectSettings.globalize_path(CONTACT_SHEET_PATH))
	_expect(
		contact_sheet != null and contact_sheet.get_size() == Vector2i(616, 176),
		"缺少按 64px 实际尺寸生成的双阵营验收图"
	)
	if _failures.is_empty():
		print("ROUND_TOKEN_ASSET_CONTRACT_PASS assets=%d small_size=%d" % [
			TOKEN_PATHS.size(), SMALL_SIZE
		])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("ROUND_TOKEN_ASSET_CONTRACT_FAIL failures=%d" % _failures.size())
	quit(1)


func _check_token(token_path: String) -> void:
	var imported_texture := load(token_path) as Texture2D
	_expect(imported_texture != null, "%s 没有可用的 Godot 纹理导入" % token_path)
	if imported_texture != null:
		var imported_image := imported_texture.get_image()
		_expect(
			imported_image != null and imported_image.has_mipmaps(),
			"%s 没有生成小尺寸显示所需的 mipmap" % token_path
		)
	var image := Image.load_from_file(ProjectSettings.globalize_path(token_path))
	_expect(image != null and not image.is_empty(), "%s 无法读取" % token_path)
	if image == null or image.is_empty():
		return
	image.convert(Image.FORMAT_RGBA8)
	_expect(image.get_size() == Vector2i.ONE * OUTPUT_SIZE, "%s 不是 512×512" % token_path)
	if image.get_size() != Vector2i.ONE * OUTPUT_SIZE:
		return
	for corner: Vector2i in [
		Vector2i.ZERO,
		Vector2i(OUTPUT_SIZE - 1, 0),
		Vector2i(0, OUTPUT_SIZE - 1),
		Vector2i.ONE * (OUTPUT_SIZE - 1),
	]:
		_expect(image.get_pixelv(corner).a <= 0.001, "%s 四角没有完全透明" % token_path)
	var bounds := _alpha_bounds(image, 0.08)
	_expect(bounds.size.x > 0 and bounds.size.y > 0, "%s 没有可见内容" % token_path)
	_expect(
		bounds.position.x >= MIN_TRANSPARENT_PADDING \
		and bounds.position.y >= MIN_TRANSPARENT_PADDING \
		and bounds.end.x <= OUTPUT_SIZE - MIN_TRANSPARENT_PADDING \
		and bounds.end.y <= OUTPUT_SIZE - MIN_TRANSPARENT_PADDING,
		"%s 没有保留至少 %dpx 的棋盘安全留边" % [token_path, MIN_TRANSPARENT_PADDING]
	)
	_expect(_purple_spill_count(image) == 0, "%s 的透明边缘仍残留可见紫幕" % token_path)
	_check_small_size_contrast(image, token_path)


func _check_small_size_contrast(source: Image, token_path: String) -> void:
	var small: Image = source.duplicate() as Image
	small.resize(SMALL_SIZE, SMALL_SIZE, Image.INTERPOLATE_LANCZOS)
	var min_luminance := 1.0
	var max_luminance := 0.0
	var strong_transitions := 0
	for y: int in range(14, 50):
		for x: int in range(14, 50):
			var color: Color = small.get_pixel(x, y)
			if color.a < 0.8:
				continue
			var luminance := _luminance(color)
			min_luminance = minf(min_luminance, luminance)
			max_luminance = maxf(max_luminance, luminance)
			if x < 49:
				var right: Color = small.get_pixel(x + 1, y)
				if right.a >= 0.8 and absf(luminance - _luminance(right)) >= 0.12:
					strong_transitions += 1
			if y < 49:
				var below: Color = small.get_pixel(x, y + 1)
				if below.a >= 0.8 and absf(luminance - _luminance(below)) >= 0.12:
					strong_transitions += 1
	_expect(
		max_luminance - min_luminance >= 0.42,
		"%s 缩至 64px 后中心字形明暗跨度不足" % token_path
	)
	_expect(
		strong_transitions >= 24,
		"%s 缩至 64px 后中心字形有效边缘过少（%d）" % [token_path, strong_transitions]
	)


func _alpha_bounds(image: Image, threshold: float) -> Rect2i:
	var bounds := Rect2i(image.get_width(), image.get_height(), 0, 0)
	var found := false
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < threshold:
				continue
			if not found:
				bounds = Rect2i(x, y, 1, 1)
				found = true
			else:
				bounds = bounds.expand(Vector2i(x, y))
	return bounds if found else Rect2i()


func _purple_spill_count(image: Image) -> int:
	var spill_count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			# 近黑和近白材质的微小 RGB 偏差会产生不稳定色相；只有同时具备
			# 可见红蓝分量且绿色显著偏低时，才视为真正的紫幕残留。
			if color.a < 0.04 \
			or color.r < 0.18 \
			or color.b < 0.30 \
			or color.g > minf(color.r, color.b) * 0.55:
				continue
			var hue_distance := absf(color.h - KEY_HUE)
			hue_distance = minf(hue_distance, 1.0 - hue_distance)
			if hue_distance <= 0.09:
				spill_count += 1
	return spill_count


func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
