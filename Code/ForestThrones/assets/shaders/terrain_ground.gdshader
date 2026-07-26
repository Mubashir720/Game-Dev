shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

// ─────────────────────────────────────────────────────────────────────────
//  TERRAIN GROUND SHADER
//  Consumes smoothly-blended per-vertex biome colors (baked in COLOR by the
//  continuous terrain mesh builder) and layers procedural micro-detail on
//  top so large flat regions never read as a single dead-flat tile color.
//  Adds a faint triplanar rock bleed on steep slopes and a subtle sheen so
//  wet/mossy areas catch light differently than dry clearings.
// ─────────────────────────────────────────────────────────────────────────

uniform float detail_strength : hint_range(0.0, 0.2) = 0.055;
uniform float detail_scale : hint_range(1.0, 20.0) = 6.0;
uniform float large_scale : hint_range(0.1, 5.0) = 0.9;

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

	// Large rolling blotches (patchy dry/lush grass variation, moss patches)
	float big = fbm(world_pos.xz * 0.06 * large_scale) - 0.5;

	// Fine speckle so close-up ground never looks flat-painted
	float fine = value_noise(world_pos.xz * detail_scale) - 0.5;

	vec3 detailed = base + big * detail_strength * 1.6 + fine * detail_strength;

	// Slope-aware rock bleed: steep faces show more bare rock/dirt regardless of biome
	float slope = 1.0 - clamp(dot(normalize(world_normal), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	vec3 rock_tint = vec3(0.34, 0.33, 0.30);
	detailed = mix(detailed, rock_tint, clamp(slope * 1.6 - 0.15, 0.0, 0.55));

	ALBEDO = clamp(detailed, 0.0, 1.0);
	ROUGHNESS = clamp(0.95 - slope * 0.25, 0.55, 0.98);
	METALLIC = 0.0;
	SPECULAR = 0.25;
}
