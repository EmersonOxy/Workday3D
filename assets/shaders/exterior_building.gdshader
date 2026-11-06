shader_type spatial;
// Prédios fora da janela: fachada com grade de janelas que acendem à noite (emissão) e escurecem com o céu.

uniform vec3 wall_color : source_color = vec3(0.34, 0.38, 0.46);
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 1.0;

varying vec3 v_world;
varying vec3 v_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float u = abs(v_normal.x) > 0.5 ? v_world.z : v_world.x;
	vec2 grid = vec2(u * 0.55, v_world.y * 0.42);
	vec2 cell = floor(grid);
	vec2 f = fract(grid);
	float pane = step(0.2, f.x) * step(f.x, 0.8) * step(0.25, f.y) * step(f.y, 0.78);
	float lit = step(0.55, hash(cell)) * pane * (abs(v_normal.y) < 0.5 ? 1.0 : 0.0);
	vec3 base = wall_color * mix(1.0, 0.25, night);
	ALBEDO = mix(base, base * 0.55 + vec3(0.1, 0.14, 0.2) * (1.0 - night), pane);
	EMISSION = vec3(1.0, 0.82, 0.45) * lit * night * 1.6;
	ROUGHNESS = 0.95;
}
