shader_type spatial;
render_mode blend_mix, cull_back;

// ═══════════════════════════════════════════════════════════════════════════════
//  STYLIZED PROP SHADER  ·  v2 "studio pass"
//
//  One shader for every baked prop, character, beast and structure in the game.
//  It is the single biggest lever on how expensive the game looks, and it is
//  nearly free: every object already shares one material and renders through
//  MultiMesh, so improving this improves the entire game at one draw-call cost.
//
//  WHAT CHANGED FROM v1 (and why it reads as "big budget" now):
//    • Toon ramp lighting — a custom light() bands the key light into 3 soft
//      tones instead of a smooth photographic gradient. This is THE difference
//      between "hobby low-poly" and "painted mobile hit" (Brawl Stars, Clash).
//      The earlier failed attempt threw away ambient + shadow softening; this one
//      keeps ambient (Godot fills AMBIENT_LIGHT independently of light()) and
//      multiplies by ATTENUATION so real shadows still soften the bands.
//    • Real materials — metallic is now threaded in from the baker, so armour,
//      swords, coins, crowns and mint-gold catch a bright specular and read as
//      metal instead of painted plastic. Cloth/fur/wood stay matte.
//    • Colour grade — a gentle saturation + contrast lift counteracts the muddy,
//      desaturated look the filmic tonemapper leaves on flat vertex colours.
//    • Stronger rim + sky bounce — silhouettes separate cleanly from the terrain.
//    • Wind sway — unchanged; canopies breathe, trunks stay planted.
//
//  Albedo rides in the vertex-colour channel, where the baker welds each part's
//  original material colour; MultiMesh per-instance colour modulates it, giving
//  hundreds of shades from one material and one draw call.
// ═══════════════════════════════════════════════════════════════════════════════

group_uniforms Wind;
uniform float sway_strength : hint_range(0.0, 0.6) = 0.0;
uniform float sway_speed : hint_range(0.0, 4.0) = 1.1;
uniform float sway_base_height : hint_range(0.01, 4.0) = 0.6;

group_uniforms Shading;
uniform vec3 rim_color : source_color = vec3(0.66, 0.82, 0.98);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.55;
uniform float rim_power : hint_range(0.5, 8.0) = 2.6;
uniform float contact_shade : hint_range(0.0, 1.0) = 0.40;
uniform float contact_height : hint_range(0.05, 4.0) = 1.10;
uniform float top_light : hint_range(0.0, 0.6) = 0.12;

group_uniforms Toon;
// How hard the light bands. 0 = smooth (photographic), 1 = crisp cel edges.
uniform float band_sharpness : hint_range(0.0, 1.0) = 0.55;
// Brightness of the darkest lit band, so the shadow side keeps its hue.
uniform float shade_floor : hint_range(0.0, 1.0) = 0.42;
uniform float light_wrap : hint_range(0.0, 0.6) = 0.22;

group_uniforms Grade;
uniform float saturation : hint_range(0.0, 2.0) = 1.14;
uniform float contrast : hint_range(0.5, 1.6) = 1.04;
uniform float brightness : hint_range(0.5, 1.5) = 1.02;

group_uniforms Surface;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;

varying float v_contact;
varying float v_up;
varying vec3 v_tint;

vec3 apply_grade(vec3 c) {
	// saturation around luminance
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, saturation);
	// contrast around mid-grey, then brightness
	c = (c - 0.5) * contrast + 0.5;
	c *= brightness;
	return max(c, vec3(0.0));
}

void vertex() {
	if (sway_strength > 0.001) {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		float phase = world.x * 0.35 + world.z * 0.27;
		float t = TIME * sway_speed;
		float wave = sin(t + phase) * 0.7 + sin(t * 1.73 + phase * 2.1) * 0.3;
		float lean = clamp((h - sway_base_height) / max(sway_base_height, 0.001), 0.0, 2.0);
		VERTEX.x += wave * lean * sway_strength;
		VERTEX.z += wave * 0.6 * lean * sway_strength;
	}

	v_contact = clamp(max(VERTEX.y, 0.0) / contact_height, 0.0, 1.0);
	v_up = clamp(NORMAL.y, 0.0, 1.0);
	v_tint = COLOR.rgb;
}

void fragment() {
	vec3 base = apply_grade(v_tint);

	// Contact shading — darken toward the base so objects look planted.
	base *= mix(1.0 - contact_shade, 1.0, v_contact);
	// Sky bounce — upward faces lift slightly, giving round shapes volume.
	base *= 1.0 + v_up * top_light;

	ALBEDO = base;
	ROUGHNESS = mix(roughness_value, 0.18, metallic_value);
	METALLIC = metallic_value;
	SPECULAR = mix(0.14, 0.55, metallic_value);

	// Rim light as emission: view-dependent silhouette separation that survives
	// shadow, so an object in shade still reads as a distinct shape. Metal gets a
	// hotter rim so it reads as a glinting edge.
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	// Rim only on the upper/side of forms (fades on down-facing) so it reads as a
	// light edge, not a glowing outline all the way around.
	rim *= clamp(0.4 + 0.6 * v_up + 0.3, 0.0, 1.0);
	vec3 rim_out = rim_color * rim * (rim_strength + metallic_value * 0.35);

	if (emission_energy > 0.001) {
		EMISSION = base * emission_energy + rim_out;
	} else {
		EMISSION = rim_out;
	}
}

// Toon ramp. Called once per light; ambient/GI is added by the engine separately
// into AMBIENT_LIGHT, so the shadow side keeps colour instead of going black.
void light() {
	vec3 N = normalize(NORMAL);
	vec3 L = normalize(LIGHT);
	// Half-lambert wrap softens the terminator so round shapes don't hard-clip.
	float ndl = dot(N, L);
	float w = clamp((ndl + light_wrap) / (1.0 + light_wrap), 0.0, 1.0);

	// Three soft bands. band_sharpness controls edge crispness; at 0 this is a
	// near-smooth gradient, at 1 it is crisp cel steps.
	float e = mix(0.16, 0.02, band_sharpness);
	float b1 = smoothstep(0.30 - e, 0.30 + e, w);
	float b2 = smoothstep(0.62 - e, 0.62 + e, w);
	float ramp = shade_floor + (1.0 - shade_floor) * (b1 * 0.55 + b2 * 0.45);

	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * ramp;

	// Stylised specular — a tight painted glint, essentially metal-only so matte
	// cloth/fur/wood never blow out. Non-metal keeps a whisper of sheen.
	vec3 H = normalize(normalize(VIEW) + L);
	float nh = max(dot(N, H), 0.0);
	float shine = pow(nh, mix(56.0, 100.0, metallic_value));
	shine = smoothstep(0.4, 0.7, shine);
	float spec_amt = metallic_value * 1.1;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * shine * spec_amt;
}
