shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D albedo_texture : source_color;
uniform sampler2D normal_texture : hint_normal;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform bool use_normal = false;
uniform float roughness : hint_range(0.0, 1.0) = 0.88;
uniform float wind_strength : hint_range(0.0, 0.1) = 0.032;
uniform float height_reference = 1.3;

void vertex() {
	float crown = pow(clamp(VERTEX.y / max(height_reference, 0.08), 0.0, 1.0), 1.55);
	float phase = INSTANCE_CUSTOM.r * 6.28318;
	float gust = sin(TIME * 1.15 + phase) * 0.68 + sin(TIME * 2.3 + phase * 1.7) * 0.32;
	VERTEX.x += gust * wind_strength * crown;
	VERTEX.z += cos(TIME * 0.82 + phase) * wind_strength * crown * 0.55;
}

void fragment() {
	vec4 sampled = texture(albedo_texture, UV) * albedo_tint;
	ALBEDO = sampled.rgb;
	if (use_normal) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = 0.72;
	}
	ROUGHNESS = roughness;
}
