shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 deep_fog_color : source_color = vec4(0.018, 0.028, 0.042, 0.86);
uniform vec4 smoke_color : source_color = vec4(0.085, 0.12, 0.14, 0.58);
uniform vec4 edge_color : source_color = vec4(0.53, 0.37, 0.19, 0.72);
uniform float motion_speed : hint_range(0.0, 0.2, 0.005) = 0.025;
uniform float grain_strength : hint_range(0.0, 0.35, 0.01) = 0.16;
uniform float boundary_warp : hint_range(0.0, 1.0, 0.01) = 0.82;
uniform float edge_breakup : hint_range(0.0, 0.65, 0.01) = 0.38;
uniform float edge_softness : hint_range(0.04, 0.4, 0.01) = 0.22;

const vec2 CELL_UV = vec2(0.11111111, 0.04166667);

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

float fog_noise(vec2 point) {
	float result = value_noise(point) * 0.56;
	result += value_noise(point * 2.03 + vec2(13.7, 4.9)) * 0.29;
	result += value_noise(point * 4.11 + vec2(2.1, 19.3)) * 0.15;
	return result;
}

void fragment() {
	float source_mask = texture(TEXTURE, UV).r;
	float detection_hint = texture(TEXTURE, UV).g;
	vec2 slow_drift = vec2(TIME * motion_speed, -TIME * motion_speed * 0.61);
	float warp_x = fog_noise(UV * vec2(4.2, 11.6) + slow_drift);
	float warp_y = fog_noise(UV * vec2(5.1, 13.8) - slow_drift * 0.73 + vec2(21.7, 8.4));
	vec2 warped_uv = clamp(
		UV + (vec2(warp_x, warp_y) - vec2(0.5)) * CELL_UV * boundary_warp,
		vec2(0.0),
		vec2(1.0)
	);

	vec2 round_radius = CELL_UV * 0.34;
	float rounded_mask = texture(TEXTURE, warped_uv).r * 2.0;
	rounded_mask += texture(TEXTURE, clamp(warped_uv + vec2(round_radius.x, 0.0), vec2(0.0), vec2(1.0))).r;
	rounded_mask += texture(TEXTURE, clamp(warped_uv - vec2(round_radius.x, 0.0), vec2(0.0), vec2(1.0))).r;
	rounded_mask += texture(TEXTURE, clamp(warped_uv + vec2(0.0, round_radius.y), vec2(0.0), vec2(1.0))).r;
	rounded_mask += texture(TEXTURE, clamp(warped_uv - vec2(0.0, round_radius.y), vec2(0.0), vec2(1.0))).r;
	rounded_mask += texture(TEXTURE, clamp(warped_uv + round_radius, vec2(0.0), vec2(1.0))).r * 0.7;
	rounded_mask += texture(TEXTURE, clamp(warped_uv - round_radius, vec2(0.0), vec2(1.0))).r * 0.7;
	rounded_mask += texture(TEXTURE, clamp(warped_uv + vec2(round_radius.x, -round_radius.y), vec2(0.0), vec2(1.0))).r * 0.7;
	rounded_mask += texture(TEXTURE, clamp(warped_uv + vec2(-round_radius.x, round_radius.y), vec2(0.0), vec2(1.0))).r * 0.7;
	rounded_mask /= 8.8;

	float erosion = fog_noise(UV * vec2(15.0, 37.0) + slow_drift * 0.37);
	float threshold = 0.5 + (erosion - 0.5) * edge_breakup;
	float fog_mask = smoothstep(threshold - edge_softness, threshold + edge_softness, rounded_mask);
	vec2 local_cell_uv = fract(UV / CELL_UV);
	float center_distance = max(abs(local_cell_uv.x - 0.5), abs(local_cell_uv.y - 0.5));
	float center_guard = 1.0 - smoothstep(0.14, 0.36, center_distance);
	if (source_mask < 0.5) {
		fog_mask *= 1.0 - center_guard;
	} else {
		fog_mask = max(fog_mask, center_guard);
	}
	if (fog_mask <= 0.002) {
		COLOR = vec4(0.0);
	} else {
		float broad_smoke = fog_noise(UV * vec2(6.2, 15.5) + slow_drift);
		float fine_smoke = value_noise(UV * vec2(23.0, 57.0) - slow_drift * 1.7);
		float grain = mix(broad_smoke, fine_smoke, 0.38);
		float edge_band = smoothstep(0.04, 0.46, fog_mask) * (1.0 - smoothstep(0.48, 0.94, fog_mask));
		vec3 fog_rgb = mix(deep_fog_color.rgb, smoke_color.rgb, broad_smoke * 0.42);
		fog_rgb = mix(fog_rgb, edge_color.rgb, edge_band * 0.24);
		fog_rgb = mix(fog_rgb, smoke_color.rgb, detection_hint * 0.18);
		float alpha_noise = mix(1.0 - grain_strength, 1.0 + grain_strength, grain);
		float fog_alpha = fog_mask * deep_fog_color.a * alpha_noise;
		fog_alpha *= mix(1.0, 0.78, detection_hint);
		fog_alpha += edge_band * edge_color.a * 0.10;
		COLOR = vec4(fog_rgb, clamp(fog_alpha, 0.0, 0.94));
	}
}
