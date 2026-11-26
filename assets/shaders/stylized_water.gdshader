shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.06, 0.28, 0.42, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.14, 0.62, 0.68, 1.0);
uniform vec4 foam_color : source_color = vec4(0.86, 0.97, 0.99, 1.0);
uniform vec2 flow_dir = vec2(0.0, 1.0);
uniform float flow_speed : hint_range(0.0, 3.0) = 0.55;
uniform float wave_scale : hint_range(0.2, 6.0) = 1.35;

varying vec3 v_world_pos;

float pcg_hash12(uvec2 p) {
	uvec2 v = p * 1664525u + 1013904223u;
	v.x += v.y * 1664525u;
	v.y += v.x * 1664525u;
	v ^= v >> 16u;
	v.x += v.y * 1664525u;
	return float(v.x >> 8u) * (1.0 / 16777215.0);
}

float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	vec2 u = f * f * (3.0 - 2.0 * f);
	uvec2 iu = uvec2(ivec2(i) + ivec2(32768));
	float a = pcg_hash12(iu);
	float b = pcg_hash12(iu + uvec2(1u, 0u));
	float c = pcg_hash12(iu + uvec2(0u, 1u));
	float d = pcg_hash12(iu + uvec2(1u, 1u));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// UV.x on BoxMesh top face spans 0..1 across width -> shore distance!
	float bank = abs(UV.x - 0.5) * 2.0;
	vec2 wuv = v_world_pos.xz * wave_scale;
	float t = TIME * flow_speed;

	float n1 = vnoise(wuv + flow_dir * t);
	float n2 = vnoise(wuv * 1.85 - flow_dir * (t * 0.72) + vec2(4.1, 2.7));
	float caustic = smoothstep(0.56, 0.78, n1 * 0.55 + n2 * 0.45);

	vec3 water_col = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.15, 0.92, bank * 0.78 + n1 * 0.28));
	water_col = mix(water_col, foam_color.rgb, caustic * 0.34);

	// Animated shoreline foam ribbons near banks
	float shore_foam = smoothstep(0.74, 0.95, bank + (n2 - 0.5) * 0.22);
	water_col = mix(water_col, foam_color.rgb, shore_foam * 0.72);

	ALBEDO = water_col;
	ROUGHNESS = mix(0.08, 0.26, shore_foam);
	SPECULAR = 0.62;
	EMISSION = (shallow_color.rgb * 0.18 + foam_color.rgb * (caustic * 0.22 + shore_foam * 0.16));
}
