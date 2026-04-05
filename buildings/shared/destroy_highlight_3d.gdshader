shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 tint_color : source_color = vec4(1.0, 0.15, 0.1, 0.3);
uniform vec4 stripe_color : source_color = vec4(1.0, 0.25, 0.2, 0.7);

void fragment() {
	// Slow-moving diagonal lines in screen space
	float w = (FRAGCOORD.x + FRAGCOORD.y) / 48.0 + TIME * 0.7;
	float line = smoothstep(0.35, 0.4, fract(w)) * (1.0 - smoothstep(0.85, 0.9, fract(w)));

	vec3 col = mix(tint_color.rgb, stripe_color.rgb, line * stripe_color.a);
	ALBEDO = col;
	ALPHA = tint_color.a + line * stripe_color.a * 0.3;
}
