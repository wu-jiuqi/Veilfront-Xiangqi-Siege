shader_type canvas_item;
render_mode unshaded;

uniform float sharpness : hint_range(0.0, 1.0, 0.01) = 0.42;

void fragment() {
	vec4 center = texture(TEXTURE, UV);
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec3 neighbor_average = (
		texture(TEXTURE, UV + vec2(texel.x, 0.0)).rgb
		+ texture(TEXTURE, UV - vec2(texel.x, 0.0)).rgb
		+ texture(TEXTURE, UV + vec2(0.0, texel.y)).rgb
		+ texture(TEXTURE, UV - vec2(0.0, texel.y)).rgb
	) * 0.25;
	vec3 sharpened = center.rgb + (center.rgb - neighbor_average) * sharpness;
	COLOR = vec4(clamp(sharpened, vec3(0.0), vec3(1.0)), center.a);
}
