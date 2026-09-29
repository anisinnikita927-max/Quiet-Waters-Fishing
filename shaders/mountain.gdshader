shader_type spatial;

uniform vec4 stone : source_color = vec4(0.3, 0.38, 0.4, 1.0);
uniform vec4 snow : source_color = vec4(0.9, 0.95, 0.93, 1.0);
uniform float snow_line = 9.0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = sin(wpos.x * 0.55) * sin(wpos.z * 0.45) * 0.9 + sin(wpos.x * 1.3 + wpos.y * 0.7) * 0.35;
	float m = smoothstep(snow_line - 1.2, snow_line + 1.4, wpos.y + n);
	float shade = 0.85 + 0.15 * sin(wpos.y * 0.9 + wpos.x * 0.3);
	ALBEDO = mix(stone.rgb * shade, snow.rgb, m);
	ROUGHNESS = mix(1.0, 0.8, m);
}
