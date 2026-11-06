shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Feixe de luz (raios de sol ou luz de poste/lâmpada atravessando a janela). UV.y vai de 0 (janela) a 1 (ponta do feixe).
// Soma luz aditiva com poeira em movimento; a ponta, as bordas e os ângulos rasantes se dissolvem.
// O esmaecimento por ângulo de visão (Fresnel) vem da ideia do "Fake Godrays (Godot 4.x)" de Ivan Isaev, CC0,
// https://godotshaders.com/shader/fake-godrays-godot-4-2/

uniform vec3 shaft_color : source_color = vec3(1.0, 0.9, 0.65);
uniform float intensity : hint_range(0.0, 2.0) = 0.5;
uniform float dust_speed = 0.08;
uniform float rim_power : hint_range(0.2, 5.0) = 1.4;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);
	float fade = pow(1.0 - along, 1.4) * smoothstep(0.0, 0.04, along);
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	// Face de frente para o olho fica forte; a que aparece de lado some (dá a sensação de volume).
	float facing = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), rim_power);
	float dust = 0.6 + 0.4 * noise(vec2(UV.x * 7.0 + TIME * dust_speed, UV.y * 9.0 - TIME * dust_speed * 2.0));
	float grain = 0.8 + 0.2 * noise(vec2(UV.x * 26.0, UV.y * 4.0 - TIME * dust_speed * 3.0));
	ALBEDO = shaft_color * intensity * fade * edge * dust * grain * (0.25 + 0.75 * facing);
}
