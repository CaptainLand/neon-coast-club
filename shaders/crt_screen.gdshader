shader_type spatial;
render_mode unshaded;
uniform vec3 screen_color : source_color = vec3(0.12, 0.86, 0.78);
uniform float brightness = 1.5;
uniform float powered = 0.0;
uniform float channel = 0.0;

float line(vec2 p, float width) { return 1.0-smoothstep(width,width+0.012,abs(p.y)); }
float box_mask(vec2 p, vec2 b) { vec2 d=abs(p)-b; return 1.0-smoothstep(0.0,0.025,max(d.x,d.y)); }

vec3 sunset_tape(vec2 uv) {
	vec2 p=uv*2.0-1.0;
	float horizon=0.48;
	float sun=1.0-smoothstep(0.22,0.235,length(p-vec2(0.28,0.18)));
	float stripes=step(0.48,fract((p.y+TIME*0.045)*16.0));
	sun*=mix(0.42,1.0,stripes);
	vec3 col=mix(vec3(0.035,0.015,0.12),vec3(0.85,0.12,0.46),uv.y);
	col+=sun*vec3(1.0,0.42,0.18)*2.0;
	if (uv.y>horizon) {
		float z=1.0/max(0.04,uv.y-horizon);
		float gx=1.0-smoothstep(0.035,0.075,abs(fract((uv.x-0.5)*z*1.4+TIME*0.35)-0.5));
		float gy=1.0-smoothstep(0.035,0.075,abs(fract(z*0.18-TIME*0.7)-0.5));
		col+=vec3(0.08,0.9,1.0)*(gx+gy)*0.48;
	}
	return col;
}

vec3 city_tape(vec2 uv) {
	vec2 p=uv*2.0-1.0; p.x+=sin(TIME*0.38)*0.22;
	vec3 col=mix(vec3(0.02,0.01,0.09),vec3(0.18,0.03,0.28),uv.y);
	for(int i=0;i<7;i++){
		float fi=float(i); float x=-0.92+fi*0.31+sin(fi*4.1)*0.035;
		float h=0.25+fract(sin(fi*19.23)*43.1)*0.55;
		float building=box_mask(p-vec2(x,0.72-h*0.5),vec2(0.12,h*0.5));
		float windows=step(0.72,fract((p.x-x)*25.0))*step(0.68,fract((p.y+fi)*20.0+TIME*0.8));
		col=mix(col,vec3(0.035,0.055,0.14)+windows*vec3(0.1,0.85,1.0),building);
	}
	float road=line(vec2(p.x+sin(p.y*8.0+TIME)*0.02,p.y-0.62),0.018);
	col+=road*vec3(1.0,0.1,0.55)*1.4;
	return col;
}

vec3 ocean_tape(vec2 uv) {
	vec2 p=uv*2.0-1.0;
	vec3 col=mix(vec3(0.02,0.12,0.20),vec3(0.78,0.18,0.52),1.0-uv.y);
	float sun=1.0-smoothstep(0.18,0.20,length(p-vec2(-0.32,-0.18)));
	col+=sun*vec3(1.0,0.65,0.3);
	for(int i=0;i<7;i++){
		float fi=float(i); float wave=line(vec2(p.x,p.y-0.05-fi*0.12-sin(p.x*(5.0+fi)+TIME*(0.7+fi*0.08))*0.035),0.012);
		col+=wave*mix(vec3(0.1,0.9,0.95),vec3(0.95,0.25,0.72),fi/7.0)*0.55;
	}
	return col;
}

void fragment() {
	vec2 uv = UV; vec2 centered = uv * 2.0 - 1.0;
	uv += centered * dot(centered, centered) * 0.012;
	float scan = 0.90 + 0.10 * sin(uv.y * 620.0);
	float noise = fract(sin(dot(floor(uv * 220.0 + TIME*9.0), vec2(12.9898,78.233))) * 43758.5453);
	vec3 tape=sunset_tape(uv);
	if(channel>0.5) tape=city_tape(uv);
	if(channel>1.5) tape=ocean_tape(uv);
	float edge=1.0-smoothstep(0.82,1.02,length(centered*vec2(0.82,1.0)));
	vec3 standby=screen_color*(0.035+noise*0.018);
	vec3 color=mix(standby,tape+noise*0.035,powered)*scan*edge;
	color*=0.96+0.04*sin(TIME*19.0);
	ALBEDO = color; EMISSION = color * brightness;
}
