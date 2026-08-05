shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin_texture : source_color;
uniform vec3 jacket_color : source_color = vec3(0.19, 0.27, 0.18);
uniform vec3 trouser_color : source_color = vec3(0.105, 0.135, 0.115);
uniform vec3 glove_color : source_color = vec3(0.07, 0.085, 0.075);

varying float model_height;
varying vec3 model_position;

void vertex() {
	model_height = VERTEX.y;
	model_position = VERTEX;
}

void fragment() {
	vec3 skin = texture(skin_texture, UV).rgb;
	float weave = 0.92 + 0.08 * sin(model_position.x * 95.0) * sin(model_position.y * 82.0);
	float head = smoothstep(1.63, 1.76, model_height);
	float upper_body = smoothstep(0.92, 1.08, model_height) * (1.0 - head);
	float lower_body = 1.0 - smoothstep(0.94, 1.08, model_height);
	vec3 dressed = mix(trouser_color, jacket_color, upper_body) * weave;
	float hands_or_boots = step(abs(model_position.x), 0.12) * (1.0 - smoothstep(0.28, 0.46, model_height));
	dressed = mix(dressed, glove_color, hands_or_boots * lower_body);
	ALBEDO = mix(dressed, skin, head);
	ROUGHNESS = mix(0.92, 0.76, head);
	EMISSION = ALBEDO * 0.045;
	RIM = 0.32;
	RIM_TINT = 0.62;
}
