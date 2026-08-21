shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 deep_fog_color : source_color = vec4(0.018, 0.028, 0.042, 0.86);
uniform vec4 smoke_color : source_color = vec4(0.085, 0.12, 0.14, 0.58);
uniform vec4 edge_color : source_color = vec4(0.53, 0.37, 0.19, 0.72);
uniform float motion_speed : hint_range(0.0, 0.2, 0.005) = 0.025;
uniform float grain_strength : hint_range(0.0, 0.35, 0.01) = 0.16;

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

void fragment() {
	float fog_mask = texture(TEXTURE, UV).r;
	if (fog_mask <= 0.002) {
		COLOR = vec4(0.0);
	} else {
		vec2 drift = vec2(TIME * motion_speed, -TIME * motion_speed * 0.61);
		float broad_smoke = value_noise(UV * vec2(7.0, 18.0) + drift);
		float fine_smoke = value_noise(UV * vec2(23.0, 57.0) - drift * 1.7);
		float grain = mix(broad_smoke, fine_smoke, 0.38);
		float edge_band = smoothstep(0.04, 0.46, fog_mask)
			* (1.0 - smoothstep(0.48, 0.94, fog_mask));
		vec3 fog_rgb = mix(deep_fog_color.rgb, smoke_color.rgb, broad_smoke * 0.42);
		fog_rgb = mix(fog_rgb, edge_color.rgb, edge_band * 0.24);
		float alpha_noise = mix(1.0 - grain_strength, 1.0 + grain_strength, grain);
		float fog_alpha = fog_mask * deep_fog_color.a * alpha_noise;
		fog_alpha += edge_band * edge_color.a * 0.10;
		COLOR = vec4(fog_rgb, clamp(fog_alpha, 0.0, 0.94));
	}
}
