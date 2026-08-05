shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley;

uniform vec4 shallow_color : source_color = vec4(0.07, 0.38, 0.45, 0.76);

varying float wave_height;

void vertex() {
	float wave_a = sin((VERTEX.x * 1.9 + VERTEX.z * 0.7) + TIME * 1.7);
	float wave_b = sin((VERTEX.z * 2.7 - VERTEX.x * 0.5) - TIME * 1.15);
	wave_height = (wave_a + wave_b) * 0.5;
	VERTEX.y += wave_height * 0.035;
}

void fragment() {
	float wave_a = sin((UV.x * 23.0 + UV.y * 8.0) + TIME * 1.8);
	float wave_b = sin((UV.y * 31.0 - UV.x * 5.0) - TIME * 1.15);
	float ripple = (wave_a + wave_b) * 0.5;
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	vec3 deep_color = shallow_color.rgb * vec3(0.55, 0.8, 0.9);
	vec3 reflection_color = vec3(0.48, 0.67, 0.72);
	ALBEDO = mix(deep_color, reflection_color, fresnel * 0.72) + vec3(0.02, 0.07, 0.075) * (ripple + wave_height);
	ROUGHNESS = mix(0.28, 0.08, fresnel);
	METALLIC = 0.04;
	ALPHA = mix(shallow_color.a, 0.9, fresnel);
}
