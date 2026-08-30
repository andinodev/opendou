shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 base_color : source_color = vec4(0.1, 0.85, 1.0, 0.45);
uniform vec4 occluded_color : source_color = vec4(1.0, 0.35, 0.1, 0.45);
uniform float wave_speed : hint_range(0.1, 10.0) = 3.0;
uniform float wave_frequency : hint_range(0.5, 20.0) = 4.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	float dist = length(UV - vec2(0.5));
	float wave = sin((dist * wave_frequency - TIME * wave_speed) * 6.28318) * 0.5 + 0.5;
	vec4 final_col = mix(COLOR, base_color, 0.25);
	ALBEDO = final_col.rgb * (1.0 + wave * pulse_intensity);
	ALPHA = clamp(final_col.a * (0.5 + 0.5 * wave), 0.0, 1.0);
}
