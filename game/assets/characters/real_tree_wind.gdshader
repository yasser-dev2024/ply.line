shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D leaf_texture : source_color;
uniform float wind_strength = 0.075;
uniform float wind_speed = 1.15;

void vertex() {
	float height_mask = smoothstep(2.0, 11.5, VERTEX.y);
	float phase = TIME * wind_speed + MODEL_MATRIX[3].x * 0.17 + MODEL_MATRIX[3].z * 0.13;
	VERTEX.x += sin(phase + VERTEX.y * 0.34) * wind_strength * height_mask;
	VERTEX.z += cos(phase * 0.73 + VERTEX.y * 0.21) * wind_strength * 0.55 * height_mask;
}

void fragment() {
	vec4 leaf = texture(leaf_texture, UV);
	ALBEDO = leaf.rgb * vec3(0.48, 0.62, 0.42);
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.38;
	ROUGHNESS = 0.9;
}
