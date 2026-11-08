shader_type canvas_item;
// 焚纸：卡面按噪声从边缘烧穿（2026-11-08 用户令：改成烧，不再切碎块）
// threshold 0→1 逐帧推进；烧穿的边缘留一圈焦橙光。
uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.12, 0.13, 0.16, 1.0);
uniform float edge_width : hint_range(0.0, 0.4) = 0.10;
uniform float noise_scale = 11.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	// 边缘先烧：离边越近，噪声阈值越低
	vec2 e = min(UV, vec2(1.0) - UV);
	float edge = min(e.x, e.y) * 2.0;
	float n = vnoise(UV * noise_scale) * 0.55 + vnoise(UV * noise_scale * 2.3) * 0.30
		+ vnoise(UV * noise_scale * 5.1) * 0.15;
	float burnmap = n * (0.80 + 0.20 * edge);   // 散墨：不做边缘优先，整面随机渗开
	float d = burnmap - threshold;
	if (d < 0.0) {
		discard;
	}
	float glow = 1.0 - smoothstep(0.0, edge_width, d);
	vec3 col = mix(tex.rgb, edge_color.rgb, glow * 0.55);   // 渗墨柔一点
	COLOR = vec4(col, tex.a);
}
