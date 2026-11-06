shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;
// Cúpula de céu vista pelas janelas: gradiente dia/entardecer/noite, sol, lua e estrelas por direção.

uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float low_sun : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sun_dir = vec3(0.0, 0.7, 0.7);
uniform vec3 moon_dir = vec3(0.0, 0.7, -0.7);
uniform vec3 top_day : source_color = vec3(0.3, 0.55, 0.95);
uniform vec3 horizon_day : source_color = vec3(0.78, 0.9, 1.0);
uniform vec3 top_night : source_color = vec3(0.012, 0.02, 0.08);
uniform vec3 horizon_night : source_color = vec3(0.06, 0.08, 0.2);
uniform vec3 sunset : source_color = vec3(1.0, 0.5, 0.25);

varying vec3 v_dir;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * vnoise(p);
		p = p * 2.03 + vec2(17.1, 5.3);
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	v_dir = normalize(VERTEX);
}

void fragment() {
	vec3 d = normalize(v_dir);
	float h = clamp(d.y, 0.0, 1.0);
	vec3 day = mix(horizon_day, top_day, pow(h, 0.6));
	vec3 night = mix(horizon_night, top_night, pow(h, 0.5));
	vec3 col = mix(night, day, daylight);
	float toward_sun = max(dot(d, normalize(sun_dir)), 0.0);
	col = mix(col, sunset, low_sun * pow(toward_sun, 3.0) * 0.9 * clamp(daylight * 2.0, 0.0, 1.0));
	col = mix(col, sunset * 0.8, low_sun * smoothstep(0.35, 0.0, h) * 0.55 * clamp(daylight * 2.0, 0.0, 1.0));
	// Sol com halo.
	col += vec3(1.0, 0.85, 0.55) * pow(toward_sun, 40.0) * 0.6 * daylight;
	col = mix(col, vec3(1.0, 0.96, 0.8), smoothstep(0.9993, 0.9998, toward_sun) * clamp(daylight * 3.0, 0.0, 1.0));
	// Lua.
	float toward_moon = max(dot(d, normalize(moon_dir)), 0.0);
	col = mix(col, vec3(0.92, 0.95, 1.0), smoothstep(0.9995, 0.9999, toward_moon) * (1.0 - daylight));
	col += vec3(0.5, 0.6, 0.9) * pow(toward_moon, 60.0) * 0.18 * (1.0 - daylight);
	// Nuvens: ruído fractal num plano projetado, tingidas pelo sol (brancas de dia, rosadas no entardecer, escuras à noite).
	if (d.y > 0.02) {
		vec2 cp = d.xz / (d.y + 0.35) * 1.5 + vec2(TIME * 0.004, TIME * 0.0015);
		float cloud = smoothstep(0.5, 0.8, fbm(cp)) * smoothstep(0.02, 0.22, d.y);
		vec3 cloud_col = mix(vec3(0.16, 0.18, 0.28), vec3(1.0), daylight);
		cloud_col = mix(cloud_col, sunset * 1.15, low_sun * 0.7 * daylight);
		cloud_col *= 0.82 + 0.18 * vnoise(cp * 3.0);
		col = mix(col, cloud_col, cloud * 0.85);
	}
	// Estrelas.
	vec3 cell = floor(d * 160.0);
	float star = step(0.9965, hash3(cell)) * (1.0 - daylight) * smoothstep(0.05, 0.35, h);
	col += vec3(star);
	ALBEDO = col;
}
