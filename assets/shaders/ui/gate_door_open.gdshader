shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float open_progress : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float hinge_top_x : hint_range(0.0, 1.0, 0.001) = 0.25;
uniform float hinge_bottom_x : hint_range(0.0, 1.0, 0.001) = 0.25;
uniform float gate_top_y : hint_range(0.0, 1.0, 0.001) = 0.237;
uniform float gate_bottom_y : hint_range(0.0, 1.0, 0.001) = 0.865;
uniform float brightness : hint_range(0.5, 2.0, 0.01) = 1.35;
uniform float shadow_lift : hint_range(0.0, 0.3, 0.01) = 0.14;
uniform float edge_feather_pixels : hint_range(0.0, 32.0, 0.25) = 18.0;
uniform vec4 bronze_tint : source_color = vec4(1.08, 1.04, 0.95, 1.0);

void fragment() {
	float eased = open_progress * open_progress * (3.0 - 2.0 * open_progress);
	float horizontal_scale = mix(1.0, 0.035, eased);
	float gate_height = max(gate_bottom_y - gate_top_y, 0.001);
	float vertical_progress = clamp((UV.y - gate_top_y) / gate_height, 0.0, 1.0);
	float hinge_x = mix(hinge_top_x, hinge_bottom_x, vertical_progress);
	float source_x = hinge_x + (UV.x - hinge_x) / horizontal_scale;

	if (source_x < 0.0 || source_x > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec2 source_uv = vec2(source_x, UV.y);
		vec4 door = texture(TEXTURE, source_uv);
		vec2 feather_step = TEXTURE_PIXEL_SIZE * edge_feather_pixels * 0.25;
		float left_support = 0.0;
		float right_support = 0.0;
		float top_support = 0.0;
		float bottom_support = 0.0;
		for (int sample_index = 1; sample_index <= 4; sample_index++) {
			float sample_distance = float(sample_index);
			left_support += texture(TEXTURE, source_uv - vec2(feather_step.x * sample_distance, 0.0)).a;
			right_support += texture(TEXTURE, source_uv + vec2(feather_step.x * sample_distance, 0.0)).a;
			top_support += texture(TEXTURE, source_uv - vec2(0.0, feather_step.y * sample_distance)).a;
			bottom_support += texture(TEXTURE, source_uv + vec2(0.0, feather_step.y * sample_distance)).a;
		}
		float edge_support = min(min(left_support, right_support), min(top_support, bottom_support)) * 0.25;
		float edge_feather = smoothstep(0.0, 1.0, edge_support);
		door.rgb = (pow(max(door.rgb, vec3(0.0)), vec3(0.72)) * brightness + vec3(shadow_lift)) * bronze_tint.rgb;
		float edge_shadow = mix(1.0, 0.48, eased);
		door.rgb *= edge_shadow;
		door.a *= edge_feather;
		door.a *= 1.0 - smoothstep(0.9, 1.0, eased);
		COLOR = door * COLOR;
	}
}
