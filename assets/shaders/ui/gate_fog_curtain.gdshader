shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float reveal : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float opacity : hint_range(0.0, 1.0, 0.001) = 0.92;
uniform float density_boost : hint_range(0.5, 1.5, 0.01) = 1.0;
uniform float flow_speed : hint_range(0.0, 1.0, 0.01) = 0.08;
uniform vec4 fog_color : source_color = vec4(0.19, 0.25, 0.29, 1.0);

vec2 random_gradient(vec2 point) {
	vec2 seed = vec2(
		dot(point, vec2(127.1, 311.7)),
		dot(point, vec2(269.5, 183.3))
	);
	return -1.0 + 2.0 * fract(sin(seed) * 43758.5453);
}

float gradient_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 curve = local * local * local * (local * (local * 6.0 - 15.0) + 10.0);
	float a = dot(random_gradient(cell), local);
	float b = dot(random_gradient(cell + vec2(1.0, 0.0)), local - vec2(1.0, 0.0));
	float c = dot(random_gradient(cell + vec2(0.0, 1.0)), local - vec2(0.0, 1.0));
	float d = dot(random_gradient(cell + vec2(1.0, 1.0)), local - vec2(1.0, 1.0));
	return mix(mix(a, b, curve.x), mix(c, d, curve.x), curve.y) * 0.5 + 0.5;
}

float fog_noise(vec2 point) {
	float result = 0.0;
	float weight = 0.52;
	mat2 rotation = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int octave = 0; octave < 5; octave++) {
		result += gradient_noise(point) * weight;
		point = rotation * point * 2.04 + vec2(5.7, 9.2);
		weight *= 0.48;
	}
	return result;
}

void fragment() {
	float time = TIME * flow_speed;
	vec2 space = (UV - vec2(0.5)) * vec2(1.55, 1.0);
	vec2 slow_flow = vec2(time * 0.36, -time * 0.17);
	vec2 cross_flow = vec2(-time * 0.24, time * 0.31);
	vec2 warp = vec2(
		fog_noise(space * 1.65 + slow_flow + vec2(2.1, 5.3)),
		fog_noise(space * 1.83 + cross_flow + vec2(8.7, 1.4))
	) - vec2(0.5);
	float large_noise = fog_noise(space * 2.7 + warp * 1.55 + slow_flow);
	float medium_noise = fog_noise(space * 5.1 - warp * 0.85 + cross_flow);
	float wisp_noise = fog_noise(space * vec2(9.2, 6.4) + warp * 2.2 - slow_flow * 1.8);
	float shaped_noise = large_noise * 0.55 + medium_noise * 0.30 + wisp_noise * 0.15;

	vec2 origin = vec2(0.5, 0.68);
	vec2 delta = (UV - origin) * vec2(1.0, 0.76);
	float distance_from_gate = length(delta);
	float expanding_front = reveal * 0.92;
	float front_distortion = (large_noise - 0.5) * 0.24 + warp.x * 0.08;
	float coverage = 1.0 - smoothstep(
		expanding_front - 0.16,
		expanding_front + 0.18,
		distance_from_gate + front_distortion
	);
	coverage *= smoothstep(0.0, 0.08, reveal);

	float soft_density = smoothstep(0.20, 0.82, shaped_noise);
	float torn_edges = smoothstep(0.27, 0.74, medium_noise + wisp_noise * 0.18);
	float depth = mix(0.24, 0.96, soft_density) * mix(0.62, 1.0, torn_edges);
	float alpha = clamp(coverage * depth * density_boost * opacity, 0.0, 1.0);
	vec3 color = fog_color.rgb * mix(0.72, 1.14, large_noise * 0.7 + wisp_noise * 0.3);
	COLOR = vec4(color, alpha * fog_color.a);
}
