shader_type spatial;
render_mode unshaded, cull_disabled;
// Tela CRT do monitor do WorkOS: curvatura leve, linhas de varredura, separação de cor e cantos escuros.
// Suave o bastante para o texto do WorkOS continuar legível de perto. Sem curvatura por padrão: o clique
// do mouse é mapeado na tela plana, e a curvatura deslocaria a imagem em relação ao ponteiro.

uniform sampler2D screen_texture : source_color, filter_linear;
uniform float curvature : hint_range(0.0, 0.3) = 0.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_count = 360.0;
uniform float chroma_offset : hint_range(0.0, 0.004) = 0.0006;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float brightness : hint_range(0.5, 1.5) = 1.08;

void fragment() {
	// Mesma inversão horizontal do material antigo da tela (uv1_scale.x = -1).
	vec2 uv = vec2(1.0 - UV.x, UV.y);
	vec2 centered = uv * 2.0 - 1.0;
	centered *= 1.0 + curvature * dot(centered, centered) * vec2(0.25, 0.35);
	uv = centered * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		ALBEDO = vec3(0.0);
	} else {
		vec3 color;
		color.r = texture(screen_texture, uv + vec2(chroma_offset, 0.0)).r;
		color.g = texture(screen_texture, uv).g;
		color.b = texture(screen_texture, uv - vec2(chroma_offset, 0.0)).b;
		float scan = 1.0 - scanline_strength * (0.5 + 0.5 * cos(uv.y * scanline_count * 6.2831853));
		float edge = smoothstep(1.0, 0.25, length(centered * vec2(0.85, 1.0))) ;
		color *= scan * mix(1.0, edge, vignette) * brightness;
		ALBEDO = color;
	}
}
