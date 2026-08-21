extends SceneTree

const KEY_HUE: float = 0.83
const INNER_HUE_DISTANCE: float = 0.06
const OUTER_HUE_DISTANCE: float = 0.25
const MIN_KEY_SATURATION: float = 0.12
const FULL_KEY_SATURATION: float = 0.55
const CROP_PADDING: int = 4


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() % 2 != 0:
		push_error("用法：godot --headless --script chroma_key_ui_assets.gd -- <输入.png> <输出.png> [...]")
		quit(2)
		return
	for pair_index: int in range(0, args.size(), 2):
		var source_path := ProjectSettings.globalize_path(args[pair_index])
		var output_path := ProjectSettings.globalize_path(args[pair_index + 1])
		var result := _key_and_crop(source_path, output_path)
		if result != OK:
			push_error("紫幕抠图失败：%s -> %s（%s）" % [source_path, output_path, error_string(result)])
			quit(3)
			return
	quit()


func _key_and_crop(source_path: String, output_path: String) -> Error:
	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		return ERR_FILE_CANT_READ
	image.convert(Image.FORMAT_RGBA8)
	var opaque_bounds := Rect2i(image.get_width(), image.get_height(), 0, 0)
	var found_opaque := false
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			var alpha := color.a * _foreground_alpha(color)
			if alpha <= 0.003:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			color.a = alpha
			image.set_pixel(x, y, color)
			if alpha >= 0.08:
				if not found_opaque:
					opaque_bounds = Rect2i(x, y, 1, 1)
					found_opaque = true
				else:
					opaque_bounds = opaque_bounds.expand(Vector2i(x, y))
	if not found_opaque:
		return ERR_INVALID_DATA
	var padded := opaque_bounds.grow(CROP_PADDING)
	padded.position.x = maxi(0, padded.position.x)
	padded.position.y = maxi(0, padded.position.y)
	padded.size.x = mini(image.get_width() - padded.position.x, padded.size.x)
	padded.size.y = mini(image.get_height() - padded.position.y, padded.size.y)
	image = image.get_region(padded)
	return image.save_png(output_path)


func _foreground_alpha(color: Color) -> float:
	var hue_distance := absf(color.h - KEY_HUE)
	hue_distance = minf(hue_distance, 1.0 - hue_distance)
	var hue_key := 1.0 - smoothstep(INNER_HUE_DISTANCE, OUTER_HUE_DISTANCE, hue_distance)
	var saturation_key := smoothstep(MIN_KEY_SATURATION, FULL_KEY_SATURATION, color.s)
	return 1.0 - hue_key * saturation_key
