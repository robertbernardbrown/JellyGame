shader_type canvas_item;

uniform float energy : hint_range(0.0, 1.0) = 1.0;
uniform float time_val = 0.0;

void fragment() {
	vec2 center = UV - vec2(0.5);
	// Scale so screen corners reach ~1.0
	float dist = length(center) * 1.8;

	// Soft dark ring at screen edges
	float vignette = smoothstep(0.35, 1.0, dist);

	// Only kicks in below 40% energy, fully active near 0
	float intensity = smoothstep(0.4, 0.05, energy);

	// Pulse speed and strength increase as energy gets critical
	float pulse_speed = mix(2.0, 6.0, intensity);
	float pulse = sin(time_val * pulse_speed) * 0.5 + 0.5;
	float pulse_boost = smoothstep(0.15, 0.0, energy) * pulse * 0.4;

	float alpha = vignette * (intensity * 0.65 + pulse_boost);
	COLOR = vec4(0.75, 0.0, 0.05, clamp(alpha, 0.0, 0.8));
}
