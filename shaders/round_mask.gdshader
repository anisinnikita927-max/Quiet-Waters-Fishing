shader_type canvas_item;

uniform vec4 ring_color : source_color = vec4(0.89, 0.71, 0.46, 0.0);
uniform float ring_width = 0.035;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 2.0;
	float edge = fwidth(d) * 1.5;
	float mask = 1.0 - smoothstep(1.0 - edge, 1.0, d);
	vec4 c = texture(TEXTURE, UV);
	float ring = smoothstep(1.0 - ring_width - edge, 1.0 - ring_width, d) * ring_color.a;
	COLOR = vec4(mix(c.rgb, ring_color.rgb, ring), 1.0) * mask;
}
