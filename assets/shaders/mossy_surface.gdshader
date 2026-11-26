shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.20, 0.44, 0.25, 1.0);
uniform vec4 warm_tint : source_color = vec4(0.36, 0.56, 0.26, 1.0);
uniform vec4 cool_shadow_tint : source_color = vec4(0.10, 0.22, 0.24, 1.0);
uniform float noise_scale : hint_range(0.05, 8.0) = 0.55;
uniform float micro_scale : hint_range(1.0, 40.0) = 11.0;
uniform float color_variation : hint_range(0.0, 0.6) = 0.24;
uniform float rough_min : hint_range(0.2, 1.0) = 0.68;
uniform float rough_max : hint_range(0.3, 1.0) = 0.96;
uniform float specular_amt : hint_range(0.0, 0.5) = 0.14;
uniform vec3 emission_tint : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_energy : hint_range(0.0, 3.0) = 0.0;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

// Integer PCG 2D hash (shader-visual-polish: zero sine-hash GPU artifacts)
float pcg_hash12(uvec2 p) {
	uvec2 v = p * 1664525u + 1013904223u;
	v.x += v.y * 1664525u;
	v.y += v.x * 1664525u;
	v ^= v >> 16u;
	v.x += v.y * 1664525u;
	return float(v.x >> 8u) * (1.0 / 16777215.0);
}

float value_noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	uvec2 iu = uvec2(ivec2(i) + ivec2(32768));
	float a = pcg_hash12(iu);
	float b = pcg_hash12(iu + uvec2(1u, 0u));
	float c = pcg_hash12(iu + uvec2(0u, 1u));
	float d = pcg_hash12(iu + uvec2(1u, 1u));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm3(vec2 p) {
	float sum = 0.0;
	float amp = 0.52;
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 3; i++) {
		sum += amp * value_noise(p);
		p = rot * p * 2.07 + vec2(13.7, 7.3);
		amp *= 0.50;
	}
	return sum;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	// Triplanar-lite blend between XZ ground projection and side cliff projection
	float upness = clamp(abs(v_world_nrm.y), 0.0, 1.0);
	vec2 coord = mix(v_world_pos.xy + v_world_pos.zy * 0.5, v_world_pos.xz, smoothstep(0.25, 0.75, upness));

	float macro = fbm3(coord * noise_scale);
	float mid = value_noise(coord * (noise_scale * 3.3) + vec2(5.2, -3.1));
	float grain = value_noise(coord * micro_scale);

	// Warm clearing patches vs cool damp moss shadow pockets
	vec3 col = mix(cool_shadow_tint.rgb, base_color.rgb, smoothstep(0.18, 0.62, macro));
	col = mix(col, warm_tint.rgb, smoothstep(0.54, 0.88, macro * 0.72 + mid * 0.28) * color_variation * 2.2);

	// Subtle micro-grain roughness & luminance breakup (kills flat plastic look)
	col *= 0.90 + 0.20 * grain;
	// Cool ambient underside tint on vertical/overhanging facets
	col = mix(col * vec3(0.76, 0.84, 0.94), col, clamp(v_world_nrm.y * 0.5 + 0.5, 0.0, 1.0));

	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(rough_min, rough_max, clamp(1.0 - macro * 0.65 + (grain - 0.5) * 0.25, 0.0, 1.0));
	SPECULAR = specular_amt;
	if (emission_energy > 0.001) {
		EMISSION = emission_tint * emission_energy * (0.82 + 0.36 * mid);
	}
}
