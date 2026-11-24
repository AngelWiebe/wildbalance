shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_always;

uniform vec4 season_tint : source_color = vec4(1.0);

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float flow = p.y + TIME * 1.15;
	float a = sin(p.x * 4.9 + flow * 3.6 + sin(flow * 1.7));
	float b = sin(p.x * -10.0 + flow * 5.3 + sin(p.x * 2.0) * 1.4);
	float c = cos(p.x * 1.6 + flow * 8.0);
	NORMAL = normalize(NORMAL + vec3(a * 0.09 + b * 0.025, b * 0.06, c * 0.025));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float river = 7.5 + 2.3 * sin(p.y * 0.105) + 0.85 * sin(p.y * 0.23);
	float edge = smoothstep(1.10, 1.62, abs(p.x - river));
	float foam = edge * smoothstep(0.73, 0.99, a * b) * (0.5 + 0.5 * c);
	ALBEDO = mix(vec3(0.025, 0.101, 0.088), vec3(0.35, 0.52, 0.49), fresnel);
	ALBEDO += foam * vec3(0.36, 0.43, 0.41);
	ALBEDO *= season_tint.rgb;
	ROUGHNESS = 0.17;
	SPECULAR = 0.55;
	ALPHA = clamp(0.63 + fresnel * 0.32 + foam, 0.0, 1.0);
}
