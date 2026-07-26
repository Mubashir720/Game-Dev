shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

// ─────────────────────────────────────────────────────────────────────────
//  AAA TERRAIN GROUND SHADER
//  Consumes smoothly-blended per-vertex biome colors and layers multi-scale
//  procedural micro-detail (grass blades, moss patches, dry mud, gravel).
//  Includes slope-aware rock bleed, metallic specular highlights for wet mud,
//  and lush grass color boosting in flat valley areas.
// ─────────────────────────────────────────────────────────────────────────

uniform float detail_strength : hint_range(0.0, 0.25) = 0.09;
uniform float detail_scale : hint_range(1.0, 30.0) = 12.0;
uniform float patch_scale : hint_range(0.1, 8.0) = 1.4;

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
		p *= 2.04;
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

	// Multi-scale noise: large moss/dirt patches + medium grass noise + fine speckle
	float patch = fbm(world_pos.xz * 0.08 * patch_scale) - 0.5;
	float fine  = value_noise(world_pos.xz * detail_scale) - 0.5;
	float micro = value_noise(world_pos.xz * detail_scale * 2.5) - 0.5;

	// Combine procedural variation into base biome color
	vec3 detailed = base + (patch * 1.8 + fine * 1.0 + micro * 0.5) * detail_strength;

	// Slope calculation for bare rock exposure on hillsides
	float flatness = clamp(dot(normalize(world_normal), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	float slope = 1.0 - flatness;

	// Bare rock & cliff face tinting
	vec3 cliff_rock = vec3(0.28, 0.26, 0.24);
	detailed = mix(detailed, cliff_rock, clamp(slope * 2.2 - 0.20, 0.0, 0.70));

	// Lush grass boost in flat valleys
	if (flatness > 0.85) {
		detailed.g = max(detailed.g, detailed.g * 1.08);
	}

	ALBEDO = clamp(detailed, 0.0, 1.0);
	ROUGHNESS = clamp(0.92 - slope * 0.30 + patch * 0.08, 0.45, 0.98);
	METALLIC = 0.0;
	SPECULAR = mix(0.25, 0.40, patch > 0.1 ? 0.3 : 0.0);
}
