shader_type canvas_item;

// 0.0 = empty, 1.0 = full
uniform float fill_amount : hint_range(0.0, 1.0) = 1.0;
// UV.x where the yellow bar begins (just past the plankton icon / red line)
uniform float fill_start : hint_range(0.0, 1.0) = 0.072;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	float right_edge = fill_start + fill_amount * (1.0 - fill_start);
	float in_bar = step(fill_start, UV.x) * step(UV.x, right_edge);
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tex.rgb * tint_color.rgb, tex.a * in_bar * tint_color.a);
}
