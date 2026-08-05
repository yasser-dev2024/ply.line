shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.18, 0.42, 0.23, 1.0);
uniform float wind_strength = 0.08;
uniform float wind_speed = 1.35;

varying float height_tint;
varying vec3 instance_tint;

void vertex() {
	float upper = clamp(VERTEX.y * 0.75 + 0.55, 0.0, 1.0);
	float world_phase = MODEL_MATRIX[3].x * 0.17 + MODEL_MATRIX[3].z * 0.11;
	float gust = sin(TIME * wind_speed + world_phase + VERTEX.y * 1.7);
	float secondary = sin(TIME * wind_speed * 0.47 + world_phase * 2.3 + VERTEX.x * 2.0);
	VERTEX.x += (gust + secondary * 0.28) * wind_strength * upper;
	VERTEX.z += cos(TIME * wind_speed * 0.73 + world_phase) * wind_strength * 0.45 * upper;
	height_tint = upper;
	instance_tint = max(INSTANCE_CUSTOM.rgb, vec3(0.72));
}

void fragment() {
	ALBEDO = base_color.rgb * instance_tint * mix(0.78, 1.08, height_tint);
	ROUGHNESS = 0.93;
}
