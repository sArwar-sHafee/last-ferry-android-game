shader_type canvas_item;
render_mode unshaded;

uniform vec2 lantern;
uniform float flash : hint_range(0.0, 1.0);

void fragment() {
	vec2 from_lantern = UV * vec2(960.0, 540.0) - lantern;
	float falloff = smoothstep(42.0, 150.0, length(from_lantern));
	vec3 night = vec3(0.026, 0.042, 0.076);
	vec3 amber = vec3(0.94, 0.66, 0.34);
	vec3 ambient = mix(amber, night, falloff);
	float shade = mix(0.10, 0.94, falloff);
	// The lantern still illuminates the near ground during a distant flash.
	vec4 afterglow = vec4(0.60, 0.69, 0.85, mix(0.08, 0.20, falloff));
	COLOR = mix(vec4(ambient, shade), afterglow, flash);
}
