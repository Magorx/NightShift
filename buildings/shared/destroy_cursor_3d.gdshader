shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 fill_color : source_color = vec4(1.0, 0.15, 0.1, 0.35);
uniform vec4 border_color : source_color = vec4(0.55, 0.05, 0.02, 0.9);
uniform float border_width : hint_range(0.01, 0.2) = 0.06;

void fragment() {
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	if (edge < border_width) {
		ALBEDO = border_color.rgb;
		ALPHA = border_color.a;
	} else {
		ALBEDO = fill_color.rgb;
		ALPHA = fill_color.a;
	}
}
