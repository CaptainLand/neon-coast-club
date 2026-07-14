shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale = vec2(6.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float roughness_base : hint_range(0.0,1.0) = 0.55;
uniform float metallic_base : hint_range(0.0,1.0) = 0.08;
uniform float normal_strength : hint_range(0.0,2.0) = 0.55;
uniform float ao_strength : hint_range(0.0,1.0) = 0.35;

float height_sample(vec2 uv) {
	vec3 c=texture(albedo_texture,uv).rgb;
	return dot(c,vec3(0.299,0.587,0.114));
}

void fragment() {
	vec2 uv=UV*uv_scale;
	vec4 tex=texture(albedo_texture,uv);
	vec2 px=1.0/vec2(textureSize(albedo_texture,0));
	float h=height_sample(uv);
	float hx=height_sample(uv+vec2(px.x,0.0))-height_sample(uv-vec2(px.x,0.0));
	float hy=height_sample(uv+vec2(0.0,px.y))-height_sample(uv-vec2(0.0,px.y));
	ALBEDO=tex.rgb*tint;
	NORMAL_MAP=vec3(-hx*normal_strength,-hy*normal_strength,1.0);
	NORMAL_MAP_DEPTH=normal_strength;
	ROUGHNESS=clamp(roughness_base+(0.5-h)*0.28,0.08,0.96);
	METALLIC=clamp(metallic_base+smoothstep(0.62,0.92,h)*0.34,0.0,0.72);
	AO=mix(1.0,clamp(h*1.25,0.34,1.0),ao_strength);
}
