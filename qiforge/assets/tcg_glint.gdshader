shader_type canvas_item;

// 金件：金属反射 + Voronoi 闪点 + 彩虹流光（2026-11-08 按原版 HolographicCard 拆解做的近似）
// 全部只作用于"金件笔画"（外框/分割线），卡面不动。
uniform float band_pos = 0.2;                  // 光带相位（战斗屏驱动）
uniform float strength : hint_range(0.0, 2.0) = 0.34;
uniform float tip_x : hint_range(-1.0, 1.0) = 0.0;   // 倾斜量：决定金属高光落点
uniform float tip_y : hint_range(-1.0, 1.0) = 0.0;
uniform float metal_gain : hint_range(0.0, 2.0) = 0.55;   // 金属反射打开
uniform float voronoi_density = 8.5;
uniform float voronoi_gain : hint_range(0.0, 2.0) = 0.0;   // 闪点关闭（排查明暗不均）
uniform float rainbow_gain : hint_range(0.0, 2.0) = 0.25;   // 彩虹流光开启

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

// 3x3 Voronoi（晶格闪点）
float voronoi_edge(vec2 p) {
	vec2 g = floor(p);
	vec2 f = fract(p);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = vec2(float(i), float(j));
			vec2 r = o + vec2(hash21(g + o), hash21(g + o + 17.0)) - f;
			md = min(md, length(r));
		}
	}
	return md;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	if (base.a < 0.05) {
		COLOR = base;
	} else {
		// ① 金属反射（matcap 近似）：高光位置随倾斜偏移
		vec2 mc = vec2(0.5) + vec2(tip_x, tip_y) * 0.32;
		vec2 dv = (UV - mc) * vec2(1.0, 1.55);
		float spec = smoothstep(0.42, 0.0, length(dv)) * metal_gain;
		// ② Voronoi 闪点（很弱、常驻）
		float vd = voronoi_edge(UV * voronoi_density);
		float spark = smoothstep(0.34, 0.02, vd) * voronoi_gain;
		// ③ 彩虹流光（沿对角线的相位，弱）
		float axis = (UV.x * 0.71 + UV.y) * 0.7071;
		float band = smoothstep(0.07, 0.0, abs(axis - band_pos));
		vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + axis * 1.2 + band_pos * 0.5));
		vec3 warm = vec3(1.0, 0.93, 0.75);
		float amt = clamp(band * strength, 0.0, 0.45);
		vec3 col = base.rgb + warm * amt * step(0.35, base.a);
		col += warm * spec * step(0.35, base.a);
		col += vec3(1.0) * spark * step(0.35, base.a);
		col += rainbow * band * rainbow_gain * step(0.35, base.a);
		COLOR = vec4(col, base.a);
	}
}
