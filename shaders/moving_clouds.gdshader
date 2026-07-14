shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never;

uniform vec4 day_color : source_color = vec4(0.92,0.82,0.92,0.22);
uniform vec4 night_color : source_color = vec4(0.22,0.25,0.48,0.10);
uniform float daylight : hint_range(0.0,1.0) = 0.5;

float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){
	vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float fbm(vec2 p){ float v=0.0,a=0.5; for(int i=0;i<5;i++){v+=noise(p)*a;p=p*2.03+17.2;a*=0.5;}return v; }
void fragment(){
	vec2 p=UV*vec2(7.0,3.0)+vec2(TIME*0.006,TIME*0.0015);
	float cloud=smoothstep(0.54,0.76,fbm(p)+fbm(p*0.47+9.0)*0.34);
	float horizon=smoothstep(0.04,0.30,abs(UV.y-0.5));
	vec4 color=mix(night_color,day_color,daylight);
	ALBEDO=color.rgb; EMISSION=color.rgb*0.10; ALPHA=cloud*color.a*horizon;
}
