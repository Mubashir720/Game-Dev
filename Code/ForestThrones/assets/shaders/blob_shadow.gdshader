shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// ═══════════════════════════════════════════════════════════════════════════════
//  BLOB SHADOW — soft grounding shadow under every actor.
//
//  The real directional-light shadow tells you where the sun is. This tells you
//  where the character's FEET are, which is the thing a player actually needs on
//  an isometric camera — without it, characters read as floating stickers.
//
//  It is a single unshaded quad with a radial falloff, so it costs one tiny draw
//  call and no shadow-map work at all. depth_draw_never keeps it from fighting
//  the terrain, and the soft edge hides the fact that it is a flat plane sitting
//  on sloped ground.
// ═══════════════════════════════════════════════════════════════════════════════

uniform vec4 shadow_color : source_color = vec4(0.02, 0.03, 0.02, 0.55);
uniform float softness : hint_range(0.05, 1.0) = 0.55;
uniform float radius : hint_range(0.1, 1.0) = 0.48;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d) / max(radius, 0.001);
	float a = 1.0 - smoothstep(1.0 - softness, 1.0, dist);
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_color.a * a;
}
