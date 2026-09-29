shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float speed = 1.0;
uniform float offset = 0.0;
uniform vec3 color_a : source_color = vec3(0.1, 1.0, 0.55);
uniform vec3 color_b : source_color = vec3(0.65, 0.25, 0.95);

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed + offset;
	float wave = sin(uv.x * 7.0 + t * 0.35) * 0.5 + sin(uv.x * 17.0 - t * 0.6) * 0.25 + sin(uv.x * 3.0 + t * 0.15) * 0.4;
	float y = uv.y - 0.5 - wave * 0.09;
	float curtain = smoothstep(-0.45, 0.02, y) * (1.0 - smoothstep(0.0, 0.5, y));
	float rays = 0.55 + 0.45 * sin(uv.x * 90.0 + sin(uv.x * 11.0 + t) * 3.0);
	float edge = smoothstep(0.0, 0.08, uv.x) * (1.0 - smoothstep(0.92, 1.0, uv.x));
	vec3 col = mix(color_a, color_b, smoothstep(0.35, 0.95, uv.y + wave * 0.1));
	ALBEDO = col * curtain * rays * edge * 0.85;
}
