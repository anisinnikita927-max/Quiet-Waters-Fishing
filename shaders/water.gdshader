shader_type spatial;
render_mode specular_schlick_ggx, cull_back;

uniform vec4 deep_tint : source_color = vec4(0.035, 0.20, 0.25, 1.0);
uniform vec4 light_tint : source_color = vec4(0.18, 0.40, 0.41, 1.0);
uniform vec4 sky_tint : source_color = vec4(0.6, 0.7, 0.8, 1.0);
uniform vec4 glint_tint : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float wave_amp = 1.0;
uniform float clock = 0.0;
uniform float glint_power = 1.0;
uniform int drop_count = 0;
// x, z, время начала, амплитуда
uniform vec4 ripples[8];
uniform vec4 drops[24];

varying vec3 wpos;

float ring_height(vec2 p, vec4 r, float speed, float life, float freq) {
	float age = clock - r.z;
	if (age < 0.0 || age > life || r.w <= 0.0) {
		return 0.0;
	}
	float d = distance(p, r.xy);
	float front = age * speed;
	float x = d - front;
	float fade = (1.0 - age / life);
	return sin(x * freq) * exp(-abs(x) * 3.2) * fade * fade * r.w * 0.09;
}

float height(vec2 p) {
	float t = TIME;
	float h = 0.0;
	h += sin(p.x * 0.21 + t * 0.62) * 0.045;
	h += cos(p.y * 0.28 + t * 0.47) * 0.032;
	h += sin((p.x + p.y) * 0.12 + t * 0.32) * 0.018;
	h += sin(p.x * 0.9 + p.y * 0.55 + t * 1.3) * 0.012;
	h += sin(p.x * 1.7 - p.y * 1.2 + t * 1.9) * 0.006;
	h *= wave_amp;
	for (int i = 0; i < 8; i++) {
		h += ring_height(p, ripples[i], 1.7, 3.6, 13.0);
	}
	for (int i = 0; i < 24; i++) {
		if (i >= drop_count) {
			break;
		}
		h += ring_height(p, drops[i], 0.9, 1.1, 30.0) * 0.5;
	}
	return h;
}

void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y += height(p);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float e = 0.08;
	float hc = height(p);
	float hx = height(p + vec2(e, 0.0));
	float hz = height(p + vec2(0.0, e));
	vec3 n = normalize(vec3(-(hx - hc) / e, 1.0, -(hz - hc) / e));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float long_glint = sin(p.x * 0.11 + p.y * 0.08 + TIME * 0.15) * 0.5 + 0.5;
	float fine_glint = sin(p.x * 0.52 - p.y * 0.34 + TIME * 0.72) * 0.5 + 0.5;
	float shimmer = smoothstep(0.38, 0.94, long_glint) * 0.52 + fine_glint * 0.12;
	vec3 base = mix(deep_tint.rgb, light_tint.rgb, shimmer);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);

	// солнечные блики на мелкой ряби
	float sp = sin(p.x * 3.1 + sin(p.y * 0.9) * 2.0 + TIME * 1.7) * sin(p.y * 2.3 + sin(p.x * 0.7) * 2.0 - TIME * 1.3);
	sp += sin(p.x * 5.3 - p.y * 4.1 + sin(p.x * 1.3 + p.y * 1.7) * 2.0 + TIME * 2.4);
	float sparkle = smoothstep(1.5, 2.0, sp) * glint_power;
	float crest = smoothstep(0.08, 0.16, hc * 4.0);

	ALBEDO = base * 0.62 + vec3(0.03) * crest;
	EMISSION = sky_tint.rgb * fres * 0.20 + glint_tint.rgb * sparkle * 0.55;
	METALLIC = 0.1;
	ROUGHNESS = 0.24;
	SPECULAR = 0.45;
}
