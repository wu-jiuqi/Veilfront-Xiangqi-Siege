extends SceneTree

const KEY_HUE: float = 0.83
const INNER_HUE_DISTANCE: float = 0.055
const OUTER_HUE_DISTANCE: float = 0.22
const MIN_KEY_SATURATION: float = 0.16
const FULL_KEY_SATURATION: float = 0.62
const OPAQUE_THRESHOLD: float = 0.08
const DISCARD_ALPHA_THRESHOLD: float = 0.04
const SOURCE_PADDING: int = 3
const OUTPUT_SIZE: int = 512
const CONTENT_SIZE: int = 456
const PREVIEW_TOKEN_SIZE: int = 64
const PREVIEW_CELL_SIZE: int = 88
const PREVIEW_COLUMNS: int = 7
const CONTACT_SHEET_PATH: String = \
	"res://evidence/gate2/art-samples/round-tokens-v1/round-tokens-64px-contact-sheet.png"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 28:
		push_error(
			"用法：godot --headless --script chroma_key_round_tokens.gd -- " \
			+ "<输入.png> <输出.png>（共 14 组，红方 7 枚后接黑方 7 枚）"
		)
		quit(2)
		return
	var processed_images: Array[Image] = []
	for pair_index: int in range(0, args.size(), 2):
		var source_path := ProjectSettings.globalize_path(args[pair_index])
		var output_path := ProjectSettings.globalize_path(args[pair_index + 1])
		var result := _key_square_and_resize(source_path, output_path)
		var error: Error = result.get("error", FAILED)
		if error != OK:
			push_error(
				"圆形棋子紫幕抠图失败：%s -> %s（%s）" \
				% [source_path, output_path, error_string(error)]
			)
			quit(3)
			return
		processed_images.append(result.get("image") as Image)
	var preview_error := _save_contact_sheet(processed_images)
	if preview_error != OK:
		push_error("64px 棋子验收图保存失败：%s" % error_string(preview_error))
		quit(4)
		return
	print("ROUND_TOKEN_CHROMA_KEY_PASS assets=%d output=%dx%d preview=%dpx" % [
		processed_images.size(), OUTPUT_SIZE, OUTPUT_SIZE, PREVIEW_TOKEN_SIZE
	])
	quit()


func _key_square_and_resize(source_path: String, output_path: String) -> Dictionary:
	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		return {"error": ERR_FILE_CANT_READ}
	image.convert(Image.FORMAT_RGBA8)
	var opaque_bounds := Rect2i(image.get_width(), image.get_height(), 0, 0)
	var found_opaque := false
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if _is_visible_key_color(color):
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var alpha := color.a * _foreground_alpha(color)
			# 紫幕生成图会在纯背景内留下 1%~3% 的压缩噪点；直接清零，避免缩放后
			# 被 mipmap 聚合成紫色脏边。真正的棋子轮廓由更高 alpha 像素保留。
			if alpha <= DISCARD_ALPHA_THRESHOLD:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			color.a = alpha
			image.set_pixel(x, y, color)
			if alpha >= OPAQUE_THRESHOLD:
				if not found_opaque:
					opaque_bounds = Rect2i(x, y, 1, 1)
					found_opaque = true
				else:
					opaque_bounds = opaque_bounds.expand(Vector2i(x, y))
	if not found_opaque:
		return {"error": ERR_INVALID_DATA}
	var padded := opaque_bounds.grow(SOURCE_PADDING)
	padded.position.x = maxi(0, padded.position.x)
	padded.position.y = maxi(0, padded.position.y)
	padded.size.x = mini(image.get_width() - padded.position.x, padded.size.x)
	padded.size.y = mini(image.get_height() - padded.position.y, padded.size.y)
	var cropped := image.get_region(padded)
	var scale := minf(
		float(CONTENT_SIZE) / float(cropped.get_width()),
		float(CONTENT_SIZE) / float(cropped.get_height())
	)
	var resized_size := Vector2i(
		maxi(1, roundi(float(cropped.get_width()) * scale)),
		maxi(1, roundi(float(cropped.get_height()) * scale))
	)
	cropped.resize(resized_size.x, resized_size.y, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(OUTPUT_SIZE, OUTPUT_SIZE, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
	var destination := Vector2i(
		(OUTPUT_SIZE - resized_size.x) / 2,
		(OUTPUT_SIZE - resized_size.y) / 2
	)
	canvas.blend_rect(cropped, Rect2i(Vector2i.ZERO, resized_size), destination)
	_clean_output_edge(canvas)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if directory_error != OK:
		return {"error": directory_error}
	var save_error := canvas.save_png(output_path)
	return {"error": save_error, "image": canvas}


func _clean_output_edge(image: Image) -> void:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= DISCARD_ALPHA_THRESHOLD or _is_visible_key_color(color):
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))


func _save_contact_sheet(images: Array[Image]) -> Error:
	if images.size() != PREVIEW_COLUMNS * 2:
		return ERR_INVALID_DATA
	var sheet := Image.create(
		PREVIEW_CELL_SIZE * PREVIEW_COLUMNS,
		PREVIEW_CELL_SIZE * 2,
		false,
		Image.FORMAT_RGBA8
	)
	sheet.fill(Color("111716"))
	for index: int in images.size():
		var column := index % PREVIEW_COLUMNS
		var row := index / PREVIEW_COLUMNS
		var cell_origin := Vector2i(column, row) * PREVIEW_CELL_SIZE
		var cell_color := Color("28211e") if row == 0 else Color("172421")
		var border_color := Color("956b55") if row == 0 else Color("4f796b")
		sheet.fill_rect(Rect2i(cell_origin + Vector2i.ONE * 2, Vector2i.ONE * (PREVIEW_CELL_SIZE - 4)), cell_color)
		sheet.fill_rect(Rect2i(cell_origin + Vector2i(2, 2), Vector2i(PREVIEW_CELL_SIZE - 4, 2)), border_color)
		var thumbnail := images[index].duplicate()
		thumbnail.resize(PREVIEW_TOKEN_SIZE, PREVIEW_TOKEN_SIZE, Image.INTERPOLATE_LANCZOS)
		var token_origin := cell_origin + Vector2i.ONE * ((PREVIEW_CELL_SIZE - PREVIEW_TOKEN_SIZE) / 2)
		sheet.blend_rect(
			thumbnail,
			Rect2i(Vector2i.ZERO, Vector2i.ONE * PREVIEW_TOKEN_SIZE),
			token_origin
		)
	var output_path := ProjectSettings.globalize_path(CONTACT_SHEET_PATH)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if directory_error != OK:
		return directory_error
	return sheet.save_png(output_path)


func _foreground_alpha(color: Color) -> float:
	var hue_distance := absf(color.h - KEY_HUE)
	hue_distance = minf(hue_distance, 1.0 - hue_distance)
	var hue_key := 1.0 - smoothstep(INNER_HUE_DISTANCE, OUTER_HUE_DISTANCE, hue_distance)
	var saturation_key := smoothstep(MIN_KEY_SATURATION, FULL_KEY_SATURATION, color.s)
	return 1.0 - hue_key * saturation_key


func _is_visible_key_color(color: Color) -> bool:
	if color.r < 0.18 \
	or color.b < 0.30 \
	or color.g > minf(color.r, color.b) * 0.55:
		return false
	var hue_distance := absf(color.h - KEY_HUE)
	hue_distance = minf(hue_distance, 1.0 - hue_distance)
	return hue_distance <= 0.09
