shader_type canvas_item;
// A place's own rock: the painted cliff tiles are recoloured through a
// ramp (dark to light) so one set of paintings becomes black lava, mossy
// forest earth, olive moorland basalt or blue glacier ice. The texture's
// light and shade (its detail) are kept; only the colours change. `amount`
// 0 leaves the painting as it is.

uniform sampler2D ramp : filter_linear, repeat_disable;
uniform float amount = 1.0;
// Lifts or deepens the painting's light and shade before the ramp.
uniform float contrast = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	l = clamp((l - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 m = texture(ramp, vec2(l, 0.5)).rgb;
	COLOR = vec4(mix(c.rgb, m, amount), c.a) * COLOR;
}
