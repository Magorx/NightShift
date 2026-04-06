shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float pixel_scale : hint_range(1.0, 8.0, 1.0) = 1.0;
uniform float bit_depth : hint_range(2.0, 32.0, 1.0) = 12.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.4;

// 4x4 Bayer dithering matrix (normalized to -0.5..0.5 range)
const mat4 BAYER = mat4(
	vec4(-0.5,      0.0,     -0.375,   0.125),
	vec4( 0.25,    -0.25,     0.375,  -0.125),
	vec4(-0.3125,   0.1875,  -0.4375,  0.0625),
	vec4( 0.4375,  -0.0625,   0.3125, -0.1875)
);

void fragment() {
	// Pixelate: snap UV to virtual pixel grid
	vec2 uv = SCREEN_UV - mod(SCREEN_UV, SCREEN_PIXEL_SIZE * pixel_scale);
	vec3 col = texture(screen_tex, uv).rgb;

	// Dither: sample Bayer matrix at virtual pixel position
	vec2 pix = SCREEN_UV / (SCREEN_PIXEL_SIZE * pixel_scale);
	float bayer = BAYER[int(mod(pix.x, 4.0))][int(mod(pix.y, 4.0))];
	col += vec3(bayer * dither_strength / bit_depth);

	// Quantize: reduce to N levels per channel
	col = round(col * (bit_depth - 1.0)) / (bit_depth - 1.0);

	COLOR.rgb = col;
	COLOR.a = 1.0;
}
