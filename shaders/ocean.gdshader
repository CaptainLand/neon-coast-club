shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform vec3 deep_color : source_color = vec3(0.012, 0.105, 0.22);
uniform vec3 shallow_color : source_color = vec3(0.035, 0.46, 0.53);
uniform vec3 sunset_reflection : source_color = vec3(1.0, 0.38, 0.34);
uniform vec3 foam_color : source_color = vec3(0.78, 0.94, 0.92);
uniform float wave_height : hint_range(0.0, 0.8) = 0.24;
uniform float detail_wave_height : hint_range(0.0, 0.3) = 0.065;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.48;
uniform float tide_amplitude : hint_range(0.0, 0.5) = 0.11;
uniform float tide_speed : hint_range(0.0, 1.0) = 0.12;
uniform float foam_strength : hint_range(0.0, 2.0) = 0.82;
uniform float fresnel_strength : hint_range(0.0, 2.0) = 0.72;

varying float shore_factor;
varying float crest_factor;

void vertex() {
	float t = TIME * wave_speed;
	float broad_a = sin(VERTEX.x * 0.22 + t * 1.08);
	float broad_b = sin(VERTEX.z * 0.17 - t * 0.84 + VERTEX.x * 0.07);
	float crossed = cos((VERTEX.x - VERTEX.z) * 0.41 + t * 1.42);
	float detail = sin(VERTEX.x * 0.88 + VERTEX.z * 0.63 - t * 2.1);
	shore_factor = smoothstep(68.0, 90.0, VERTEX.z);
	float tide = sin(TIME * tide_speed) * tide_amplitude * (0.30 + shore_factor * 0.70);
	float displacement = (broad_a * 0.48 + broad_b * 0.34 + crossed * 0.18) * wave_height + detail * detail_wave_height;
	VERTEX.y += displacement + tide;
	crest_factor = clamp(displacement / max(wave_height + detail_wave_height, 0.001) * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 uv_a = UV * vec2(18.0, 31.0) + vec2(t * 0.021, -t * 0.038);
	vec2 uv_b = UV * vec2(27.0, 16.0) + vec2(-t * 0.032, t * 0.018);
	float fine_a = sin(uv_a.x + sin(uv_a.y * 0.73));
	float fine_b = cos(uv_b.y + sin(uv_b.x * 0.81));
	vec2 slope = vec2(fine_a, fine_b) * 0.13;
	NORMAL_MAP = normalize(vec3(0.5 + slope.x, 0.5 + slope.y, 1.0));
	NORMAL_MAP_DEPTH = 0.48;

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.2) * fresnel_strength;
	float micro = 0.5 + 0.5 * sin((UV.x * 63.0 + UV.y * 47.0) + t * 2.4);
	vec3 water = mix(deep_color, shallow_color, clamp(shore_factor * 0.62 + crest_factor * 0.22 + micro * 0.05, 0.0, 1.0));
	float sun_band = pow(max(0.0, 1.0 - abs(UV.x - 0.32) * 5.5), 5.0) * (0.25 + fresnel);
	water = mix(water, sunset_reflection, clamp(sun_band * 0.42, 0.0, 0.55));

	float wash = sin(UV.x * 48.0 + t * 2.2 + sin(UV.x * 9.0)) * 0.5 + 0.5;
	float foam = shore_factor * smoothstep(0.56, 0.76, wash + crest_factor * 0.28) * foam_strength;
	foam += smoothstep(0.82, 0.98, crest_factor) * 0.12;
	ALBEDO = mix(water, foam_color, clamp(foam, 0.0, 0.78));
	EMISSION = foam_color * foam * 0.16;
	ROUGHNESS = mix(0.22, 0.48, clamp(foam, 0.0, 1.0));
	METALLIC = 0.06;
	SPECULAR = 0.86;
}
