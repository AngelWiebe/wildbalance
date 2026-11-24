shader_type spatial;
render_mode cull_disabled;

varying vec3 branch_position;

void vertex() {
	float height_factor = pow(max(VERTEX.y, 0.0), 1.65);
	vec2 tree_position = MODEL_MATRIX[3].xz;
	float sway = sin(
		TIME * 0.85
		+ tree_position.x * 0.27
		+ tree_position.y * 0.19
	);

	VERTEX.x += sway * 0.10 * height_factor;
	VERTEX.z += cos(TIME * 0.66 + tree_position.x * 0.16) * 0.045 * height_factor;

	branch_position = VERTEX;
}

void fragment() {
	float sprays = sin(branch_position.x * 173.0 + branch_position.z * 99.0);
	float needles = cos(branch_position.z * 247.0 - branch_position.x * 163.0);
	float detail = sprays * needles;
	float edge = min(UV.x, min(UV.y, 1.0 - UV.x - UV.y));
	if (edge < 0.045 + detail * 0.060 && detail > -0.24) {
		discard;
	}
	ALBEDO = vec3(0.041, 0.077, 0.040) * COLOR.rgb * (1.08 + detail * 0.32);
	ROUGHNESS = 0.92;
	BACKLIGHT = vec3(0.037, 0.067, 0.026);
}
