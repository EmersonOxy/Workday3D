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
	// Estrelas.
	vec3 cell = floor(d * 160.0);
	float star = step(0.9965, hash3(cell)) * (1.0 - daylight) * smoothstep(0.05, 0.35, h);
	col += vec3(star);
	ALBEDO = col;
}
