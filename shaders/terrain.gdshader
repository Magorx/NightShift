shader_type spatial;
render_mode cull_disabled;

uniform sampler2DArray terrain_diffuse : source_color, filter_nearest, repeat_enable;
uniform sampler2DArray terrain_normal : hint_normal, filter_nearest, repeat_enable;
uniform float texture_scale : hint_range(0.01, 4.0) = 0.15;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

varying vec3 v_color;
varying vec3 v_world;
varying vec3 v_norm;
varying flat float v_layer;

void vertex() {
	v_color = COLOR.rgb;
	v_world = VERTEX;
	v_norm = NORMAL;
	v_layer = UV.x;
}

void fragment() {
	vec3 col;
	bool top = v_norm.y > 0.5;

	if (top && v_layer > -0.5) {
		vec2 uv = v_world.xz * texture_scale;

		col = textureLod(terrain_diffuse, vec3(uv, v_layer), 0.0).rgb;

		NORMAL_MAP = textureLod(terrain_normal, vec3(uv, v_layer), 0.0).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	} else {
		col = v_color;
	}

	// Tile border lines on top faces
	if (top) {
		float ex = abs(fract(v_world.x + 0.5) - 0.5);
		float ez = abs(fract(v_world.z + 0.5) - 0.5);
		col *= mix(1.0, 0.72, smoothstep(0.42, 0.50, max(ex, ez)));
	}

	ALBEDO = col;
	ROUGHNESS = roughness;
}
