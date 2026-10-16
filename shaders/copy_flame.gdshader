shader_type canvas_item;
render_mode unshaded;
uniform sampler2D flame_texture : source_color, filter_linear;

float hash(vec2 p) {
	p = fract(p*vec2(123.34,345.45));
	p += dot(p,p+34.345);
	return fract(p.x*p.y);
}
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	float t=TIME*1.35+COLOR.a*11.0;
	float h=1.0-UV.y;
	float flow=noise(vec2(UV.x*5.0,UV.y*5.0+t*1.7));
	vec2 uv=UV;
	// Keep the pointed base steady while the crown and side tongue sway.
	uv.x += (sin(t*1.8+h*5.5)*.020 + (flow-.5)*.023)*h*h;
	uv.y += sin(t*2.3+UV.x*7.0)*.012*h;
	vec4 flame=texture(flame_texture,clamp(uv,vec2(.001),vec2(.999)));
	flame.rgb *= 1.0+(flow-.5)*.10;
	float glow=exp(-dot(vec2((UV.x-.51)*3.6,(UV.y-.60)*2.8),vec2((UV.x-.51)*3.6,(UV.y-.60)*2.8))*2.0)*.12;
	// Two tiny advected embers, computed in the same quad (no particle nodes).
	float a=fract(t*.32);
	float b=fract(t*.26+.47);
	vec2 ea=(UV-vec2(.13+sin(t*1.1)*.018,.63-a*.43))/vec2(.020,.048);
	vec2 eb=(UV-vec2(.88+sin(t*.9)*.014,.51-b*.34))/vec2(.016,.040);
	float ember=(1.0-smoothstep(.15,1.0,dot(ea,ea)))*sin(a*3.14159);
	ember+=(1.0-smoothstep(.15,1.0,dot(eb,eb)))*sin(b*3.14159)*.72;
	float alpha=flame.a+glow*(1.0-flame.a)+ember*(1.0-flame.a);
	vec3 rgb=(flame.rgb*flame.a+vec3(1.0,.34,.02)*glow*(1.0-flame.a)+vec3(1.0,.70,.14)*ember*(1.0-flame.a))/max(alpha,.001);
	COLOR=vec4(rgb,clamp(alpha,0.0,1.0));
}
