shader_type spatial;
uniform vec3 cyan_color : source_color = vec3(0.10, 0.82, 0.92);
uniform vec3 pink_color : source_color = vec3(1.0, 0.20, 0.62);
uniform float emission_strength : hint_range(0.0, 4.0) = 1.15;
uniform float grid_scale : hint_range(2.0, 40.0) = 14.0;
uniform float animation_speed : hint_range(0.0, 2.0) = 0.18;
void fragment() {
	vec2 p = UV * grid_scale;
	vec2 line = 1.0 - smoothstep(vec2(0.025), vec2(0.075), abs(fract(p) - 0.5));
	float grid = max(line.x, line.y);
	float drift = 0.5 + 0.5 * sin(TIME * animation_speed + UV.x * 4.0);
	vec3 glow = mix(cyan_color, pink_color, drift);
	float breathe = 0.86 + 0.14 * sin(TIME * animation_speed * 1.7);
	ALBEDO = vec3(0.035, 0.025, 0.11) + glow * grid * 0.10;
	EMISSION = glow * grid * emission_strength * breathe;
	ROUGHNESS = 0.24; METALLIC = 0.18;
}

