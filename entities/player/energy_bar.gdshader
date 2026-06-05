shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	float filled = step(abs(UV.x - 0.5), fill_amount * 0.5);
	COLOR = mix(vec4(0.0), texture(TEXTURE, UV) * tint_color, filled);
}
