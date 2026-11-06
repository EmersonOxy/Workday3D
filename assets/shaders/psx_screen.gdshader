shader_type canvas_item;
// Pós-processamento PSX do mundo 3D: baixa resolução, poucas cores e pontilhado ordenado (Bayer 4x4).

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform float color_levels : hint_range(4.0, 64.0, 1.0) = 48.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.3;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / pixel_size);
	vec2 uv = (cell * pixel_size + pixel_size * 0.5) / screen_size;
	vec3 color = texture(screen_texture, uv).rgb;
	int index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	float threshold = (BAYER[index] / 16.0 - 0.5) * dither_strength;
	color = floor(color * (color_levels - 1.0) + 0.5 + threshold) / (color_levels - 1.0);
	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
