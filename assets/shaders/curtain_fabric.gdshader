shader_type spatial;
render_mode cull_disabled;
// Cortina de tecido: pregas verticais (normal perturbada, sem custo de geometria), trama fina e translucidez falsa:
// com sol atrás da cortina fechada o tecido brilha por dentro (backlight).
// A perturbação de normal com ruído de valor segue a ideia do "Procedural Cloth Wrinkles Shader" de
// Yui Kinomoto (arlez80), MIT License, https://godotshaders.com/shader/procedural-cloth-wrinkles-shader/

uniform vec3 cloth_color : source_color = vec3(0.37, 0.48, 0.66);
uniform float folds = 9.0;
uniform float fold_depth : hint_range(0.0, 1.5) = 0.7;
uniform float backlight : hint_range(0.0, 1.0) = 0.0;
uniform vec3 backlight_color : source_color = vec3(1.0, 0.85, 0.6);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	// UV.x corre pela largura da folha; as pregas variam um pouco com a altura.
	float sway = value_noise(vec2(UV.x * 4.0, UV.y * 2.5)) * 0.6;
	float phase = UV.x * folds * 6.2831853 + sway * 2.0;
	float wave = sin(phase);
	float weave = value_noise(vec2(UV.x * 90.0, UV.y * 160.0));
	vec3 bent = normalize(NORMAL + TANGENT * wave * fold_depth);
	NORMAL = bent;
	float valley = 0.5 + 0.5 * wave;
	ALBEDO = cloth_color * (0.78 + 0.22 * valley) * (0.94 + 0.06 * weave);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	// Luz atravessando o tecido: mais forte nos cumes das pregas, que são mais finos.
	EMISSION = backlight_color * backlight * 0.55 * (0.55 + 0.45 * valley) * cloth_color * 1.6;
}
