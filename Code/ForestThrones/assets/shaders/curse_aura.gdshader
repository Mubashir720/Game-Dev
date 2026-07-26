shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform vec4 aura_color : source_color = vec4(0.8, 0.1, 0.2, 0.7);
uniform float pulse_speed : hint_range(0.5, 5.0) = 2.5;

void fragment() {
	float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * 0.4 + 0.6;
	ALBEDO = aura_color.rgb * pulse;
	ALPHA = aura_color.a * pulse * (1.0 - UV.y);
}
