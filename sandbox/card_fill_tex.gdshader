shader_type canvas_item;

// 卡底：AI 底纹贴图 × 类型变色（普攻/催破/护体/心法四色全靠换 tint）
// fill_tex 须为归一化中性灰贴图（无色相），色相全由 tint 给
uniform sampler2D fill_tex : source_color, hint_default_white;
uniform vec4 tint : source_color = vec4(0.336, 0.357, 0.377, 1.0);
uniform float pattern_strength : hint_range(0.0, 1.0) = 0.9; // 1=全纹理 0=纯色
uniform float grain : hint_range(0.0, 0.5) = 0.06;           // 细颗粒
uniform vec2 light_pos = vec2(0.5, 0.35);                    // 光源（卡面 UV，脚本喂）
uniform float light_amt : hint_range(0.0, 0.4) = 0.15;       // 光源提亮量

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float shape_a = texture(TEXTURE, UV).a;      // 剪影形状来自 card_fill.png
	float tv = texture(fill_tex, UV).r;          // AI 底纹灰度 0..1
	float tone = mix(1.0, tv, pattern_strength); // strength=0 退回纯色
	tone *= 1.0 - grain + grain * fbm(UV * vec2(2.2, 4.5) * 7.0);
	float vign = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.82, UV.y);
	tone *= 0.93 + 0.07 * vign;                  // 上下轻晕影收束
	vec2 ld = UV - light_pos;                    // 光源热点：卡面随鼠标亮一角
	ld.x *= 0.71;
	tone *= 1.0 + light_amt * exp(-dot(ld, ld) * 20.0);
	vec3 col = tint.rgb * clamp(tone, 0.0, 1.6);
	COLOR = vec4(col, shape_a * tint.a);
}
