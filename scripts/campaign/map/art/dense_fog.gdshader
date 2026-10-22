shader_type canvas_item;
render_mode unshaded;

uniform sampler2D mist_noise : repeat_enable, filter_linear_mipmap;
uniform float drift = 0.0;
uniform float density : hint_range(0.0,1.0) = 0.98;
uniform vec4 deep_colour : source_color = vec4(0.09,0.14,0.20,1.0);
uniform vec4 light_colour : source_color = vec4(0.30,0.38,0.46,1.0);

void fragment() {
	// Three inexpensive samples from one small seamless noise texture. The
	// effect occupies the terminal rectangle, never a full-screen postprocess.
	float a=texture(mist_noise,UV*vec2(1.4,0.8)+vec2(drift*0.009,-drift*0.012)).r;
	float b=texture(mist_noise,UV*vec2(2.8,1.7)+vec2(-drift*0.016,drift*0.007)).r;
	float c=texture(mist_noise,UV*vec2(0.9,1.3)+vec2(drift*0.005,drift*0.004)).r;
	float billow=a*0.52+b*0.26+c*0.22;
	float edge=smoothstep(0.0,0.31,UV.x+(a-0.5)*0.19);
	float opacity=edge*density*(0.94+0.06*billow);
	vec3 colour=mix(deep_colour.rgb,light_colour.rgb,clamp(billow*0.75+0.12,0.0,1.0));
	COLOR=vec4(colour,opacity);
}
