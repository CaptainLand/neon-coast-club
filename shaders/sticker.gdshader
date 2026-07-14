shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform sampler2D sticker_texture : source_color;
uniform vec3 rarity_color : source_color = vec3(0.25,0.65,1.0);
uniform float foil_strength : hint_range(0.0,1.0) = 0.0;

void fragment() {
	vec2 centered=UV-vec2(0.5);
	float circle=1.0-smoothstep(0.485,0.505,length(centered));
	vec4 tex=texture(sticker_texture,UV);
	float sweep=0.5+0.5*sin((UV.x+UV.y)*18.0-TIME*1.8);
	float glint=pow(max(0.0,1.0-abs(fract(UV.x*2.2+TIME*0.16)-0.5)*2.0),10.0);
	vec3 iridescence=0.5+0.5*cos(6.28318*(vec3(0.0,0.33,0.67)+UV.x+UV.y+TIME*0.04));
	vec3 foil=mix(rarity_color,iridescence,0.58)*foil_strength*(sweep*0.22+glint*0.55);
	ALBEDO=tex.rgb+foil;
	EMISSION=foil*0.45;
	ALPHA=tex.a*circle;
}
