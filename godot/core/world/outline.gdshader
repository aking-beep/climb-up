shader_type canvas_item;
// A one-pixel dark outline around a sprite, so people read against rock of
// any colour (the art's own soft outline vanishes on dark rock).

uniform vec4 line : source_color = vec4(0.07, 0.05, 0.07, 0.9);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.1) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
		a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		c = a > 0.5 ? line : vec4(0.0);
	}
	COLOR = c * tint;
}
