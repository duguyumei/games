// 连击徽·墨焰（2026-11-06 第二轮）
// 上一版把噪声直接当 alpha，出来是「绕圈的一团雾」＝无根之火。
// 这一版改成「轮廓驱动」：火沿着徽章外缘烧起来，每个角度能烧多高由噪声决定，
// 所以外沿是有齿的火舌；贴着徽章是金芯，越往外越墨（有厚度，不是一层淡光）。
shader_type canvas_item;

uniform float time = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec2 origin = vec2(0.5, 0.5);
uniform float inner = 0.185;
uniform vec4 cold : source_color = vec4(0.30, 0.48, 0.78, 1.0);
uniform vec4 warm : source_color = vec4(1.00, 0.78, 0.36, 1.0);
uniform vec4 soot : source_color = vec4(0.09, 0.12, 0.19, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(13.7, 7.1);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV - origin;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float up = smoothstep(0.55, -0.55, p.y);

	float n1 = fbm(vec2(ang * 2.3, time * 0.55));
	float n2 = fbm(vec2(ang * 5.6 + 7.3, time * 0.95));
	float h = smoothstep(0.34, 0.78, n1 * 0.66 + n2 * 0.34);

	float edge = inner + (0.012 + 0.150 * h) * (0.18 + 1.50 * up);

	vec2 q = vec2(ang * 10.0, (r - inner) * 13.0 - time * 2.4);
	float streak = fbm(q);

	float a = smoothstep(edge, edge - 0.026, r);
	a *= smoothstep(inner * 0.80, inner * 1.05, r);
	a = clamp(a * (0.50 + 0.75 * streak), 0.0, 1.0);
	a *= 0.95 + 0.60 * pulse;
	a *= strength;

	float heat = smoothstep(edge * 0.99, inner * 1.06, r);
	heat = clamp(heat * (0.55 + 0.95 * streak), 0.0, 1.0);
	vec3 col = mix(soot.rgb, warm.rgb, pow(heat, 3.2));
	col = mix(col, cold.rgb, (1.0 - heat) * 0.40);

	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
