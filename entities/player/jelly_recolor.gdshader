shader_type canvas_item;

// region_mask channels flag which part a pixel belongs to: R = bell top, G = dots, B = tentacles.
// A pixel with all channels near zero (outline, or anywhere left unpainted) is never recolored.
uniform sampler2D region_mask : filter_nearest, repeat_disable;

// Stock hues below match the original art exactly, so custom_amount = 0.0 renders pixel-identical
// to before this shader existed.
uniform vec4 top_color : source_color = vec4(0.8588, 0.2078, 0.5882, 1.0);
uniform vec4 dot_color : source_color = vec4(0.1725, 0.0157, 0.0667, 1.0);
uniform vec4 tentacle_color : source_color = vec4(0.5412, 0.1216, 0.7490, 1.0);
uniform float custom_amount : hint_range(0.0, 1.0) = 0.0;

uniform float flash : hint_range(0.0, 1.0) = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

// Takes hue + saturation from target_rgb but keeps original_rgb's value, so the art's existing
// shading/highlight pattern survives being recolored to any hue/saturation the player picks.
vec3 recolor(vec3 original_rgb, vec3 target_rgb) {
	float original_value = rgb2hsv(original_rgb).z;
	vec3 target_hsv = rgb2hsv(target_rgb);
	return hsv2rgb(vec3(target_hsv.x, target_hsv.y, original_value));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 mask = texture(region_mask, UV);
	vec3 result = tex.rgb;
	if (mask.r > 0.5) {
		result = mix(tex.rgb, recolor(tex.rgb, top_color.rgb), custom_amount);
	} else if (mask.g > 0.5) {
		result = mix(tex.rgb, recolor(tex.rgb, dot_color.rgb), custom_amount);
	} else if (mask.b > 0.5) {
		result = mix(tex.rgb, recolor(tex.rgb, tentacle_color.rgb), custom_amount);
	}
	result = mix(result, vec3(0.7, 1.0, 1.0), flash);
	COLOR = vec4(result, tex.a);
}
