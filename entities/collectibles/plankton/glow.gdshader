shader_type canvas_item;

uniform float time_val = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float pulse = sin(time_val * 2.5) * 0.5 + 0.5;

	// Cycle between cool cyan and warm yellow — bioluminescent feel
	vec3 tint = mix(vec3(0.2, 1.0, 0.9), vec3(1.0, 0.95, 0.1), pulse);

	// Additive glow so it clearly brightens even dark pixels
	COLOR.rgb = tex.rgb + tint * 0.8 * pulse;
	COLOR.a = tex.a;
}
