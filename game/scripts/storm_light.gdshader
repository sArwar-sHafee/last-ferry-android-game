shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scenery : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 lantern;
uniform float outward = 1.0;
uniform float flame = 1.0;
uniform float flash : hint_range(0.0, 1.0);

void fragment() {
	vec3 surface = texture(scenery, SCREEN_UV).rgb;
	vec2 offset = UV * vec2(960.0, 540.0) - lantern;
	// The cap limits upward spill. The keeper shades the side behind the glass.
	vec2 spread = vec2(offset.x, offset.y * (offset.y < 0.0 ? 1.35 : 1.1));
	float radius_sq = dot(spread, spread);
	float spill = (1.0 - smoothstep(44.0 * 44.0, 88.0 * 88.0, radius_sq))
			/ (1.0 + radius_sq / (27.0 * 27.0));
	float shade = 1.0 - 0.65 * smoothstep(5.0, 26.0, -offset.x * outward);
	float light = spill * shade * flame;

	vec3 dark = mix(surface, vec3(0.026, 0.042, 0.076), 0.95);
	vec3 reflected = surface * vec3(1.55, 1.00, 0.57) * light;
	float bloom = exp(-dot(offset, offset) / 44.0) * flame;
	vec3 firelight = dark + reflected + vec3(0.32, 0.16, 0.052) * bloom;
	vec3 afterglow = mix(surface, vec3(0.60, 0.69, 0.85), mix(0.20, 0.08, min(light, 1.0)));
	COLOR = vec4(mix(firelight, afterglow, flash), 1.0);
}
