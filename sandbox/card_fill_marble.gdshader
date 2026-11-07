shader_type canvas_item;

// 卡底：剑修风底纹（三式可切）＋类型变色
// Style: 1=宣纸纤维  2=墨晕  3=剑气痕
uniform int style : hint_range(1, 3) = 3;
uniform vec4 tint : source_color = vec4(0.604, 0.627, 0.651, 1.0); // 默认＝普攻青石灰
uniform float pattern_strength : hint_range(0.0, 1.0) = 0.35;      // 纹样强度
uniform float grain : hint_range(0.0, 0.5) = 0.08;                 // 颗粒

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
	float shape_a = texture(TEXTURE, UV).a;   // 剪影形状来自 card_fill
	vec2 p = UV * vec2(2.2, 4.5);

	float pat = 0.5;   // 各式纹样的「明暗系数」0=最暗 1=最亮
	if (style == 1) {
		// 宣纸：竖向细纤维＋纸面起伏
		float fiber = fbm(vec2(p.x * 26.0, p.y * 2.2));
		float paper = fbm(p * 3.0);
		pat = 0.85 + 0.3 * paper + 0.12 * fiber;
	} else if (style == 2) {
		// 墨晕：大片浓淡扩散（对比曲线拉开的低频噪声）
		float ink = fbm(p * 1.1 + fbm(p * 2.0) * 1.5);
		ink = smoothstep(0.25, 0.75, ink);
		pat = 0.7 + 0.5 * ink;
	} else {
		// 剑气（精修版）：双向斜纹——宽流带（气感）＋细锐痕（剑意），32° 走向
		vec2 q = vec2(p.x * 0.9 + p.y * 0.55, -p.x * 2.6 + p.y * 1.6);
		float warp2 = fbm(q * 0.8) * 1.8;
		float sweep = fbm(q * vec2(0.55, 3.2) + vec2(warp2 * 0.4, warp2));
		// 细锐痕：窄过渡＋对比拉直（剑刃感）
		float edge = abs(sweep - 0.5) * 2.0;           // 0=谷线 1=平面
		float blade = 1.0 - smoothstep(0.0, 0.34, edge); // 谷线附近的亮痕
		float valley = smoothstep(0.10, 0.42, edge);     // 平面区正常亮
		// 宽流带：低频大结构（气的流动）
		float flow = fbm(q * vec2(0.4, 1.1) + warp2 * 0.3);
		float band = smoothstep(0.3, 0.7, flow);
		float base = fbm(p * 2.4);
		pat = (0.84 + 0.2 * base) * mix(0.62 + 0.38 * valley, 1.0, 0.35);
		pat *= 0.9 + 0.18 * band;
		pat += blade * 0.16;                             // 锐痕提亮
	}

	// 颗粒＋上下轻晕影（收束视觉）
	float tone = pat * (1.0 - grain + grain * fbm(p * 7.0));
	float vign = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.82, UV.y);
	tone *= 0.93 + 0.07 * vign;
	tone = mix(1.0, tone, clamp(pattern_strength * 2.2, 0.0, 1.0));

	vec3 col = tint.rgb * clamp(tone, 0.0, 1.6);
	COLOR = vec4(col, shape_a * tint.a);
}
