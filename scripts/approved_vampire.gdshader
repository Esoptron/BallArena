shader_type canvas_item;
render_mode unshaded;

uniform bool body_layer = true;
uniform bool blue_variant = false;
uniform float status_brightness = 1.0;

void fragment() {
	float canvas_alpha = COLOR.a;
	vec4 original = texture(TEXTURE, UV);
	// The original background is blue-black; every character color is warmer.
	// Preserve source RGB. Only transparency is evaluated by the renderer.
	float warm = original.r - original.b;
	float alpha = smoothstep(0.004, 0.025, warm);
	if (max(max(original.r, original.g), original.b) < 0.075) {
		float neighbor = 0.0;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 sample_color = texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * 2.0).rgb;
				neighbor = max(neighbor, sample_color.r - sample_color.b);
			}
		}
		alpha = max(alpha, step(0.08, neighbor));
	}
	float pixel_y = UV.y / TEXTURE_PIXEL_SIZE.y;
	bool red = original.r > original.g * 1.6 && original.r > original.b * 1.8;
	bool is_body = pixel_y < 690.0 || (pixel_y < 790.0 && red);
	if (is_body != body_layer) {
		alpha = 0.0;
	}
	vec3 rgb = original.rgb;
	if (blue_variant && body_layer && red) {
		rgb = vec3(original.g * 0.65, original.r * 0.38, original.r);
	}
	COLOR = vec4(rgb * status_brightness, alpha * original.a * canvas_alpha);
}
