shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2DArray terrain_diffuse : source_color, filter_nearest, repeat_enable;
uniform sampler2DArray terrain_normal : hint_normal, filter_nearest, repeat_enable;
uniform float texture_scale : hint_range(0.01, 4.0) = 0.15;

// Fake directional light for normal-map depth
uniform vec3 light_dir = vec3(0.35, 0.75, 0.3);
uniform float normal_strength : hint_range(0.0, 1.0) = 0.5;

varying vec3 v_color;
varying vec3 v_world;
varying vec3 v_norm;
varying flat float v_layer;  // flat = no interpolation across triangle edges

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

		// textureLod forces mip 0 — avoids broken derivatives from
		// non-uniform layer index across adjacent tiles (known GLSL pitfall)
		col = textureLod(terrain_diffuse, vec3(uv, v_layer), 0.0).rgb;

		// Normal-map fake shading for depth without scene lights
		vec3 n = textureLod(terrain_normal, vec3(uv, v_layer), 0.0).rgb * 2.0 - 1.0;
		vec3 world_n = normalize(vec3(n.x, n.z, -n.y));
		float ndotl = dot(world_n, normalize(light_dir));
		float shade = mix(1.0 - normal_strength, 1.0, clamp(ndotl * 0.5 + 0.5, 0.0, 1.0));
		col *= shade;
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
}
