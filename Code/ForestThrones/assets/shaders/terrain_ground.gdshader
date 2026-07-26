shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

// ─────────────────────────────────────────────────────────────────────────
//  TERRAIN GROUND SHADER v2 — AAA Dark Fantasy Battle Royale Shader
//  Blends rich per-vertex biome colors with organic multi-frequency noise
//  and slope-aware slate rock/mud layers for max visual depth.
// ─────────────────────────────────────────────────────────────────────────

uniform float detail_strength : hint_range(0.0, 0.2) = 0.045;
uniform float detail_scale : hint_range(1.0, 20.0) = 8.0;
uniform float large_scale : hint_range(0.1, 5.0) = 1.2;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amp;
		p *= 2.02;
		amp *= 0.5;
	}
	return total;
}

void vertex() {
	world_pos = VERTEX;
	world_normal = NORMAL;
}

void fragment() {
	vec3 base = COLOR.rgb;

	// Rich rolling micro-noise patches (natural sunlit moss vs shade variation)
	float big = fbm(world_pos.xz * 0.08 * large_scale) - 0.5;
	float fine = value_noise(world_pos.xz * detail_scale) - 0.5;
	vec3 detailed = base + big * detail_strength * 1.5 + fine * detail_strength * 0.7;

	// Natural slope stone bleed (only on steep cliff faces > 45 degrees, avoiding flat ground wash-out)
	float slope = 1.0 - clamp(dot(normalize(world_normal), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	vec3 rock_tint = vec3(0.22, 0.23, 0.25); // Dark slate granite stone
	detailed = mix(detailed, rock_tint, smoothstep(0.42, 0.80, slope) * 0.65);

	ALBEDO = clamp(detailed, 0.0, 1.0);
	ROUGHNESS = clamp(0.92 - slope * 0.20, 0.55, 0.96);
	METALLIC = 0.0;
	SPECULAR = 0.25;
}
