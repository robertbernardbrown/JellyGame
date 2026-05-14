shader_type canvas_item;

uniform float time_val = 0.0;
uniform float wave_strength = 0.005;
uniform float wave_speed = 1.0;

void fragment() {
	vec2 uv = UV;
	uv.x += sin(uv.y * 8.0 + time_val * wave_speed) * wave_strength;
	uv.y += sin(uv.x * 5.0 + time_val * wave_speed * 0.7) * wave_strength * 0.5;
	COLOR = texture(TEXTURE, uv);
}
