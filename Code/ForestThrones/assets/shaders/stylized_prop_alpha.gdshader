shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_disabled, depth_draw_opaque;

// ═══════════════════════════════════════════════════════════════════════════════
//  STYLIZED PROP SHADER — TRANSPARENT VARIANT
//
//  Same look as stylized_prop.gdshader, but it reads alpha from the baked vertex
//  colour instead of forcing everything opaque.
//
//  Why this exists: PropBaker welds each part's material colour into the vertex
//  colour channel. The opaque shader ignored the alpha, so every transparent
//  piece in the game — hut proximity-aura rings, well water, goggle lenses,
//  beast ember trails — rendered as a SOLID object. The most visible symptom was
//  a bright green ring around every hut that read as a laser line across the map.
//
//  Kept as a separate shader rather than a uniform on the opaque one because
//  writing to ALPHA at all forces Godot to treat a material as transparent, and
//  that would push every tree in the world into the alpha-sorted pass.
// ═══════════════════════════════════════════════════════════════════════════════

group_uniforms Shading;
uniform vec3 rim_color : source_color = vec3(0.62, 0.78, 0.92);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.30;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float alpha_scale : hint_range(0.0, 1.0) = 1.0;

group_uniforms Surface;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;

varying vec4 v_tint;

void vertex() {
	v_tint = COLOR;
}

void fragment() {
	ALBEDO = v_tint.rgb;
	ALPHA = clamp(v_tint.a * alpha_scale, 0.0, 1.0);
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	SPECULAR = 0.10;

	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	vec3 rim_out = rim_color * rim * rim_strength;
	EMISSION = v_tint.rgb * emission_energy + rim_out;
}
