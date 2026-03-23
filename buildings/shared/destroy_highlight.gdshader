shader_type canvas_item;

uniform bool enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0, 0.15, 0.1, 0.85);
uniform vec4 stripe_color : source_color = vec4(1.0, 0.3, 0.25, 0.15);
uniform float stripe_frequency : hint_range(0.1, 1.0) = 0.3;
// Frame UV bounds within the atlas texture (set from GDScript for atlas sprites)
uniform vec2 frame_uv_min = vec2(0.0);
uniform vec2 frame_uv_max = vec2(1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;

	if (enabled && base.a > 0.01) {
		vec4 result = base;

		// Diagonal stripes in screen space so direction is always top-left to bottom-right
		float w = (FRAGCOORD.x + FRAGCOORD.y) * stripe_frequency / 32.0 + TIME * 2.0;
		float stripe = step(0.5, fract(w));
		result.rgb = mix(result.rgb, stripe_color.rgb, stripe * stripe_color.a);

		// Inner outline: opaque pixels within 2px of a transparent pixel
		// Samples outside the frame region count as transparent (real sprite edge)
		vec2 ps = TEXTURE_PIXEL_SIZE;
		vec2 offsets[8] = {
			vec2(-ps.x, 0.0), vec2(ps.x, 0.0),
			vec2(0.0, -ps.y), vec2(0.0, ps.y),
			vec2(-2.0 * ps.x, 0.0), vec2(2.0 * ps.x, 0.0),
			vec2(0.0, -2.0 * ps.y), vec2(0.0, 2.0 * ps.y)
		};
		float n = 0.0;
		for (int i = 0; i < 8; i++) {
			vec2 s = UV + offsets[i];
			if (s.x < frame_uv_min.x || s.x > frame_uv_max.x ||
				s.y < frame_uv_min.y || s.y > frame_uv_max.y) {
				n += 0.0;
			} else {
				n += texture(TEXTURE, s).a;
			}
		}
		if (n < 7.99) {
			result = mix(result, outline_color, outline_color.a);
		}

		COLOR = result;
	} else {
		COLOR = base;
	}
}
