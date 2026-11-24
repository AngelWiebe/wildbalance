shader_type spatial;

varying vec3 trunk_position;

void vertex() {
	trunk_position = VERTEX;
}

void fragment() {
	float angle = atan(trunk_position.z, trunk_position.x);
	float grain = sin(angle * 24.0 + sin(trunk_position.y * 20.0 + angle * 3.0) * 0.8);
	grain += sin(angle * 51.0 + trunk_position.y * 9.0) * 0.54;
	float ridges = smoothstep(-1.05, 1.12, grain);
	float knots = sin(trunk_position.y * 63.0 + angle * 8.0) * cos(angle * 13.0);
	ALBEDO = mix(vec3(0.038, 0.026, 0.018), vec3(0.115, 0.077, 0.046), ridges) * COLOR.rgb;
	ALBEDO *= 0.89 + knots * 0.12;
	ROUGHNESS = 0.96;
}
