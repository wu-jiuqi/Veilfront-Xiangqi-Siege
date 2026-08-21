shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float scatter : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float drift_strength : hint_range(0.0, 16.0, 0.1) = 7.0;
uniform float breakup_scale : hint_range(4.0, 40.0, 0.5) = 18.0;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

void vertex() {
	float curl = sin((UV.x * 7.0 + UV.y * 3.0 + TIME * 1.4) * 3.14159265);
	float lift = mix(0.35, 1.0, UV.x);
	VERTEX.x += scatter * drift_strength * (0.35 + UV.y + curl * 0.2);
	VERTEX.y -= scatter * drift_strength * lift * (0.7 + curl * 0.35);
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	float breakup = value_noise(UV * breakup_scale + vec2(TIME * 0.16, -TIME * 0.09));
	float visibility = 1.0 - smoothstep(breakup - 0.16, breakup + 0.16, scatter);
	float edge_thin = mix(1.0, smoothstep(0.0, 0.72, glyph.a), scatter * 0.55);
	COLOR = vec4(glyph.rgb * COLOR.rgb, glyph.a * COLOR.a * visibility * edge_thin);
}
