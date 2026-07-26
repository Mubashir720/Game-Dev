shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.08, 0.06, 0.12, 1.0);
uniform float outline_thickness : hint_range(0.0, 0.05) = 0.015;

void vertex() {
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
