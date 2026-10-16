// Destello de impacto: mezcla el sprite con blanco conservando su silueta
// (equivale a setTintFill(0xffffff) de Phaser).
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
