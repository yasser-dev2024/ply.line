shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color;
uniform vec4 albedo_color : source_color = vec4(0.78, 0.54, 0.24, 1.0);
uniform bool use_texture = false;
uniform float gait_speed = 0.0;
uniform float motion_amount = 0.0;
uniform float attack_mix = 0.0;
uniform float hurt_mix = 0.0;

varying float mane_mask;

void vertex() {
	float phase = TIME * gait_speed;
	float low_body = 1.0 - smoothstep(2.5, 3.9, VERTEX.y);
	float front_leg = 1.0 - smoothstep(-2.4, -0.4, VERTEX.z);
	float rear_leg = smoothstep(0.2, 2.3, VERTEX.z);
	float left_side = step(0.0, VERTEX.x);
	float side_phase = mix(0.0, 3.14159, left_side);
	float leg_phase = mix(phase, phase + 3.14159, rear_leg) + side_phase;
	VERTEX.z += sin(leg_phase) * 0.72 * low_body * max(front_leg, rear_leg) * motion_amount;
	VERTEX.y += abs(sin(phase * 0.5)) * 0.11 * motion_amount;

	float head_mask = 1.0 - smoothstep(-4.9, -2.3, VERTEX.z);
	VERTEX.y += sin(phase * 0.5) * 0.09 * head_mask * motion_amount;
	VERTEX.z -= attack_mix * head_mask * 0.85;
	VERTEX.y -= attack_mix * head_mask * 0.4;
	VERTEX.x += sin(VERTEX.y * 3.4 + TIME * 22.0) * hurt_mix * 0.035;

	float tail_mask = smoothstep(3.2, 5.2, VERTEX.z);
	VERTEX.x += sin(phase * 0.55 + VERTEX.z) * 0.65 * tail_mask * (0.35 + motion_amount);
	mane_mask = head_mask * smoothstep(2.7, 5.8, VERTEX.y);
}

void fragment() {
	vec4 base = albedo_color;
	if (use_texture) {
		base *= texture(albedo_texture, UV);
	}
	base.rgb *= vec3(0.64, 0.55, 0.43);
	base.rgb = mix(base.rgb, base.rgb * vec3(0.31, 0.22, 0.16), mane_mask * 0.62);
	base.rgb = mix(base.rgb, vec3(0.34, 0.06, 0.035), hurt_mix * 0.34);
	ALBEDO = base.rgb;
	ALPHA = base.a;
	ROUGHNESS = 0.82;
}
