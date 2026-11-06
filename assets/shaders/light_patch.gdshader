shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Mancha de luz no chão: a janela (vidros e divisões) projetada por uma luz de fora, somada ao piso.
// A geometria da mancha é calculada em office_lighting.gd projetando os cantos da janela a partir do poste.

uniform sampler2D pattern : filter_linear, repeat_disable;
uniform vec3 patch_color : source_color = vec3(1.0, 0.8, 0.5);
uniform float intensity : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	float mask = texture(pattern, UV).r;
	// Esmaece com a distância ao centro da mancha para não parecer um recorte duro.
	float soft = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x) * smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.82, UV.y);
	ALBEDO = patch_color * mask * intensity * (0.4 + 0.6 * soft);
}
