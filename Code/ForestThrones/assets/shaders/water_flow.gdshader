shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx, depth_draw_always, world_vertex_coords;

// ─────────────────────────────────────────────────────────────────────────
//  FLOWING WATER SHADER
//  Two counter-scrolling noise layers create a real moving-current look
//  (river ripple + cross-chop), with scrolling foam streaks along the flow
//  direction, a fresnel-driven bank/edge highlight, and a fake normal
//  perturbation so the surface catches light dynamically instead of sitting
//  as one flat translucent color.
// ─────────────────────────────────────────────────────────────────────────

uniform vec4 shallow_color : source_color = vec4(0.14, 0.42, 0.62, 0.72);
uniform vec4 deep_color : source_color = vec4(0.04, 0.15, 0.30, 0.92);
uniform vec2 flow_direction = vec2(0.12, 1.0);
uniform float flow_speed : hint_range(0.0, 3.0) = 0.55;
uniform float wave_scale : hint_range(0.2, 10.0) = 2.4;
uniform float foam_amount : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_pos;

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

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	vec2 dir = normalize(flow_direction);
	float t = TIME * flow_speed;

	vec2 uv1 = world_pos.xz * 0.22 * wave_scale + dir * t;
	vec2 uv2 = world_pos.xz * 0.55 * wave_scale - dir * t * 1.6 + vec2(4.2, 1.3);
	vec2 uv3 = world_pos.xz * 0.9 * wave_scale + vec2(dir.y, -dir.x) * t * 0.8;

	float n1 = value_noise(uv1);
	float n2 = value_noise(uv2);
	float n3 = value_noise(uv3);
	float ripple = clamp(n1 * 0.5 + n2 * 0.35 + n3 * 0.25, 0.0, 1.0);

	vec3 col = mix(deep_color.rgb, shallow_color.rgb, ripple);

	// Scrolling foam streaks stretched along the current direction
	vec2 foam_uv = world_pos.xz * vec2(0.6, 0.12) * wave_scale + dir * t * 1.8;
	float foam_n = value_noise(foam_uv) * 0.7 + value_noise(foam_uv * 2.3 + 9.0) * 0.3;
	float foam = smoothstep(0.72, 0.92, foam_n) * foam_amount;
	col = mix(col, vec3(0.88, 0.94, 0.97), foam);

	// Fresnel-style edge brightening so banks/shorelines read distinctly
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	col += fresnel * 0.12;

	ALBEDO = col;
	ALPHA = mix(deep_color.a, shallow_color.a, ripple);
	ROUGHNESS = 0.06;
	METALLIC = 0.55;
	SPECULAR = 0.9;
	EMISSION = col * 0.10;

	// Fake rippled normal so lighting shifts across the surface as it "flows"
	NORMAL_MAP = normalize(vec3((n1 - 0.5) * 0.4, (n2 - 0.5) * 0.4, 1.0)) * 0.5 + vec3(0.5, 0.5, 0.5);
	NORMAL_MAP_DEPTH = 0.6;
}
