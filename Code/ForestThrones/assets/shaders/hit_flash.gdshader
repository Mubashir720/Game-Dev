shader_type spatial;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_color = ALBEDO == vec3(0.0) ? vec4(1.0) : vec4(ALBEDO, 1.0);
	ALBEDO = mix(tex_color.rgb, flash_color.rgb, flash_modifier);
	EMISSION = flash_color.rgb * flash_modifier * 2.0;
}
