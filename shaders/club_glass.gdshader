shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 glass_tint : source_color = vec4(0.18,0.72,0.78,0.22);
uniform float refraction_strength : hint_range(0.0,0.08) = 0.018;
uniform float roughness : hint_range(0.0,1.0) = 0.12;
void fragment() {
	float ripple=sin(UV.y*86.0+sin(UV.x*31.0)*2.0)*0.5+0.5;
	vec2 distortion=vec2(dFdx(ripple),dFdy(ripple))*refraction_strength;
	vec3 behind=textureLod(screen_texture,SCREEN_UV+distortion,roughness*4.0).rgb;
	float fresnel=pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),4.0);
	ALBEDO=mix(behind,glass_tint.rgb,0.22+fresnel*0.34);
	METALLIC=0.18; ROUGHNESS=roughness+ripple*0.035;
	NORMAL_MAP=vec3((ripple-0.5)*0.07,(0.5-ripple)*0.04,1.0); NORMAL_MAP_DEPTH=0.24;
	EMISSION=glass_tint.rgb*fresnel*0.18; ALPHA=glass_tint.a+fresnel*0.34;
}
