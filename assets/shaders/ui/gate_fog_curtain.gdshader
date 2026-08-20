shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float reveal : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float opacity : hint_range(0.0, 1.0, 0.001) = 0.92;
uniform float flow_speed : hint_range(0.0, 1.0, 0.01) = 0.08;
uniform vec4 fog_color : source_color = vec4(0.19, 0.25, 0.29, 1.0);

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 curve = local * local * (3.0 - 2.0 * local);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, curve.x), mix(c, d, curve.x), curve.y);
}

float fog_noise(vec2 point) {
	float result = 0.0;
	float weight = 0.55;
	for (int octave = 0; octave < 4; octave++) {
		result += value_noise(point) * weight;
		point = point * 2.03 + vec2(7.1, 3.7);
		weight *= 0.5;
	}
	return result;
}

void fragment() {
	vec2 flow = vec2(TIME * flow_speed, -TIME * flow_speed * 0.45);
	float large_noise = fog_noise(UV * vec2(3.4, 2.6) + flow);
	float fine_noise = fog_noise(UV * vec2(8.0, 5.0) - flow * 1.7);
	float shaped_noise = mix(large_noise, fine_noise, 0.32);

	vec2 origin = vec2(0.5, 0.68);
	vec2 delta = (UV - origin) * vec2(1.0, 0.76);
	float distance_from_gate = length(delta);
	float expanding_front = reveal * 0.92;
	float front_distortion = (shaped_noise - 0.5) * 0.16;
	float coverage = 1.0 - smoothstep(
		expanding_front - 0.12,
		expanding_front + 0.16,
		distance_from_gate + front_distortion
	);
	coverage *= smoothstep(0.0, 0.08, reveal);

	float depth = mix(0.58, 0.98, shaped_noise);
	float alpha = coverage * depth * opacity;
	vec3 color = fog_color.rgb * mix(0.78, 1.2, fine_noise);
	COLOR = vec4(color, alpha * fog_color.a);
}
