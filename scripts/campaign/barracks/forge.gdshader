shader_type canvas_item;
render_mode unshaded;

// One lookup, no particles or full-screen blur. Only the painted hot surfaces
// shimmer; stone, banners and the UI remain steady and easy to read.
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float heat = smoothstep(0.28, 0.65, source.r - source.b);
	float flicker = sin(TIME * 2.8 + UV.y * 30.0) * 0.025
		+ sin(TIME * 4.1 + UV.x * 41.0) * 0.015;
	COLOR = vec4(source.rgb * (0.92 + heat * flicker), source.a) * COLOR;
}
