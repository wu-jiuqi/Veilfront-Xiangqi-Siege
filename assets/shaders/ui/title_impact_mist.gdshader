shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float impact_strength : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform vec2 impact_center = vec2(0.435, 0.35);
uniform vec4 mist_color : source_color = vec4(0.36, 0.45, 0.48, 1.0);

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}

float fbm(vec2 point) {
	float value = 0.0;
	float weight = 0.55;
	for (int octave = 0; octave < 4; octave++) {
		value += noise(point) * weight;
		point = point * 2.03 + vec2(7.4, 3.1);
		weight *= 0.46;
	}
	return value;
}

void fragment() {
	vec2 aspect = vec2(1.777778, 1.0);
	vec2 delta = (UV - impact_center) * aspect;
	float progress = 1.0 - impact_strength;
	float distortion = (fbm(delta * 9.0 + vec2(TIME * 0.42, -TIME * 0.31)) - 0.5) * 0.10;
	float radius = mix(0.025, 0.38, progress);
	float ring = 1.0 - smoothstep(0.035, 0.13, abs(length(delta) + distortion - radius));
	float torn_mist = smoothstep(0.32, 0.76, fbm(delta * 5.2 - vec2(TIME * 0.22, TIME * 0.17)));
	float alpha = ring * mix(0.22, 0.62, torn_mist) * impact_strength;
	COLOR = vec4(mist_color.rgb * mix(0.78, 1.08, torn_mist), alpha * mist_color.a);
}
