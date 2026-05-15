shader_type canvas_item;

uniform sampler2D under_texture;
uniform float fill_amount : hint_range(0.0, 1.0) = 1.0;
uniform float time_val = 0.0;

void fragment() {
	// Wave grows from nothing at 50% energy to full intensity at empty
	float intensity = smoothstep(0.5, 0.0, fill_amount);
	float wave = sin(UV.y * 25.566 + time_val * 2.0) * 0.06 * intensity;
	vec2 uv = vec2(UV.x + wave, UV.y);

	vec4 under = texture(under_texture, uv);
	vec4 progress = texture(TEXTURE, uv);

	float filled = step(1.0 - fill_amount, UV.y);
	COLOR = mix(under, progress, filled);
}
