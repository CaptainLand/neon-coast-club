shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_back;
uniform vec3 tint : source_color = vec3(0.16, 0.72, 0.82);
uniform float opacity : hint_range(0.0, 1.0) = 0.20;
void fragment() { ALBEDO = tint; ALPHA = opacity; ROUGHNESS = 0.12; METALLIC = 0.05; }

