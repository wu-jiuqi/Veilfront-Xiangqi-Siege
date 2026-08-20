shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float open_progress : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float hinge_top_x : hint_range(0.0, 1.0, 0.001) = 0.25;
uniform float hinge_bottom_x : hint_range(0.0, 1.0, 0.001) = 0.25;
uniform float gate_top_y : hint_range(0.0, 1.0, 0.001) = 0.237;
uniform float gate_bottom_y : hint_range(0.0, 1.0, 0.001) = 0.865;

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
		vec4 door = texture(TEXTURE, vec2(source_x, UV.y));
		float edge_shadow = mix(1.0, 0.48, eased);
		door.rgb *= edge_shadow;
		door.a *= 1.0 - smoothstep(0.9, 1.0, eased);
		COLOR = door * COLOR;
	}
}
