shader_type canvas_item;
// The lens over the world: a colour grade (shadows toward a cool tint,
// lights toward a warm one, a touch more contrast and saturation) and a
// vignette. With `graded` off it is only the vignette, drawn as a dark
// overlay, which costs no screen read (the "Low power" setting).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec3 shadow_tint = vec3(0.9, 0.9, 1.04);
uniform vec3 light_tint = vec3(1.06, 1.01, 0.93);
uniform float contrast = 1.07;
uniform float saturation = 1.1;
uniform float strength = 0.42;
uniform bool graded = true;

void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.38, 0.88, length(uv * vec2(1.25, 1.0)));
	if (!graded) {
		COLOR = vec4(0.05, 0.035, 0.05, v * strength * 0.9);
	} else {
		vec3 c = texture(screen_tex, SCREEN_UV).rgb;
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c * shadow_tint, c * light_tint, smoothstep(0.12, 0.7, l));
		c = mix(vec3(l), c, saturation);
		c = (c - 0.5) * contrast + 0.5;
		c = mix(c, c * vec3(0.32, 0.27, 0.33), v * strength);
		COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
	}
}
