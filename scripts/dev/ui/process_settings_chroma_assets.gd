extends SceneTree

const SOURCE_DIR := "res://assets/art/ui/settings/chroma_sources"
const OUTPUT_DIR := "res://assets/art/ui/settings/png_v2"
const CHROMA_INNER := 0.01
const CHROMA_OUTER := 0.14
const ALPHA_CROP_THRESHOLD := 0.04
const CROP_PADDING := 4
const SOURCE_SIZES: Dictionary[String, Vector2i] = {
	SOURCE_DIR + "/settings_frame_chroma_v2.png": Vector2i(1619, 971),
	SOURCE_DIR + "/settings_components_chroma_v2.png": Vector2i(1620, 971),
	SOURCE_DIR + "/settings_micro_components_chroma_v2.png": Vector2i(1254, 1254),
}

const JOBS: Array[Dictionary] = [
	{
		"source": SOURCE_DIR + "/settings_frame_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_frame_v2.png",
		"cell": Rect2i(),
	},
	{
		"source": SOURCE_DIR + "/settings_components_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_button_secondary_v2.png",
		"cell": Rect2i(0, 0, 810, 243),
	},
	{
		"source": SOURCE_DIR + "/settings_components_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_button_primary_v2.png",
		"cell": Rect2i(810, 0, 810, 243),
	},
	{
		"source": SOURCE_DIR + "/settings_components_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_tab_inactive_v2.png",
		"cell": Rect2i(0, 243, 810, 243),
		"resize": Vector2i(170, 54),
	},
	{
		"source": SOURCE_DIR + "/settings_components_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_tab_active_v2.png",
		"cell": Rect2i(810, 243, 810, 243),
		"resize": Vector2i(190, 58),
	},
	{
		"source": SOURCE_DIR + "/settings_components_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_option_field_v2.png",
		"cell": Rect2i(0, 486, 810, 243),
	},
	{
		"source": SOURCE_DIR + "/settings_components_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_slider_v2.png",
		"cell": Rect2i(810, 486, 810, 243),
	},
	{
		"source": SOURCE_DIR + "/settings_components_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_checkbox_empty_v2.png",
		"cell": Rect2i(0, 729, 810, 242),
		"resize": Vector2i(34, 34),
	},
	{
		"source": SOURCE_DIR + "/settings_components_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_checkbox_checked_v2.png",
		"cell": Rect2i(810, 729, 810, 242),
		"resize": Vector2i(34, 34),
	},
	{
		"source": SOURCE_DIR + "/settings_micro_components_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_slider_track_v2.png",
		"cell": Rect2i(0, 180, 800, 340),
	},
	{
		"source": SOURCE_DIR + "/settings_micro_components_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_slider_knob_v2.png",
		"cell": Rect2i(800, 150, 350, 400),
		"resize": Vector2i(38, 38),
	},
	{
		"source": SOURCE_DIR + "/settings_micro_components_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_dropdown_arrow_v2.png",
		"cell": Rect2i(200, 750, 300, 300),
		"resize": Vector2i(18, 14),
	},
	{
		"source": SOURCE_DIR + "/settings_micro_components_chroma_v2.png",
		"output": OUTPUT_DIR + "/settings_title_crest_v2.png",
		"cell": Rect2i(650, 730, 550, 350),
		"resize": Vector2i(210, 93),
	},
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for job: Dictionary in JOBS:
		var error := _process_job(job)
		if error != OK:
			push_error("设置页紫幕资产处理失败：%s (%s)" % [job["output"], error_string(error)])
			quit(1)
			return
	print("SETTINGS_CHROMA_ASSETS_PASS outputs=%d" % JOBS.size())
	quit()


func _process_job(job: Dictionary) -> Error:
	var source_path: String = job["source"]
	var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	if source == null or source.is_empty():
		return ERR_FILE_CANT_READ
	if source.get_size() != SOURCE_SIZES.get(source_path, Vector2i.ZERO):
		push_error(
			"紫幕母版尺寸不匹配：%s expected=%s actual=%s"
			% [source_path, SOURCE_SIZES.get(source_path, Vector2i.ZERO), source.get_size()]
		)
		return ERR_INVALID_DATA
	source.convert(Image.FORMAT_RGBA8)
	var cell: Rect2i = job["cell"]
	var region := source if cell.size == Vector2i.ZERO else source.get_region(cell)
	var keyed := _key_magenta(region)
	var bounds := _find_alpha_bounds(keyed)
	if bounds.size == Vector2i.ZERO:
		return ERR_INVALID_DATA
	var padded_bounds := bounds.grow(CROP_PADDING).intersection(Rect2i(Vector2i.ZERO, keyed.get_size()))
	var cropped := keyed.get_region(padded_bounds)
	var resize_to: Vector2i = job.get("resize", Vector2i.ZERO)
	if resize_to != Vector2i.ZERO:
		cropped.resize(resize_to.x, resize_to.y, Image.INTERPOLATE_LANCZOS)
	var output_path: String = job["output"]
	var error := cropped.save_png(output_path)
	if error == OK:
		print("KEYED %s size=%s" % [output_path, cropped.get_size()])
	return error


func _key_magenta(source: Image) -> Image:
	var output := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	var key_color := _sample_corner_key(source)
	for y: int in source.get_height():
		for x: int in source.get_width():
			var pixel := source.get_pixel(x, y)
			var magenta_strength := minf(pixel.r, pixel.b) - pixel.g
			var magenta_relative := magenta_strength / maxf(maxf(pixel.r, pixel.b), 0.001)
			var chroma_alpha := minf(
				1.0 - smoothstep(CHROMA_INNER, CHROMA_OUTER, magenta_strength),
				1.0 - smoothstep(0.08, 0.46, magenta_relative)
			)
			if pixel.r < 0.32 or pixel.b < 0.28:
				chroma_alpha = 1.0
			var alpha := clampf(chroma_alpha, 0.0, 1.0)
			if alpha <= 0.001:
				output.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var rgb := Vector3(pixel.r, pixel.g, pixel.b)
			if alpha < 0.999:
				var key_rgb := Vector3(key_color.r, key_color.g, key_color.b)
				rgb = (rgb - key_rgb * (1.0 - alpha)) / maxf(alpha, 0.001)
				var neutral_ceiling := maxf(rgb.y * 1.45, 0.035)
				rgb.x = minf(rgb.x, neutral_ceiling)
				rgb.z = minf(rgb.z, neutral_ceiling)
				if alpha < 0.92:
					var luma := rgb.x * 0.2126 + rgb.y * 0.7152 + rgb.z * 0.0722
					var saturation_weight := clampf(alpha / 0.92, 0.0, 1.0)
					rgb = Vector3(luma, luma, luma).lerp(rgb, saturation_weight)
				rgb.x = clampf(rgb.x, 0.0, 1.0)
				rgb.y = clampf(rgb.y, 0.0, 1.0)
				rgb.z = clampf(rgb.z, 0.0, 1.0)
			var purple_excess := maxf(minf(rgb.x, rgb.z) - rgb.y, 0.0)
			if purple_excess > 0.0:
				rgb.x = maxf(rgb.x - purple_excess, 0.0)
				rgb.z = maxf(rgb.z - purple_excess, 0.0)
			output.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, alpha))
	return output


func _sample_corner_key(image: Image) -> Color:
	var inset := 12
	var max_x := image.get_width() - 1 - inset
	var max_y := image.get_height() - 1 - inset
	var samples: Array[Color] = [
		image.get_pixel(inset, inset),
		image.get_pixel(max_x, inset),
		image.get_pixel(inset, max_y),
		image.get_pixel(max_x, max_y),
	]
	var average := Color(0, 0, 0, 1)
	for sample: Color in samples:
		average.r += sample.r
		average.g += sample.g
		average.b += sample.b
	average.r /= samples.size()
	average.g /= samples.size()
	average.b /= samples.size()
	return average


func _find_alpha_bounds(image: Image) -> Rect2i:
	var min_point := Vector2i(image.get_width(), image.get_height())
	var max_point := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a <= ALPHA_CROP_THRESHOLD:
				continue
			min_point.x = mini(min_point.x, x)
			min_point.y = mini(min_point.y, y)
			max_point.x = maxi(max_point.x, x)
			max_point.y = maxi(max_point.y, y)
	if max_point.x < min_point.x or max_point.y < min_point.y:
		return Rect2i()
	return Rect2i(min_point, max_point - min_point + Vector2i.ONE)
