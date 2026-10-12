shader_type canvas_item;
render_mode unshaded;

uniform float fang_radius = 35.0;
uniform float mist_clock = 0.0;
uniform vec2 tooth_vertices[56];
varying vec2 fang_position;

void vertex() {
	fang_position = VERTEX / max(fang_radius, 1.0);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

float fog(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(13.7, 5.3);
		amplitude *= 0.5;
	}
	return value;
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / max(dot(ab, ab), 0.000001), 0.0, 1.0));
}

void fragment() {
	vec2 p = fang_position;
	float distance = 10.0;
	for (int i = 0; i < 56; i++) {
		int next = (i % 14 == 13) ? i - 13 : i + 1;
		distance = min(distance, segment_distance(p, tooth_vertices[i], tooth_vertices[next]));
	}
	vec2 drift = vec2(sin(mist_clock * 0.65) * 0.12, mist_clock * 0.16);
	float broad = fog(p * 4.8 + drift);
	float detail = fog(p * 12.0 + vec2(-mist_clock * 0.10, mist_clock * 0.27));
	float warped_distance = distance + (broad - 0.5) * 0.10;
	// A feathered, broken cloud band separated slightly from each tooth.
	float band = exp(-pow((warped_distance - 0.16) / 0.13, 2.0));
	float gap = smoothstep(0.015, 0.085, distance);
	float density = smoothstep(0.23, 0.70, broad * 0.72 + detail * 0.28);
	float alpha = band * gap * density * 0.70;
	vec3 violet = mix(vec3(0.32, 0.045, 0.70), vec3(0.72, 0.31, 0.96), detail);
	COLOR = vec4(violet, alpha);
}
