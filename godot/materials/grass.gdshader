shader_type spatial;
render_mode cull_disabled;

void vertex() {
	float tip = smoothstep(0.03, 0.45, VERTEX.y);
	vec2 patch_position = MODEL_MATRIX[3].xz;
	float wind = sin(
		TIME * 1.45
		+ patch_position.x * 0.42
		+ patch_position.y * 0.31
	);

	VERTEX.x += wind * 0.075 * tip;
	VERTEX.z += cos(
		TIME * 1.08
		+ patch_position.x * 0.23
	) * 0.045 * tip;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.94;
}