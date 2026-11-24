shader_type spatial;

uniform vec4 season_tint : source_color = vec4(1.0);

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float river = 7.5 + 2.3 * sin(p.y * 0.105) + 0.85 * sin(p.y * 0.23);
	float bank = abs(p.x - river);
	float moss = 0.64 * noise(p * 0.37) + 0.36 * noise(p * 2.6);
	float grit = noise(p * 37.0);
	vec3 earth = mix(vec3(0.060, 0.041, 0.023), vec3(0.120, 0.097, 0.048), moss);
	vec3 turf = mix(vec3(0.049, 0.075, 0.023), vec3(0.158, 0.199, 0.064), moss);
	vec3 gravel = mix(vec3(0.058, 0.063, 0.052), vec3(0.235, 0.211, 0.154), grit);
	vec3 forest = mix(earth, turf, smoothstep(0.24, 0.65, moss));
	ALBEDO = mix(gravel, forest, smoothstep(1.5, 3.15, bank + (moss - 0.5) * 1.7));
	ALBEDO *= mix(0.72, 1.2, grit);
	ALBEDO *= season_tint.rgb;
	ROUGHNESS = 0.91;
}
