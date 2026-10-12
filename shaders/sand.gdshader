shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Цвета песка
uniform vec3 sand_light  : source_color = vec3(0.96, 0.84, 0.58);
uniform vec3 sand_mid    : source_color = vec3(0.82, 0.66, 0.38);
uniform vec3 sand_dark   : source_color = vec3(0.62, 0.46, 0.22);

// Масштаб: 1 единица мира = 1.0 / texture_scale тайлов
uniform float texture_scale  : hint_range(0.01, 2.0) = 0.25;
uniform float ripple_strength: hint_range(0.0, 2.0)  = 0.55;
uniform float roughness_base : hint_range(0.0, 1.0)  = 0.90;
uniform float specular_amt   : hint_range(0.0, 1.0)  = 0.18;

// Мировая позиция — пробрасываем из vertex в fragment
varying vec3 world_pos;

void vertex() {
	// MODEL_MATRIX переводит из локального пространства в мировое
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// ---- Noise ----
float hash2(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 74.3);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 6; i++) {
		v += a * vnoise(p);
		p  = p * 2.13 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// ---- Рябь (анизотропные волны) ----
float ripple(vec2 uv) {
	float warp = fbm(uv * 0.25) * 2.5;
	float r1 = sin((uv.x + warp) * TAU * 0.4) * 0.5 + 0.5;
	float r2 = sin((uv.x * 0.7 - uv.y * 0.3 + warp * 0.6) * TAU * 0.25) * 0.5 + 0.5;
	return mix(r1, r2, 0.4);
}

vec3 ripple_normal(vec2 uv, float strength) {
	float eps = 0.008;
	float dx = ripple(uv + vec2(eps, 0.0)) - ripple(uv - vec2(eps, 0.0));
	float dy = ripple(uv + vec2(0.0, eps)) - ripple(uv - vec2(0.0, eps));
	return normalize(vec3(-dx * strength, -dy * strength * 0.5, 1.0));
}

void fragment() {
	// UV из мировых координат — правильный тайлинг независимо от размера меша
	vec2 uv = vec2(world_pos.x, world_pos.z) * texture_scale;

	// Крупный шум → цвет
	float macro = fbm(uv * 0.14);
	float r     = ripple(uv);

	vec3 col = mix(sand_dark, sand_mid, smoothstep(0.2, 0.6, macro));
	col       = mix(col, sand_light, smoothstep(0.35, 0.75, r) * 0.65);

	// Мелкий гравий / тёмные пятна
	float spots = smoothstep(0.82, 0.88, fbm(uv * 0.8));
	col = mix(col, sand_dark * 0.7, spots * 0.35);

	// Рябь → нормаль
	vec3 n_ripple = ripple_normal(uv, ripple_strength);
	vec3 n_dune   = ripple_normal(uv * 0.08, 0.3);
	vec3 n_final  = normalize(mix(n_dune, n_ripple, 0.75));

	ALBEDO       = col;
	ROUGHNESS    = clamp(roughness_base - r * 0.18 + spots * 0.08, 0.55, 1.0);
	SPECULAR     = specular_amt;
	NORMAL_MAP   = n_final * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = ripple_strength;
}
