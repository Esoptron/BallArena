shader_type canvas_item;
render_mode unshaded;

uniform float fang_radius = 35.0;
uniform float mist_clock = 0.0;
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

float cross2(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0));
}

float tooth_distance(vec2 p, float x, float width, float height) {
	vec2 a = vec2(x - width, -0.58);
	vec2 b = vec2(x - width * 0.68, -height * 0.73);
	vec2 c = vec2(x - sign(x) * 0.07, -height);
	vec2 d = vec2(x + width * 0.68, -height * 0.73);
	vec2 e = vec2(x + width, -0.58);
	float distance = min(min(segment_distance(p, a, b), segment_distance(p, b, c)),
		min(min(segment_distance(p, c, d), segment_distance(p, d, e)), segment_distance(p, e, a)));
	bool inside = cross2(b - a, p - a) >= 0.0 && cross2(c - b, p - b) >= 0.0
		&& cross2(d - c, p - c) >= 0.0 && cross2(e - d, p - d) >= 0.0
		&& cross2(a - e, p - e) >= 0.0;
	return inside ? -distance : distance;
}

void fragment() {
	vec2 p = fang_position;
	float distance = min(min(tooth_distance(p, -0.66, 0.22, 1.85),
		tooth_distance(p, -0.24, 0.16, 1.52)),
		min(tooth_distance(p, 0.24, 0.16, 1.52), tooth_distance(p, 0.66, 0.22, 1.85)));
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
