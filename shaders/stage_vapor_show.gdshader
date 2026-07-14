shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 cyan : source_color = vec3(0.10,0.92,1.0);
uniform vec3 pink : source_color = vec3(1.0,0.16,0.62);
uniform vec3 violet : source_color = vec3(0.34,0.12,0.62);
uniform sampler2D poster_texture : source_color, filter_linear_mipmap_anisotropic;

float hash(float n){return fract(sin(n)*43758.5453);}
float building(vec2 p,float x,float w,float h){return step(abs(p.x-x),w)*step(p.y,-0.04+h)*step(-0.52,p.y);}

void fragment(){
	vec2 uv=UV;
	vec2 p=uv*2.0-1.0;
	float beat=0.94+0.06*pow(max(0.0,sin(TIME*2.35)),8.0);
	vec3 poster=texture(poster_texture,uv).rgb;
	vec3 col=poster;
	float scan=0.975+0.025*sin(uv.y*720.0+TIME*5.0);
	float vignette=1.0-smoothstep(0.72,1.38,length(p*vec2(0.76,1.0)))*0.14;
	float glitch=step(0.985,hash(floor(TIME*8.0)))*step(0.82,fract(uv.y*13.0+TIME));
	col=mix(col,col.bgr,glitch*0.12);
	ALBEDO=col*scan*vignette*beat; EMISSION=col*(0.82+beat*0.26);
}
